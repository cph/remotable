require "active_record"
require "active_resource"


class RemoteTenant < ActiveResource::Base
  self.site                 = "http://example.com/api/"
  self.element_name         = "account"
  self.format               = :json
  self.include_root_in_json = false
  self.user                 = "username"
  self.password             = "password"
end

class Tenant < ActiveRecord::Base
  remote_model RemoteTenant
  attr_remote :slug, :church_name => :name, :id => :remote_id
  find_by :name => "by_nombre/:name"
end



class RemoteTenant2 < ActiveResource::Base
end

class RemoteWithoutKey < ActiveRecord::Base
  set_table_name "tenants"
  
  remote_model RemoteTenant2
  attr_remote :id => :remote_id
end


class RemoteTenant3 < ActiveResource::Base
end

class RemoteWithKey < ActiveRecord::Base
  set_table_name "tenants"
  
  remote_model RemoteTenant3
  attr_remote :slug
  remote_key :slug
end
