require "active_record"


class BespokeModel
  
  def new_resource
    BespokeResource.new
  end
  
  def find_by(remote_attr, value)
    nil
  end
  
end

class BespokeResource
  
  def initialize(attributes={})
    self.slug = attributes[:slug]
    self.name = attributes[:name]
  end
  
  attr_accessor :slug, :name
  
  def save
    true
  end
  
  def errors
    {}
  end
  
  def destroy
  end
  
end

class BespokeTenant < ActiveRecord::Base
  set_table_name "tenants"
  
  remote_model BespokeModel.new
  attr_remote :slug, :name
  remote_key :slug
end

