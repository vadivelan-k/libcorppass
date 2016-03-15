require 'active_support/tagged_logging.rb'

module CorpPass
  class Logger
    attr_accessor :tags
    attr_reader :logger

    LIBSAML_EVENTS = /^.+\.saml$/

    def initialize(logger)
      @logger = ActiveSupport::TaggedLogging.new(logger)
      default_tags!
    end

    def default_tags!
      self.tags = ['CorpPass']
    end

    def debug(message)
      tagged(::Logger::DEBUG, message)
    end

    def error(message)
      tagged(::Logger::ERROR, message)
    end

    def fatal(message)
      tagged(::Logger::FATAL, message)
    end

    def info(message)
      tagged(::Logger::INFO, message)
    end

    def warn(message)
      tagged(::Logger::WARN, message)
    end

    def subscribe_all
      [subscribe(CorpPass::Events::PREFIX), subscribe(LIBSAML_EVENTS)]
    end

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
