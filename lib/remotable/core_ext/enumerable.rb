module Enumerable

  def map_to_self(result={})
    inject(result) {|hash, value| hash.merge(value => value)}
  end

end
