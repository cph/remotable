require "remotable/active_resource_fixes"
require "remotable/core_ext/uri"
require "active_support/concern"


module Remotable
  module Adapters
    module ActiveResource
      extend ActiveSupport::Concern
      
      module ClassMethods
        
        
        
        
        def find_by!(path, key, value)
          find(:one, :from => expanded_path_for(path))
        end
        
        def find_by(path, key, value)
          find_by!(path, key, value)
        rescue ::ActiveResource::ResourceNotFound
          nil
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
