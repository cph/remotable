require "active_record"


class BespokeModel
  
  def new_resource
    BespokeResource.new
  end
  
  def find_by(remote_attr, value)
    nil
  end
  
end

class BespokeModel2
  
  def new_resource
    BespokeResource.new
  end
  
  def find_by(remote_attr, value)
    BespokeResource.new(remote_attr => value)
  end
  
end

class BespokeResource
  
  def initialize(attributes={})
    @attributes = attributes
  end
  
  delegate :key?, :[], :[]=, :to => :@attributes
  
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
  self.table_name = "tenants"
  
  remote_model BespokeModel.new
  attr_remote :slug, :name
  remote_key :slug
end

