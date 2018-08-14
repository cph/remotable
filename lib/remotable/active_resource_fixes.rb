require "active_resource"
require "active_support/concern"


module ActiveResourceFixes
  extend ActiveSupport::Concern


  # ! ActiveModel::AttributeMethods assumes that :attribute is the target
  # for attribute lookup. ActiveResource doesn't define that method.
  def attribute(method)
    attributes[method]
  end


  included do
    alias_method_chain :destroy, :validation
  end


  # ActiveResource::Validations overrides ActiveResource::Base#save
  # to rescue from ActiveResource::ResourceInvalid and record the
  # resource's errors. Do the same for `destroy`.
  def destroy_with_validation
    destroy_without_validation
  rescue ActiveResource::ResourceInvalid => error
    # cache the remote errors because every call to <tt>valid?</tt> clears
    # all errors. We must keep a copy to add these back after local
    # validations.
    @remote_errors = error
    load_remote_errors(@remote_errors, true)
    false
  end

end

ActiveResource::Base.send(:include, ActiveResourceFixes)



module ActiveResourceJsonFormatFixes

  def decode(json)
    return {} if json.blank? # <-- insert this line. json will be nil if response is 304
    super
  end

end

ActiveResource::Formats::JsonFormat.extend ActiveResourceJsonFormatFixes



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
