module Remotable
  module CoreExt
    module Object
      
      
      def respond_to_all?(*methods)
        respond_to = method(:respond_to?)
        methods.flatten.all?(&respond_to)
      end
      
      def responds_to(*methods)
        respond_to = method(:respond_to?)
        methods.flatten.select(&respond_to)
      end
      
      def does_not_respond_to(*methods)
        methods.flatten - self.responds_to(methods)
      end
      
      
    end
  end
end


::Object.extend(Remotable::CoreExt::Object)
::Object.send(:include, Remotable::CoreExt::Object)
