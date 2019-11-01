require "active_resource/threadsafe_attributes"

module Remotable
  module ValidateModels
    include ThreadsafeAttributes

    def self.extended(*args)
      threadsafe_attribute :_validate_models
    end

    def validate_models=(val)
      self._validate_models = (val == true)
    end

    def validate_models?
      _validate_models == true
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
