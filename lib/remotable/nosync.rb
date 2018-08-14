module Remotable
  module Nosync


    def nosync!
      self.nosync = true
    end

    def nosync(new_value=true)
      old_value = _nosync
      self.nosync = new_value
      yield
    ensure
      @nosync = old_value
    end

    def nosync=(val)
      @nosync = val
    end

    def nosync_value?
      !_nosync.nil?
    end

    def nosync?
      @nosync == true
    end

  private

    def _nosync
      @nosync if instance_variable_defined?(:@nosync)
    end


  end
end
