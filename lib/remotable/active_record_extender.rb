require "remotable/core_ext"
require "active_support/concern"
require "active_support/core_ext/array/wrap"


module Remotable
  module ActiveRecordExtender
    extend ActiveSupport::Concern
    include Nosync
    
    def nosync?
      self.class.nosync? || super
    end
    
    
    
    included do
      before_update   :update_remote_resource,  :unless => :nosync?
      before_create   :create_remote_resource,  :unless => :nosync?
      before_destroy  :destroy_remote_resource, :unless => :nosync?
      
      before_validation :initialize_expiration_date, :on => :create
      
      validates_presence_of :expires_at
      
      @remote_attribute_map ||= default_remote_attributes.map_to_self
      @local_attribute_routes ||= {}
      @expires_after ||= 1.day
    end
    
    
    
    module ClassMethods
      include Nosync
      
      def nosync?
        Remotable.nosync? || remote_model.nil? || super
      end
      
      # Sets the key with which a resource is identified remotely.
      # If no remote key is set, the remote key is assumed to be :id.
      # Which could be explicitly set like this:
      #
      #     remote_key :id
      #
      # It can can be a composite key:
      #
      #     remote_key [:calendar_id, :id]
      #
      # You can also supply a path for the remote key which will
      # be passed to +fetch_with+:
      #
      #     remote_key [:calendar_id, :id], :path => "calendars/:calendar_id/events/:id"
      #
      def remote_key(*args)
        if args.any?
          remote_key = args.shift
          options = args.shift || {}
          
          # remote_key may be a composite of several attributes
          # ensure that all of the attributs have been defined
          Array.wrap(remote_key).each do |attribute|
            raise(":#{attribute} is not the name of a remote attribute") unless remote_attribute_names.member?(attribute)
          end
          
          # Set up a finder method for the remote_key
          fetch_with(local_key(remote_key), options)
          
          @remote_key = remote_key
        else
          @remote_key || generate_default_remote_key
        end
      end
      
      def expires_after(*args)
        @expires_after = args.first if args.any?
        @expires_after
      end
      
      def attr_remote(*attrs)
        map = attrs.extract_options!
        map = attrs.map_to_self.merge(map)
        @remote_attribute_map = map
        
        assert_that_remote_resource_responds_to_remote_attributes!(remote_model) if Remotable.validate_models?
        
        # Reset routes
        @local_attribute_routes = {}
      end
      
      def fetch_with(local_key, options={})
        @local_attribute_routes.merge!(local_key => options[:path])
      end
      alias :find_by :fetch_with
      
      
      
      attr_reader :remote_attribute_map,
                  :local_attribute_routes
      
      def local_key(remote_key=nil)
        remote_key ||= self.remote_key
        if remote_key.is_a?(Array)
          remote_key.map(&method(:local_attribute_name))
        else
          local_attribute_name(remote_key)
        end
      end
      
      def remote_attribute_names
        remote_attribute_map.keys
      end
      
      def local_attribute_names
        remote_attribute_map.values
      end
      
      def remote_attribute_name(local_attr)
        remote_attribute_map.key(local_attr) || local_attr
      end
      
      def local_attribute_name(remote_attr)
        remote_attribute_map[remote_attr] || remote_attr
      end
      
      def route_for(remote_key)
        local_key = self.local_key(remote_key)
        local_attribute_routes[local_key] || default_route_for(local_key, remote_key)
      end
      
      def default_route_for(local_key, remote_key=nil)
        puts "local_key: #{local_key}; remote_key: #{remote_key}"
        remote_key ||= remote_attribute_name(local_key)
        if remote_key.to_s == primary_key
          ":#{local_key}"
        else
          "by_#{local_key}/:#{local_key}"
        end
      end
      
      
      
      # !nb: this method is called when associations are loaded
      # so you can use the remoted record in associations.
      def instantiate(*args)
        record = super
        if record.expired? && !Remotable.nosync?
          record.pull_remote_data!
          record = nil if record.destroyed?
        end
        record
      end
      
      
      
      def respond_to?(method_sym, include_private=false)
        return true if recognize_remote_finder_method(method_sym)
        super(method_sym, include_private)
      end
      
      def method_missing(method_sym, *args, &block)
        method_details = recognize_remote_finder_method(method_sym)
        if method_details
          local_attributes = method_details[:local_attributes]
          values = args
          
          unless values.length == local_attributes.length
            raise ArgumentError, "#{method_sym} was called with #{values.length} but #{local_attributes.length} was expected"
          end
          
          local_resource = ((0...local_attributes.length).inject(scoped) do |scope, i|
            scope.where(local_attributes[i] => values[i])
          end).first || fetch_by(method_details[:remote_key], *values)
          
          raise ActiveRecord::RecordNotFound if local_resource.nil? && (method_sym =~ /!$/)
          local_resource
        else
          super(method_sym, *args, &block)
        end
      end
      
      # If the missing method IS a Remotable finder method,
      # returns the remote key (may be a composite key).
      # Otherwise, returns false.
      def recognize_remote_finder_method(method_sym)
        method_name = method_sym.to_s
        return false unless method_name =~ /find_by_([^!]*)(!?)/
        
        local_attributes = $1.split("_and_").map(&:to_sym)
        remote_attributes = local_attributes.map(&method(:remote_attribute_name))
        
        local_key, remote_key = if local_attributes.length == 1
          [local_attributes[0], remote_attributes[0]]
        else
          [local_attributes, remote_attributes]
        end
        
        generate_default_remote_key # <- Make sure we've figured out the remote
                                    #    primary key if we're evaluating a finder
        
        return false unless local_attribute_routes.key?(local_key)
        
        { :local_attributes => local_attributes,
          :remote_key => remote_key }
      end
      
      
      
      def expire_all!
        update_all(["expires_at=?", 1.day.ago])
      end
      
      
      
      # Looks the resource up remotely, by the given attribute
      # If the resource is found, wraps it in a new local resource
      # and returns that.
      def fetch_by(remote_attr, *values)
        remote_resource = find_remote_resource_by(remote_attr, *values)
        remote_resource && new_from_remote(remote_resource)
      end
      
      # Looks the resource up remotely;
      # Returns the remote resource.
      def find_remote_resource_by(remote_attr, *values)
        find_by = remote_model.method(:find_by)
        case find_by.arity
        when 1; find_by.call(remote_path_for(remote_attr, *values))
        when 2; find_by.call(remote_attr, *values)
        else
          raise InvalidRemoteModel, "#{remote_model}.find_by should take either 1 or 2 parameters"
        end
      end
      
      def remote_path_for(remote_key, *values)
        route = route_for(remote_key)
        local_key = self.local_key(remote_key)
        
        if remote_key.is_a?(Array)
          remote_path_for_composite_key(route, local_key, values)
        else
          remote_path_for_simple_key(route, local_key, values.first)
        end
      end
      
      def remote_path_for_simple_key(route, local_key, value)
        route.gsub(/:#{local_key}/, value.to_s)
      end
      
      def remote_path_for_composite_key(route, local_key, values)
        unless values.length == local_key.length
          raise ArgumentError, "local_key has #{local_key.length} attributes but values has #{values.length}"
        end
        
        (0...values.length).inject(route) do |route, i|
          route.gsub(/:#{local_key[i]}/, values[i].to_s)
        end
      end
      
      
      
    private
      
      
      
      def default_remote_attributes
        column_names - %w{id created_at updated_at expires_at}
      end
      
      
      
      def assert_that_remote_resource_responds_to_remote_attributes!(model)
        # Skip this for ActiveResource because it won't define a method until it has
        # loaded an JSON for that method
        return if model.is_a?(Class) and (model < ActiveResource::Base) 
        
        instance = model.new_resource
        attr_getters_and_setters = remote_attribute_names + remote_attribute_names.map {|attr| :"#{attr}="}
        unless instance.respond_to_all?(attr_getters_and_setters)
          raise InvalidRemoteModel,
            "#{instance.class} does not respond to getters and setters " <<
            "for each remote attribute (not implemented: #{instance.does_not_respond_to(attr_getters_and_setters).sort.join(", ")}).\n"
        end
      end
      
      
      
      def generate_default_remote_key
        return @remote_key if @remote_key
        raise("No remote key supplied and :id is not a remote attribute") unless remote_attribute_names.member?(:id)
        remote_key(:id)
      end
      
      
      
      def new_from_remote(remote_resource)
        record = self.new
        record.instance_variable_set(:@remote_resource, remote_resource)
        record.pull_remote_data!
      end
      
    end
    
    
    
    delegate :local_key,
             :remote_key,
             :remote_model,
             :remote_attribute_map,
             :remote_attribute_names,
             :remote_attribute_name,
             :local_attribute_names,
             :local_attribute_name,
             :expires_after,
             :find_remote_resource_by,
             :to => "self.class"
    
    def expired?
      expires_at.nil? || expires_at < Time.now
    end
    
    def expired!
      update_attribute(:expires_at, 1.day.ago)
    end
    
    
    
    def pull_remote_data!
      merge_remote_data!(remote_resource)
    end
    
    
    
    def remote_resource
      @remote_resource ||= fetch_remote_resource
    end
    
    def any_remote_changes?
      (changed.map(&:to_sym) & local_attribute_names).any?
    end
    
    
    
  private
    
    def fetch_remote_resource
      fetch_value = self[local_key]
      # puts "local_key", local_key.inspect, "",
      #      "remote_key", remote_key.inspect, "",
      #      "fetch_value", fetch_value
      find_remote_resource_by(remote_key, fetch_value)
    end
    
    def merge_remote_data!(remote_resource)
      if remote_resource.nil?
        nosync { destroy }
      
      else
        merge_remote_data(remote_resource)
        reset_expiration_date
        nosync { save! }
      end
      
      self
    end
    
    
    
    def update_remote_resource
      if any_remote_changes?
        merge_local_data(remote_resource, true)
        unless remote_resource.save
          merge_remote_errors(remote_resource.errors)
          raise ActiveRecord::RecordInvalid.new(self)
        end
      end
    end
    
    def create_remote_resource
      @remote_resource = remote_model.new_resource
      merge_local_data(@remote_resource)
      
      if @remote_resource.save
        
        # This line is especially crucial if the primary key
        # of the remote resource needs to be stored locally.
        merge_remote_data(@remote_resource)
      else
        
        merge_remote_errors(remote_resource.errors)
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end
    
    def destroy_remote_resource
      remote_resource && remote_resource.destroy
    end
    
    
    
    def initialize_expiration_date
      reset_expiration_date unless self.expires_at
    end
    
    def reset_expiration_date
      self.expires_at = expires_after.from_now
    end
    
    
    
    def local_attribute_changed?(name)
      changed.member?(name.to_s)
    end
    
    
    
  protected
    
    
    
    def merge_remote_errors(errors)
      errors.each do |attribute, messages|
        Array.wrap(messages).each do |message|
          self.errors.add(local_attribute_name(attribute), message)
        end
      end
      self
    end
    
    def merge_remote_data(remote_resource)
      remote_attribute_map.each do |remote_attr, local_attr|
        if remote_resource.respond_to?(remote_attr)
          send("#{local_attr}=", remote_resource.send(remote_attr))
        end
      end
      self
    end
    
    def merge_local_data(remote_resource, changes_only=false)
      remote_attribute_map.each do |remote_attr, local_attr|
        if !changes_only || local_attribute_changed?(local_attr)
          remote_resource.send("#{remote_attr}=", send(local_attr))
        end
      end
      self
    end
    
    
    
  end
end
