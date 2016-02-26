module Remotable
  class WithRemoteModelProxy

    def initialize(model, remote_model)
      @model = model
      @remote_model = remote_model
    end

    delegate :respond_to?, :to => :@model

    def method_missing(sym, *args, &block)
      @model.with_remote_model(@remote_model) do
        @model.send(sym, *args, &block)
      end
    end

  end
end
