module Remotable
  class LoggerWrapper

    def initialize(logger)
      @logger = logger
    end

    attr_reader :logger

    def debug(*args)
      logger.debug(*args) if log? :debug
    end

    def info(*args)
      logger.info(*args) if log? :info
    end

    def warn(*args)
      logger.warn(*args) if log? :warn
    end

    def error(*args)
      logger.error(*args) if log? :error
    end

  private

    LEVELS = [:debug, :info, :warn, :error].freeze

    def log?(value)
      level = LEVELS.index(Remotable.log_level)
      value = LEVELS.index(value)
      value >= level
    end

  end
end
