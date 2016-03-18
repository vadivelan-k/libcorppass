require 'active_support/tagged_logging.rb'

module CorpPass
  # The CorpPass logger uses ActiveSupport notifications. The log levels for CorpPass events
  # are defined in {CorpPass::Events}.
  #
  # See: {CorpPass::Events}
  #
  # @attr tags [Array<String>] Accessor for the tags to be attached to logs. Defaults to <tt>['CorpPass']</tt>.
  # @attr_reader logger [Logger] Returns the +ActiveSupport::TaggedLogging+ backing instance.
  class Logger
    attr_accessor :tags
    attr_reader :logger

    LIBSAML_EVENTS = /^.+\.saml$/

    # Attaches a CorpPass logger to an existing Logger.
    # {#subscribe_all} has to be called for the logger to begin receiving notification events.
    #
    # @example Log to STDOUT, log level WARN
    #   logger = Logger.new(STDOUT)
    #   logger.level = Logger::WARN
    #   CorpPass::Logger.new(logger).subscribe_all
    #
    # @example Log to Rails logger
    #  CorpPass::Logger.new(Rails.logger).subscribe_all
    def initialize(logger)
      @logger = ActiveSupport::TaggedLogging.new(logger)
      default_tags!
    end

    # Sets the logging tags for this logger to <tt>['CorpPass']</tt>.
    def default_tags!
      self.tags = ['CorpPass']
    end

    # Sends a tagged DEBUG notification.
    # @param message [Object] The message to be tagged
    def debug(message)
      tagged(::Logger::DEBUG, message)
    end

    # Sends a tagged ERROR notification.
    # @param message [Object] The message to be tagged
    def error(message)
      tagged(::Logger::ERROR, message)
    end

    # Sends a tagged FATAL notification.
    # @param message [Object] The message to be tagged
    def fatal(message)
      tagged(::Logger::FATAL, message)
    end

    # Sends a tagged INFO notification.
    # @param message [Object] The message to be tagged
    def info(message)
      tagged(::Logger::INFO, message)
    end

    # Sends a tagged WARN notification.
    # @param message [Object] The message to be tagged
    def warn(message)
      tagged(::Logger::WARN, message)
    end

    # Subscribes this logger to all CorpPass and libsaml event notifications.
    def subscribe_all
      [subscribe(CorpPass::Events::PREFIX), subscribe(LIBSAML_EVENTS)]
    end

    # Unsubscribes this logger from all CorpPass and libsaml event notifications.
    def unsubscribe_all
      @subscription.each do |_regex, subscription|
        ActiveSupport::Notifications.unsubscribe(subscription)
      end
      @subscription = {}
    end

    private

    def tagged(severity, message)
      logger.tagged(*tags) do
        logger.add(severity, message)
      end
    end

    def subscribe(regex)
      @subscription ||= {}
      @subscription[regex] ||= ActiveSupport::Notifications
                               .subscribe(regex) do |name, _start_time, _finish_time, _id, payload|
        event(name, payload)
      end
    end

    def event(name, payload)
      event = CorpPass::Events.extract_event(name)
      tagged(CorpPass::Events.find_log_level(event), "[#{name}] #{payload}")
    end
  end
end
