require "remotable/core_ext"
require "active_support/concern"


module Remotable
  module ActiveRecordExtender
    extend ActiveSupport::Concern
    
    
    
    included do
      before_update   :update_remote_resource,  :unless => :nosync?
      before_create   :create_remote_resource,  :unless => :nosync?
      before_destroy  :destroy_remote_resource, :unless => :nosync?
      
      before_validation :reset_expiration_date, :on => :create, :unless => :nosync?
      
      validates_presence_of :expires_at
      
      default_remote_attributes = column_names - %w{id created_at updated_at expires_at}
      @remote_attribute_map = default_remote_attributes.map_to_self
      @remote_attribute_routes = {}
      @expires_after = 1.day
      
      extend_remote_model
    end
    
    
    
    module ClassMethods
      
      def remote_key(*args)
        if args.any?
          remote_key = args.first
          raise("#{remote_key} is not the name of a remote attribute") unless remote_attribute_names.member?(remote_key)
          @remote_key = remote_key
          fetch_with(remote_key)
          remote_key
        else
          @remote_key || generate_default_remote_key
        end
      end
      
      def expires_after(*args)
        if args.any?
          @expires_after = args.first
        else
          @expires_after
        end
      end
      
      def attr_remote(*attrs)
        map = attrs.extract_options!
        map = attrs.map_to_self(map)
        @remote_attribute_map = map
      end
      
      def fetch_with(*local_keys)
        remote_keys_and_routes = extract_remote_keys_and_routes(*local_keys)
        @remote_attribute_routes.merge!(remote_keys_and_routes)
      end
      alias :find_by :fetch_with
      
      
      
      attr_reader :remote_attribute_map,
                  :remote_attribute_routes
      
      def local_key
        local_attribute_name(remote_key)
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
      
      def route_for(local_key)
        remote_key = remote_attribute_name(local_key)
        remote_attribute_routes[remote_key] || default_route_for(local_key, remote_key)
      end
      
      def default_route_for(local_key, remote_key=nil)
        remote_key ||= remote_attribute_name(local_key)
        if remote_key.to_s == primary_key
          ":#{local_key}"
        else
          "by_#{remote_key}/:#{local_key}"
        end
      end
      
      
      
      # !nb: this method is called when associations are loaded
      # so you can use the remoted record in associations.
      def instantiate(*args)
        record = super
        record.pull_remote_data! if record.expired?
        record = nil if record.destroyed?
        record
      end
      
      
      
      def method_missing(method_sym, *args, &block)
        method_name = method_sym.to_s
        
        if method_name =~ /find_by_(.*)(!?)/
          local_attr, bang, value = $1.to_sym, !$2.blank?, args.first
          remote_attr = remote_attribute_name(local_attr)
          
          remote_key # Make sure we've figured out the remote
                     # primary key if we're evaluating a finder
          
          if remote_attribute_routes.key?(remote_attr)
            local_resource = where(local_attr => value).first
            unless local_resource
              remote_resource = remote_model.find_by(remote_attr, value)
              local_resource = new_from_remote(remote_resource) if remote_resource
            end
            
            raise ActiveRecord::RecordNotFound if local_resource.nil? && bang
            return local_resource
          end
        end
        
        super(method_sym, *args, &block)
      end
      
      
      
    private
      
      
      
      def extend_remote_model
        if remote_model < ActiveResource::Base
          require "remotable/adapters/active_resource"
          remote_model.send(:include, Remotable::Adapters::ActiveResource)
          remote_model.local_model = self
        
        # !todo
        # Adapters for other API consumers can be implemented here
        #
        
        else
          raise("#{remote_model} is not a recognized remote resource")
        end
      end
      
      
      def extract_remote_keys_and_routes(*local_keys)
        keys_and_routes = local_keys.extract_options!
        {}.tap do |hash|
          local_keys.each {|local_key| hash[remote_attribute_name(local_key)] = nil}
          keys_and_routes.each {|local_key, value| hash[remote_attribute_name(local_key)] = value}
        end
      end
      
      
      def generate_default_remote_key
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
    
    
    
    def nosync!
      @nosync = true
    end
    
    def nosync
      value = @nosync
      @nosync = true
      yield
    ensure
      @nosync = value
    end
    
    def nosync=(val)
      @nosync = (val == true)
    end
    
    def nosync?
      @nosync == true
    end
    
    
    
  private
    
    def fetch_remote_resource
      fetch_value = self[local_key]
      remote_model.find_by(remote_key, fetch_value)
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
      @remote_resource = remote_model.new
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
    
    
    
    def reset_expiration_date
      self.expires_at = expires_after.from_now
    end
    
    
    
    def local_attribute_changed?(name)
      changed.member?(name.to_s)
    end
    
    
    
  protected
    
    
    
    def merge_remote_errors(errors)
      errors.each do |attribute, message|
        self.errors[local_attribute_name(attribute)] = message
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
