require 'active_record'
require 'active_resource'

class Tenant < ActiveRecord::Base
  include Remotable
  
  attr_remote :slug, :church_name => :name, :active_unite_account => :active
  fetch_with :slug
  
  class RemoteTenant < ActiveResource::Base
    
    self.site                 = "http://example.com/api/"
    self.element_name         = "account"
    self.format               = :json
    self.include_root_in_json = false
    self.user                 = "username"
    self.password             = "password"
    
    class << self
      def find_by_slug!(slug)
        find(:one, :from => "/api/accounts/by_slug/#{slug}.json")
      end
      
      def find_by_slug(slug)
        find_by_slug!(slug)
      rescue ActiveResource::ResourceNotFound
        nil
      end
    end
    
  end
end
