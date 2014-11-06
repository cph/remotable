require "remotable/version"
require "remotable/nosync"
require "remotable/null_remote"
require "remotable/validate_models"
require "remotable/with_remote_model_proxy"
require "remotable/errors"
require "remotable/logger_wrapper"


# Remotable keeps a locally-stored ActiveRecord
# synchronized with a remote resource.
#
# == Requirements ==
# Remotable expects there to be an <tt>expires_at</tt>
# field on the record.
#
# == New resources ==
# When a resource isn't found locally, Remotable
# fetches it from the remote API and creates a local
# copy of the resource.
#
# == Expired resources ==
# When a resource is found locally, Remotable checks
# the value of <tt>expires_at</tt> and re-fetches the
# remote resource if need be.
#
# == Deleted resources ==
# When a remote resources has been deleted, the local
# resource should be removed when it is expired.
#
# == Creating, Updating, and Destroying local resources ==
# Before a local record is saved, Remotable tries
# to apply the changes remotely.
#
#
module Remotable
  extend Nosync
  extend ValidateModels
  
  # By default, Remotable will validate the models you
  # supply it via +remote_model+. You can set validate_models
  # to false to skip this validation. It is recommended that
  # you keep validation on in development and test environments,
  # but turn it off in production.
  self.validate_models = true
  
  # Logger
  def self.logger; @logger ||= LoggerWrapper.new(FakeLogger.new); end
  def self.logger=(logger); @logger = LoggerWrapper.new(logger); end
  
  class << self
    attr_accessor :log_level
    Remotable.log_level = :debug
  end
  
  
  
  # == remote_model( model [optional] )
  # 
  # When called without arguments, this method returns
  # the remote model connected to this local ActiveRecord
  # model.
  #
  # When called with an argument, it extends the ActiveRecord
  # model on which it is called.
  #
  # <tt>model</tt> can be a class that inherits from any
  # of these API consumers:
  #
  #  * ActiveResource
  # 
  # <tt>model</tt> can be any object that responds
  # to these two methods for getting a resource:
  #
  #  * +new_resource+
  #  * +find_by(path)+ or +find_by(remote_attr, value)+
  #      +find_by+ can be defined to take either one argument or two.
  #      If it takes one argument, it will be passed path.
  #      If it takes two, it will be passed remote_attr and value.
  #  * (Optional) +find_by_for_local(local_record, remote_key, fetch_value)+
  # 
  # Resources must respond to:
  #
  #  * +save+ (return true on success and false on failure)
  #  * +destroy+
  #  * +errors+ (returns a hash of error messages by attribute)
  #  * getters and setters for each attribute
  #
  def remote_model(*args)
    if args.length >= 1
      @remote_model = args.first
      
      @__remotable_included ||= begin
        require "remotable/active_record_extender"
        include Remotable::ActiveRecordExtender
        true
      end
      
      extend_remote_model(@remote_model) if @remote_model
    end
    @remote_model
  end
  
  
  
  def with_remote_model(model)
    if block_given?
      begin
        original = self.remote_model
        self.remote_model(model)
        yield
      ensure
        self.remote_model(original)
      end
    else
      WithRemoteModelProxy.new(self, model)
    end
  end
  
  
  
  REQUIRED_CLASS_METHODS = [:find_by, :new_resource]
  REQUIRED_INSTANCE_METHODS = [:save, :errors, :destroy]
  
  class InvalidRemoteModel < ArgumentError; end
  
  class FakeLogger
    
    def write(s)
      puts s
    end
    
    alias :debug :write
    alias :info :write
    alias :warn :write
    alias :error :write
    
  end
  
  
  def self.http_format_time(time)
    return "" unless time
    time.utc.strftime("%a, %e %b %Y %H:%M:%S %Z")
  end
  
  
  
private
  
  def extend_remote_model(remote_model)
    if remote_model.is_a?(Class) and (remote_model < ActiveResource::Base)
      require "remotable/adapters/active_resource"
      remote_model.send(:include, Remotable::Adapters::ActiveResource)
    
    #
    # Adapters for other API consumers can be implemented here
    #
    
    else
      assert_that_remote_model_meets_api_requirements!(remote_model) if Remotable.validate_models?
    end
  end
  
  def assert_that_remote_model_meets_api_requirements!(model)
    unless model.respond_to_all?(REQUIRED_CLASS_METHODS)
      raise InvalidRemoteModel,
        "#{model} cannot be used as a remote model with Remotable " <<
        "because it does not define these methods: #{model.does_not_respond_to(REQUIRED_CLASS_METHODS).join(", ")}."
    end
    instance = model.new_resource
    unless instance.respond_to_all?(REQUIRED_INSTANCE_METHODS)
      raise InvalidRemoteModel,
        "#{instance.class} cannot be used as a remote resource with Remotable " <<
        "because it does not define these methods: #{instance.does_not_respond_to(REQUIRED_INSTANCE_METHODS).join(", ")}."
    end
  end
  
end


ActiveRecord::Base.extend(Remotable) if defined?(ActiveRecord::Base)
