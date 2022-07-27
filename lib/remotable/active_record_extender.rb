require "remotable/core_ext"
require "active_support/concern"
require "active_support/core_ext/array/wrap"
require "benchmark"


module Remotable
  module ActiveRecordExtender
    extend ActiveSupport::Concern
    include Nosync

    def nosync?
      return super if nosync_value?
      self.class.nosync?
    end



    included do
      extend Nosync

      # Has to be re-defined _after_ Nosync is extended, which cannot
      # be done as part of the ClassMethods module
      def self.nosync?
        return true if remote_model.nil?
        return super if nosync_value?
        Remotable.nosync?
      end

      before_update   :update_remote_resource,  :unless => :nosync?
      before_create   :create_remote_resource,  :unless => :nosync?
      before_destroy  :destroy_remote_resource, :unless => :nosync?

      before_validation :initialize_expiration_date, :on => :create

      validates_presence_of :expires_at

      self._remote_attribute_map ||= default_remote_attributes.map_to_self
      self._local_attribute_routes ||= {}
      self._expires_after ||= 1.day
      self._remote_timeout = {
        :list    => 4, # when we're getting many remote resources
        :fetch   => 4, # when we're getting a remote resource that doesn't exist locally
        :pull    => 1, # when we're getting a remote resource to refresh a local one
        :update  => 2, # when we're updaing a remote resource
        :create  => 2, # when we're creating a remote resource
        :destroy => 2  # when we're destroying a remote resource
      }
    end



    module ClassMethods

      attr_accessor :_remote_attribute_map, :_local_attribute_routes, :_expires_after,
        :_remote_timeout, :remotable_skip_validation_on_sync


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
        self._expires_after = args.first if args.any?
        _expires_after
      end

      def attr_remote(*attrs)
        map = attrs.extract_options!
        map = attrs.map_to_self.merge(map)
        self._remote_attribute_map = map
        self._local_attribute_routes = {} # reset routes
      end

      def remote_timeout(*args)
        if args.any?
          self._remote_timeout = n = args.first
          self._remote_timeout = {:list => n, :fetch => n, :pull => n, :create => n, :update => n, :destroy => n} if n.is_a?(Numeric)
        end
        _remote_timeout
      end

      def remote_attribute_map
        self._remote_attribute_map
      end

      def local_attribute_routes
        self._local_attribute_routes
      end

      def fetch_with(local_key, options={})
        self._local_attribute_routes.merge!(local_key => options[:path])
      end

      def remotable_skip_validation!
        self.remotable_skip_validation_on_sync = true
      end

      def remotable_skip_validation_on_sync?
        self.remotable_skip_validation_on_sync
      end


      def local_key(remote_key=nil)
        remote_key ||= self.remote_key
        if remote_key.is_a?(Array)
          remote_key.map(&method(:local_attribute_name))
        else
          local_attribute_name(remote_key)
        end
      end

      def remote_attribute_names
        _remote_attribute_map.keys
      end

      def local_attribute_names
        _remote_attribute_map.values
      end

      def remote_attribute_name(local_attr)
        _remote_attribute_map.key(local_attr) || local_attr
      end

      def local_attribute_name(remote_attr)
        _remote_attribute_map[remote_attr] || remote_attr
      end

      def route_for(remote_key)
        local_key = self.local_key(remote_key)
        _local_attribute_routes[local_key] || default_route_for(local_key, remote_key)
      end

      def default_route_for(local_key, remote_key=nil)
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
        super.tap do |record|
          sync_on_instantiate(record) unless ActiveRecord.version.segments.first > 5
        end
      end

      # !nb: In Rails 6+, this has been extracted from instantiate and can be called
      # to instantiate homogenous sets of records without calling instantiate
      def instantiate_instance_of(*args)
        super.tap do |record|
          sync_on_instantiate(record)
        end
      end

      def sync_on_instantiate(record)
        if record.expired? && !record.nosync?
          begin
            Remotable.logger.debug "[remotable:#{name.underscore}:sync_on_instantiate](#{record.fetch_value.inspect}) expired #{record.expires_at}"
            record.pull_remote_data!
          rescue Remotable::TimeoutError
            report_ignored_timeout_error($!)
          rescue Remotable::NetworkError
            report_ignored_network_error($!)
          rescue Remotable::ServiceUnavailableError
            report_ignored_503_error($!)
          rescue Remotable::SSLError
            report_ignored_ssl_error($!)
          end
        end
      end

      def report_ignored_timeout_error(error)
        Remotable.logger.error "[remotable:#{name.underscore}:instantiate] #{error.message}"
      end

      def report_ignored_network_error(error)
        Remotable.logger.error "[remotable:#{name.underscore}:instantiate] #{error.message}"
      end

      def report_ignored_503_error(error)
        Remotable.logger.error "[remotable:#{name.underscore}:instantiate] #{error.message}"
      end

      def report_ignored_ssl_error(error)
        Remotable.logger.error "[remotable:#{name.underscore}:instantiate] #{error.message}"
      end



      # !todo: create these methods on an anonymous module and mix it in

      def respond_to?(method_sym, include_private=false)
        return true if recognize_remote_finder_method(method_sym)
        super(method_sym, include_private)
      end

      def method_missing(method_sym, *values, &block)
        method_details = recognize_remote_finder_method(method_sym)
        return super(method_sym, *values, &block) unless method_details

        local_attributes = method_details[:local_attributes]
        raise ArgumentError, "#{method_sym} was called with #{values.length} but #{local_attributes.length} was expected" unless values.length == local_attributes.length

        local_resource = __remotable_lookup(method_details[:remote_key], local_attributes, values)
        local_resource = nil if local_resource && local_resource.destroyed?
        raise ActiveRecord::RecordNotFound if local_resource.nil? && (method_sym =~ /!$/)
        local_resource
      end

      def __remotable_lookup(key, local_attributes, values)
        __remotable_local_lookup(local_attributes, values) || fetch_by(key, *values)
      rescue ActiveRecord::RecordNotUnique
        __remotable_local_lookup(local_attributes, values)
      end

      def __remotable_local_lookup(local_attributes, values)
        (0...local_attributes.length)
          .inject(self) { |scope, i| scope.where(local_attributes[i] => values[i]) }
          .limit(1).first
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

        return false unless _local_attribute_routes.key?(local_key)

        { :local_attributes => local_attributes,
          :remote_key => remote_key }
      end



      def expire_all!
        update_all(expires_at: 1.day.ago)
      end

      def sync_all!
        expire_all!
        all.to_a
      end



      # Looks the resource up remotely, by the given attribute
      # If the resource is found, wraps it in a new local resource
      # and returns that.
      def fetch_by(remote_attr, *values)
        remote_resource = find_remote_resource_by(remote_attr, *values)
        remote_resource && new_from_remote(remote_resource)
      end

      def find_remote_resource_by(remote_attr, *values)
        invoke_remote_model_find_by(remote_attr, *values)
      end

      def find_remote_resource_for_local_by(local_resource, remote_attr, *values)
        if remote_model.respond_to?(:find_by_for_local)
          invoke_remote_model_find_by_for_local(local_resource, remote_attr, *values)
        else
          invoke_remote_model_find_by(remote_attr, *values)
        end
      end

      def invoke_remote_model_find_by(remote_attr, *values)
        remote_set_timeout :fetch

        find_by = remote_model.method(:find_by)
        case find_by.arity
        when 1; find_by.call(remote_path_for(remote_attr, *values))
        when 2; find_by.call(remote_attr, *values)
        else
          raise InvalidRemoteModel, "#{remote_model}.find_by should take either 1 or 2 parameters"
        end
      end

      def invoke_remote_model_find_by_for_local(local_resource, remote_attr, *values)
        remote_set_timeout :pull

        find_by_for_local = remote_model.method(:find_by_for_local)
        case find_by_for_local.arity
        when 2; find_by_for_local.call(local_resource, remote_path_for(remote_attr, *values))
        when 3; find_by_for_local.call(local_resource, remote_attr, *values)
        else
          raise InvalidRemoteModel, "#{remote_model}.find_by_for_local should take either 2 or 3 parameters"
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
        route.gsub(/:#{local_key}/, ERB::Util.url_encode(value.to_s))
      end

      def remote_path_for_composite_key(route, local_key, values)
        values.flatten!
        unless values.length == local_key.length
          raise ArgumentError, "local_key has #{local_key.length} attributes but values has #{values.length}"
        end

        (0...values.length).inject(route) do |route, i|
          route.gsub(/:#{local_key[i]}/, ERB::Util.url_encode(values[i].to_s))
        end
      end


      def all_by_remote
        find_by_remote_query(:all)
      end

      def find_by_remote_query(remote_method_name, *args)
        remote_set_timeout :list
        remote_resources = Array.wrap(remote_model.send(remote_method_name, *args))

        map_remote_resources_to_local(remote_resources)
      end

      def map_remote_resources_to_local(remote_resources)
        return [] if remote_resources.nil? || remote_resources.empty?

        local_resources = nosync { fetch_corresponding_local_resources(remote_resources).to_a }

        # Ensure a corresponding local resource for
        # each remote resource; return the set of
        # local resources.
        remote_resources.map do |remote_resource|

          # Get the specific local resource that
          # corresponds to this remote one.
          local_resource = local_resources.detect { |local_resource|
            Array.wrap(remote_key).all? { |remote_attr|
              local_attr = local_attribute_name(remote_attr)
              local_resource.send(local_attr) == remote_resource[remote_attr]
            }
          }

          # If a local counterpart to this remote value
          # exists, update the local resource and return it.
          # If not, create a local counterpart and return it.
          if local_resource
            local_resource.instance_variable_set :@remote_resource, remote_resource
            local_resource.pull_remote_data!
          else
            new_from_remote(remote_resource)
          end
        end
      end

      def fetch_corresponding_local_resources(remote_resources)
        conditions = Array.wrap(remote_key).each_with_object({}) do |remote_attr, query|
          local_attr = local_attribute_name(remote_attr)
          query[local_attr] = remote_resources.map { |resource| resource[remote_attr] }
        end

        where(conditions)
      end



    private

      def remote_set_timeout(mode)
        remote_model.timeout = remote_timeout[mode] if remote_model.respond_to?(:timeout=)
      end


      def default_remote_attributes
        column_names - %w{id created_at updated_at expires_at}
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
             :remotable_skip_validation_on_sync?,
             :to => "self.class"

    def expired?
      expires_at.nil? || expires_at < Time.now
    end

    def expired!
      update_attribute(:expires_at, 1.day.ago)
    end



    def accepts_not_modified?
      respond_to?(:remote_updated_at)
    end



    def pull_remote_data!
      if remote_resource
        merge_remote_data!(remote_resource)
      elsif fetch_value
        remote_model_has_been_destroyed!
      end
    end



    def remote_resource
      @remote_resource ||= fetch_remote_resource
    end

    def any_remote_changes?
      (changed.map(&:to_sym) & local_attribute_names).any?
    end



    def fetch_value
      if local_key.is_a?(Array)
        local_key.map(&method(:send))
      else
        send(local_key)
      end
    end



  private

    def fetch_remote_resource
      fetch_value && find_remote_resource_by(remote_key, fetch_value)
    end

    def find_remote_resource_by(remote_key, fetch_value)
      result = nil
      ms = Benchmark.ms do
        result = self.class.find_remote_resource_for_local_by(self, remote_key, fetch_value)
      end
      Remotable.logger.info "[remotable:#{self.class.name.underscore}:find_remote_resource_by](#{fetch_value.inspect})" << " %.1fms" % [ ms ]
      result
    end

    def merge_remote_data!(remote_resource)
      merge_remote_data(remote_resource)
      reset_expiration_date
      nosync { save!(validate: !remotable_skip_validation_on_sync?) }
      self
    end

    def remote_model_has_been_destroyed!
      Remotable.logger.info "[remotable:#{self.class.name.underscore}:remote_model_has_been_destroyed!](#{fetch_value.inspect})"
      nosync { destroy }
    end



    def update_remote_resource
      if any_remote_changes? && remote_resource
        merge_local_data(remote_resource, true)

        remote_set_timeout :update
        if remote_resource.save
          merge_remote_data!(remote_resource)
        else
          merge_remote_errors(remote_resource.errors)
          raise ActiveRecord::RecordInvalid.new(self)
        end
      end
    end

    def create_remote_resource
      @remote_resource = remote_model.new_resource
      merge_local_data(@remote_resource)

      remote_set_timeout :create
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
      return nil unless remote_resource

      remote_set_timeout :destroy
      if remote_resource.destroy
        true
      else
        merge_remote_errors(remote_resource.errors)
        ActiveRecord.version.segments.first > 4 ? throw(:abort) : false
      end
    rescue Remotable::NotFound
      report_ignored_404_on_destroy $!
    end



    def initialize_expiration_date
      reset_expiration_date unless self.expires_at
      true
    end

    def reset_expiration_date
      self.expires_at = expires_after.from_now
    end



    def local_attribute_changed?(name)
      changed.member?(name.to_s)
    end



  protected



    def report_ignored_404_on_destroy(error)
      Remotable.logger.error "[remotable:#{self.class.name.underscore}:destroy] #{error.message}"
    end

    def merge_remote_errors(errors)
      Remotable.logger.debug "[remotable:#{self.class.name.underscore}:merge_remote_errors](#{fetch_value.inspect}) #{errors.inspect}"
      errors.to_hash.each do |attribute, messages|
        Array.wrap(messages).each do |message|
          self.errors.add(local_attribute_name(attribute), message)
        end
      end
      self
    end

    def merge_remote_data(remote_resource)
      remote_attribute_map.each do |remote_attr, local_attr|
        if remote_resource.key?(remote_attr)
          remote_value = remote_resource[remote_attr]
          Remotable.logger.debug "[remotable:#{self.class.name.underscore}:merge_remote_data](#{fetch_value.inspect}) local.#{local_attr} = #{remote_value.inspect}"
          send("#{local_attr}=", remote_value)
        end
      end
      self.remote_updated_at = Time.now if respond_to?(:remote_updated_at=)
      self
    end

    def merge_local_data(remote_resource, changes_only=false)
      remote_attribute_map.each do |remote_attr, local_attr|
        if !changes_only || local_attribute_changed?(local_attr)
          local_value = send(local_attr)
          Remotable.logger.debug "[remotable:#{self.class.name.underscore}:merge_local_data](#{fetch_value.inspect}) remote.#{remote_attr} = #{local_value.inspect}"
          remote_resource[remote_attr] = local_value
        end
      end
      self
    end



  private

    def remote_set_timeout(mode)
      self.class.send :remote_set_timeout, mode
    end

  end
end
