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
      
      
      
      module ClassMethods
        
        IF_MODIFIED_SINCE = "If-Modified-Since"
        
        
        
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
          
          headers[IF_MODIFIED_SINCE] = Remotable.http_format_time(local_record.updated_at) if local_record.respond_to?(:updated_at)
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
          Remotable.logger.info "[remotable:#{name.underscore}] GET #{expanded_path}"
          find(:one, :from => expanded_path)
        rescue ::ActiveResource::TimeoutError
          $!.extend Remotable::TimeoutError
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
