require 'corp_pass/util'

module CorpPass
  module Timeout
    include CorpPass::Notification

    SKIP_TIMEOUT_REFRESH = 'skip_timeout_refresh'.freeze

    # @param last_request_at [Time]
    def self.inactivity_timeout?(last_request_at)
      last_request_at && last_request_at <= CorpPass.configuration.timeout.to_i.seconds.ago
    end

    # @param session_started_at [Time]
    def self.session_expired?(session_started_at)
      return true unless session_started_at
      session_started_at <= CorpPass.configuration.session_max_lifetime.to_i.seconds.ago
    end

    # Sets +SKIP_TIMEOUT_REFRESH+ in the environment variable hash to +true+.
    # When set to +true+, the logged-in user will not be logged out for inactivity timeout,
    # but will still be logged out for session timeout.
    #
    # @param env [Hash] Rack +env+ variable
    def self.skip_timeout_refresh(env)
      notify(CorpPass::Events::SKIP_TIMEOUT_REFRESH, 'Last request touching skipped')
      env[SKIP_TIMEOUT_REFRESH] = true
    end

    # @return [Time]
    #
    # @param warden [Warden::Proxy] Commonly gotten from Rack's <tt>env['warden']</tt>.
    def self.last_request(warden)
      last_request_at = CorpPass.session(warden)[:last_request_at]
      Time.at(last_request_at).utc if last_request_at.is_a? Integer
    end

    # @return [Time]
    #
    # @param warden [Warden::Proxy] Commonly gotten from Rack's <tt>env['warden']</tt>.
    def self.session_start(warden)
      session_started_at = CorpPass.session(warden)[:session_started_at]
      Time.at(session_started_at).utc if session_started_at.is_a? Integer
    end

    # Sets up both inactivity timeout and session timeout. To disable inactivity timeout, use {skip_timeout_refresh}.
    #
    # See: {skip_timeout_refresh}
    def self.setup_warden_timeout
      Warden::Manager.after_authentication do |_user, warden, _options|
        touch_session_start(warden)
      end

      Warden::Manager.after_set_user do |user, warden, _options|
        scope = CorpPass::WARDEN_SCOPE
        env = warden.request.env

        inactivity_timeout, session_timeout = user_timeout?(env, user, warden)

        if inactivity_timeout || session_timeout
          CorpPass.logout(warden)
          CorpPass::Util.throw_warden(:timeout, scope)
        end

        touch_last_request_at(warden) unless env[CorpPass::Timeout::SKIP_TIMEOUT_REFRESH]
      end
    end

    def self.user_timeout?(env, user, warden)
      inactivity_timeout = inactivity_timeout?(last_request(warden)) && !env[CorpPass::Timeout::SKIP_TIMEOUT_REFRESH]
      notify(CorpPass::Events::INACTIVITY_TIMEOUT, "#{user} has timed out") if inactivity_timeout
      session_timeout = session_expired?(session_start(warden))
      notify(CorpPass::Events::SESSION_TIMEOUT, "#{user} has timed out") if session_timeout
      [inactivity_timeout, session_timeout]
    end
    private_class_method :user_timeout?

    # Sets the last_request_at time to now.
    def self.touch_last_request_at(warden)
      CorpPass.session(warden)[:last_request_at] = Time.now.utc.to_i
    end

    # Sets the session_started_at time to now.
    def self.touch_session_start(warden)
      CorpPass.session(warden)[:session_started_at] = Time.now.utc.to_i
    end

    def self.timeout_thrown?(warden_options)
      !warden_options.nil? && warden_options[:type] == :timeout
    end
  end
end
