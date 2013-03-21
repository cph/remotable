module Remotable
  module Nosync
    
    
    def nosync!
      self.nosync = true
    end
    
    def nosync(new_value=true)
      old_value = @nosync
      self.nosync = new_value
      yield
    ensure
      self.nosync = old_value
    end
    
    def nosync=(val)
      @nosync = (val == true)
    end
    
    def nosync?
      @nosync == true
    end
    
    
  end
end
