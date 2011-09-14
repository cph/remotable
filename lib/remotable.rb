require "remotable/version"


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
  
  
  
  class << self
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
  end
  
  
  
  def remote_model(*args)
    if args.any?
      @remote_model = args.first
      
      require "remotable/active_record_extender"
      include Remotable::ActiveRecordExtender
    else
      @remote_model
    end
  end
  
  
  
end


ActiveRecord::Base.extend(Remotable) if defined?(ActiveRecord::Base)
