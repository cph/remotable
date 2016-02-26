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
      @nosync = old_value
    end

    def nosync=(val)
      @nosync = val
    end

    def nosync_value?
      !@nosync.nil?
    end

    def nosync?
      @nosync == true
    end


  end
end
