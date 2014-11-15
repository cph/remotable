require "remotable/active_resource_fixes"
require "remotable/core_ext/uri"
require "active_support/concern"


module Remotable
  module Adapters
    module ActiveResource
      extend ActiveSupport::Concern
      
      
      
      def key?(attribute)
        attributes.key?(attribute.to_s)
      end
      
      def [](attribute)
        attributes[attribute.to_s]
      end
      
      def []=(attribute, value)
        attributes[attribute.to_s] = value
      end
      
      
      
      # If we use `remote_key` to explicitly set the path where
      # this resource ought to be found, then we should use the
      # same path when updating or destroying this resource.
      # 
      # To accomplish this, we need to override ActiveResource's
      # element_path to return the canonical path for this resource.
      
      attr_accessor :remote_key_path
      
      def element_path(*args)
        return remote_key_path if remote_key_path
        super
      end
      
      
      
      def destroy
        super
      rescue ::ActiveResource::ResourceNotFound
        $!.extend Remotable::NotFound
        raise
      end
      
      
      
      module ClassMethods
        
        IF_MODIFIED_SINCE = "If-Modified-Since".freeze
        
        
        
        def new_resource
          new
        end
        
        
        
        # This is always invoked by instance#fetch_remote_resource.
        # It expects to find a remote counterpart for a local resource.
        # It should always return a NullRemote object that doesn't
        # alter the behavior of a normal model at all.
        def find_by_for_local(local_record, path)
          had_previous_value = headers.key?(IF_MODIFIED_SINCE)
          previous_value = headers[IF_MODIFIED_SINCE]
          
          headers[IF_MODIFIED_SINCE] = Remotable.http_format_time(local_record.remote_updated_at) if local_record.accepts_not_modified?
          find_by(path)
        ensure
          if had_previous_value
            headers[IF_MODIFIED_SINCE] = previous_value
          else
            headers.delete(IF_MODIFIED_SINCE)
          end
        end
        
        def find_by(path)
          find_by!(path)
        rescue ::ActiveResource::ResourceNotFound
          nil
        end
        
        def find_by!(path)
          expanded_path = expanded_path_for(path)
          Remotable.logger.info "[remotable:#{name.underscore}] GET #{expanded_path} (timeout: #{timeout})"
          find(:one, :from => expanded_path).tap do |resource|
            resource.remote_key_path = expanded_path if resource
          end
        rescue SocketError
          $!.extend Remotable::NetworkError
          raise
        rescue ::ActiveResource::TimeoutError
          $!.extend Remotable::TimeoutError
          raise
        rescue ::ActiveResource::ServerError
          $!.extend Remotable::ServiceUnavailableError if $!.response.code == 503
          $!.extend Remotable::TimeoutError if $!.response.code == 504
          raise
        end
        
        
        
        def expanded_path_for(path)
          if relative_path?(path)
            URI.join_url_segments(prefix, collection_name, "#{path}.#{format.extension}")
          else
            path
          end
        end
        
        
        
      private
        
        def relative_path?(path)
          !(path.start_with?("/") || path["://"])
        end
        
      end
    end
  end
end
