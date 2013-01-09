module Remotable
  class NullRemote
    
    class << self
      
      # This is always invoked by instance#fetch_remote_resource.
      # It expects to find a remote counterpart for a local resource.
      # It should always return a NullRemote object that doesn't
      # alter the behavior of a normal model at all.
      def find_by_for_local(local_record, remote_key, fetch_value)
        new
      end
      
      # This is always invoked via class#find_remote_resource_by
      # by class#fetch_by. It gives the remote model an opportunity
      # to discover a remote object that doesn't have a local
      # counterpart. NullRemote should never discover something
      # that doesn't exist locally.
      def find_by(remote_attr, value)
        nil
      end
      
      def new_resource
        new
      end
      
    end
    
    
    # NullRemote needs to receive setter messages and
    # swallow them. It doesn't need to respond to getter
    # messages since it has nothing to say.
    def method_missing(method_name, *args)
      super unless method_name.to_s =~ /=$/
    end
    
    
    def save
      true
    end
    
    def errors
      {}
    end
    
    def destroy
      true
    end
    
  end
end
