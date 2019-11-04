require "active_resource/threadsafe_attributes"

module Remotable
  module Nosync

    def self.included(base)
      base.include InstanceMethods
    end

    def self.extended(base)
      base.extend ClassMethods
    end

    module InstanceMethods

      def nosync!
        self.nosync = true
      end

      def reset_nosync!
        remove_instance_variable(:@nosync) if instance_variable_defined?(:@nosync)
      end

      def nosync(new_value=true)
        old_value = _nosync
        self.nosync = new_value
        yield
      ensure
        self.nosync = old_value
      end

      def nosync=(val)
        @nosync = val
      end

      def nosync_value?
        !_nosync.nil?
      end

      def nosync?
        !!_nosync
      end

    private

      def _nosync
        @nosync if instance_variable_defined?(:@nosync)
      end

    end

    module ClassMethods
      include ThreadsafeAttributes
      include InstanceMethods

      def reset_nosync!
        self.nosync = nil
      end

      def nosync=(val)
        self._nosync = val
      end

    private
      threadsafe_attribute :_nosync
    end

  end
end
