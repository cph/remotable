require "remotable/version"
require "remotable/nosync"
require "remotable/validate_models"


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
  extend Nosync
  extend ValidateModels
  
  # By default, Remotable will validate the models you
  # supply it via +remote_model+. You can set validate_models
  # to false to skip this validation. It is recommended that
  # you keep validation on in development and test environments,
  # but turn it off in production.
  self.validate_models = true
  
  
  # == remote_model( model [optional] )
  # 
  # When called without arguments, this method returns
  # the remote model connected to this local ActiveRecord
  # model.
  #
  # When called with an argument, it extends the ActiveRecord
  # model on which it is called.
  #
  # <tt>model</tt> can be a class that inherits from any
  # of these API consumers:
  #
  #  * ActiveResource
  # 
  # <tt>model</tt> can be any object that responds
  # to these two methods for getting a resource:
  #
  #  * +find_by(path)+ or +find_by(remote_attr, value)+
  #      +find_by+ can be defined to take either one argument or two.
  #      If it takes one argument, it will be passed path.
  #      If it takes two, it will be passed remote_attr and value.
  #  * +new_resource+
  # 
  # Resources must respond to:
  #
  #  * +save+ (return true on success and false on failure)
  #  * +destroy+
  #  * +errors+ (returning a hash of error messages by attribute)
  #  * getters and setters for each attribute
  #
  def remote_model(*args)
    if args.any?
      @remote_model = args.first
      
      require "remotable/active_record_extender"
      include Remotable::ActiveRecordExtender
    else
      @remote_model
    end
  end
  
  
  
  REQUIRED_CLASS_METHODS = [:find_by, :new_resource]
  REQUIRED_INSTANCE_METHODS = [:save, :errors, :destroy]
  
  class InvalidRemoteModel < ArgumentError; end
  
end


ActiveRecord::Base.extend(Remotable) if defined?(ActiveRecord::Base)
