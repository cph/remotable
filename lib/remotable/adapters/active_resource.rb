require "remotable/active_resource_fixes"
require "remotable/core_ext/uri"
require "active_support/concern"


module Remotable
  module Adapters
    module ActiveResource
      extend ActiveSupport::Concern
      
      module ClassMethods
        
        
        attr_accessor :local_model
        
        delegate :local_attribute_name,
                 :route_for,
                 :to => :local_model
        
        
        
        def find_by!(key, value)
          find(:one, :from => path_for(key, value))
        end
        
        def find_by(key, value)
          find_by!(key, value)
        rescue ::ActiveResource::ResourceNotFound
          nil
        end
        
        
        
        def path_for(remote_key, value)
          local_key = local_attribute_name(remote_key)
          route = route_for(local_key)
          path = route.gsub(/:#{local_key}/, value.to_s)
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
