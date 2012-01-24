module Remotable
  module ValidateModels
    
    
    def validate_models=(val)
      @validate_models = (val == true)
    end
    
    def validate_models?
      @validate_models == true
    end
    
    def without_validation
      value = self.validate_models?
      self.validate_models = false
      yield
    ensure
      self.validate_models = value
    end
    
    
  end
end
