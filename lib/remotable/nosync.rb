
module Remotable
  module Nosync
    
    
    def nosync!
      self.nosync = true
    end
    
    def nosync
      value = @nosync
      nosync!
      yield
    ensure
      self.nosync = value
    end
    
    def nosync=(val)
      @nosync = (val == true)
    end
    
    def nosync?
      @nosync == true
    end
    
    
  end
end
