require "uri"


module Remotable
  module CoreExt
    module URI
      
      
      def join_url_segments(*segments)
        segments = segments.dup.flatten
        first_segment = segments.shift.gsub(/\/$/, "")
        segments.map! { |seg| seg.gsub(/(^\/)|(\/$)/, "") }
        [first_segment, *segments].join("/")
      end
      
      
    end
  end
end


::URI.extend(Remotable::CoreExt::URI)
