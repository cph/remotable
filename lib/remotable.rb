require "remotable/version"
require "remotable/core_ext"
require "remotable/active_resource_fixes"
require "active_support/concern"


# Remotable keeps a locally-stored ActiveRecord
# synchronized with a remote resource.
#
# == Requirements ==
# Remotable expects there to be an <tt>expires_at</tt>
# field on the record.
#
# == New resources ==
# When a resource isn't found locally, Remotable
# fetches it from the remote API and creates a local
# copy of the resource.
#
# == Expired resources ==
# When a resource is found locally, Remotable checks
# the value of <tt>expires_at</tt> and re-fetches the
# remote resource if need be.
#
# == Deleted resources ==
# When a remote resources has been deleted, the local
# resource should be removed when it is expired.
#
# == Creating, Updating, and Destroying local resources ==
# Before a local record is saved, Remotable tries
# to apply the changes remotely.
#
#
module Remotable
  extend ActiveSupport::Concern
  
  
  
  included do
    before_update   :update_remote_resource,  :unless => :nosync?
    before_create   :create_remote_resource,  :unless => :nosync?
    before_destroy  :destroy_remote_resource, :unless => :nosync?
    
    before_validation :reset_expiration_date, :on => :create, :unless => :nosync?
    
    validates_presence_of :expires_at
    
    default_remote_attributes = column_names - ["id", "created_at", "updated_at", "expires_at"]
    @remote_model_name = "#{self.name}::Remote#{self.name}"
    @remote_attribute_map = default_remote_attributes.map_to_self
    @expires_after = 1.day
  end
  
  
  
  module ClassMethods
    
    def remote_model_name(name)
      @remote_model = nil
      @remote_model_name = name
    end
    
    def attr_remote(*attrs)
      map = attrs.extract_options!
      map = attrs.map_to_self(map)
      @remote_attribute_map = map
    end
    
    def fetch_with(local_key)
      @local_key = local_key
      @remote_key = remote_attribute_name(local_key)
      
      class_eval <<-RUBY
        def self.find_by_#{local_key}(value)
          local_resource = where(:#{local_key} => value).first
          local_resource || fetch_new_from_remote(value)
        end
        
        def self.find_by_#{local_key}!(value)
          find_by_#{local_key}(value) || raise(ActiveRecord::RecordNotFound)
        end
      RUBY
    end
    
    def expires_after(val)
      @expires_after = val
    end
    
    
    
    attr_reader :local_key,
                :remote_key,
                :expires_after,
                :remote_attribute_map
    
    def remote_model
      @remote_model ||= @remote_model_name.constantize
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
    
    
    
    # !nb: this method is called when associations are loaded
    # so you can use the remoted record in associations.
    def instantiate(*args)
      record = super
      record.pull_remote_data! if record.expired?
      record = nil if record.destroyed?
      record
    end
    
    
    
  private
    
    
    
    def fetch_new_from_remote(value)
      record = self.new
      record.send("#{local_key}=", value) # {local_key => value} not passed to :new so local_key can be protected
      if record.remote_resource
        record.pull_remote_data!
      else
        nil
      end
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
    if remote_key == :id
      remote_model.find(fetch_value)
    else
      remote_model.send("find_by_#{remote_key}", fetch_value)
    end
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
      if !changes_only || changed.member?(local_attr.to_s)
        remote_resource.send("#{remote_attr}=", send(local_attr))
      end
    end
    self
  end
  
  
  
end
