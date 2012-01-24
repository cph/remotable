require "active_resource"


module ActiveResourceFixes
  
  # ActiveResource hacks method_missing without hacking respond_to?
  # In fact, it responds to any method that ends in an equals sign.
  # It also responds to any method that matches an attribute name.
  def respond_to?(method_symbol, include_private=false)
    method_name = method_symbol.to_s
    if method_name =~ /\w+=/
      true
    elsif attributes.include?(method_name)
      true
    else
      super(method_symbol, include_private)
    end
  end
  
end


module ActiveResourceFixes30
  include ActiveResourceFixes
  
  # ! in this method, don't check the Content-Type header: rack doesn't always return it
  def load_attributes_from_response(response)
    if !response.body.nil? && response.body.strip.size > 0
      load(self.class.format.decode(response.body))
    end
  end
  
end


module ActiveResourceFixes31
  include ActiveResourceFixes
  
  # ! in this method, don't check the Content-Type header: rack doesn't always return it
  def load_attributes_from_response(response)
    if !response.body.nil? && response.body.strip.size > 0
      load(self.class.format.decode(response.body), true)
      @persisted = true
    end
  end
  
end


if Rails.version < '3.1'
  ActiveResource::Base.send(:include, ActiveResourceFixes30)
else
  ActiveResource::Base.send(:include, ActiveResourceFixes31)
end


# ActiveResource expects that errors will be an array of string
# However, this is not what Rails Responders are inclined to return.

class ActiveResource::Errors
  
  # Grabs errors from an array of messages (like ActiveRecord::Validations).
  # The second parameter directs the errors cache to be cleared (default)
  # or not (by passing true).
  def from_array(array, save_cache=false)
    clear unless save_cache
    hash = array[0] || {}
    hash.each do |key, value|
      Array.wrap(value).each do |message|
        self[key] = message
      end
    end
  end
  
end
