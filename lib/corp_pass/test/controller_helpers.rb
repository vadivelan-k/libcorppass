module CorpPass
  module Test
    # +ControllerHelpers+ provides a facility to test controllers in isolation
    # when using +ActionController::TestCase+ allowing you to quickly +sign_in+ or
    # +sign_out+ a user. Do not use +ControllerHelpers+ in integration tests.
    #
    # Notice you should not test Warden specific behavior (like Warden callbacks)
    # using +ControllerHelpers+ since it is a stub of the actual behavior. Such
    # callbacks should be tested in your integration suite instead.
    #
    # This is adapted from +Devise::TestHelpers+
    module ControllerHelpers
      include Warden::Test::Helpers

      def self.included(base)
        base.class_eval do
          before(:each) do
            setup_controller_for_warden
            warden
          end
        end
      end

      # Override process to consider Warden.
      def process(*)
        # Make sure we always return @response, a la ActionController::TestCase::Behaviour#process,
        # even if warden interrupts
        _catch_warden { super } # || @response  # _catch_warden will setup the @response object

        # process needs to return the ActionDispath::TestResponse object
        @response
      end

      # Note: You need to setup the environment variables and the response in the controller.
      def setup_controller_for_warden
        @request.env['action_controller.instance'] = @controller
      end

      # Quick access to Rack's <tt>env['warden']</tt> as a +Warden::Proxy+.
      #
      # @return [Warden::Proxy]
      def warden
        @request.env['warden'] ||= begin
          manager = Warden::Manager.new(nil, &Rails.application.config.middleware.find do |m|
            m.name == 'RailsWarden::Manager'
          end.block)
          Warden::Proxy.new(@request.env, manager)
        end
      end

      protected

      # Catch warden continuations and handle like the middleware would.
      # Returns nil when interrupted, otherwise the normal result of the block.
      def _catch_warden(&block)
        result = catch(:warden, &block)

        env = @controller.request.env

        result ||= {}

        # Set the response. In production, the rack result is returned
        # from Warden::Manager#call, which the following is modelled on.
        case result
        when Array
          if result.first == 401 && intercept_401?(env) # does this happen during testing?
            process_unauthenticated(env)
          else
            result
          end
        when Hash
          process_unauthenticated(env, result)
        else
          result
        end
      end

      def process_unauthenticated(env, options = {})
        options[:action] ||= :unauthenticated
        proxy = env['warden']
        result = options[:result] || proxy.result

        ret = build_response(env, options, proxy, result)

        # ensure that the controller response is set up. In production, this is
        # not necessary since warden returns the results to rack. However, at
        # testing time, we want the response to be available to the testing
        # framework to verify what would be returned to rack.
        if ret.is_a?(Array)
          # ensure the controller response is set to our response.
          setup_controller_response(ret)
        end

        ret
      end

      def setup_controller_response(ret)
        @controller.response ||= @response
        @response.status = ret.first
        @response.headers.clear
        ret.second.each { |k, v| @response[k] = v }
        @response.body = ret.third
      end

      def build_response(env, options, proxy, result)
        case result
        when :redirect
          body = proxy.message || "You are being redirected to #{proxy.headers['Location']}"
          [proxy.status, proxy.headers, [body]]
        when :custom
          proxy.custom_response
        else
          run_failure_app(env, options)
        end
      end

      def run_failure_app(env, options)
        env['PATH_INFO'] = "/#{options[:action]}"
        env['warden.options'] = options
        Warden::Manager._run_callbacks(:before_failure, env, options)

        status, headers, response = execute_failure_app(env)
        @controller.response.headers.merge!(headers)
        r_opts = { status: status, content_type: headers['Content-Type'], location: headers['Location'] }
        r_opts[Rails.version.start_with?('5') ? :body : :text] = response.body
        @controller.send :render, r_opts
        nil # causes process return @response
      end

      def execute_failure_app(env)
        failure_app = CorpPass.configuration.failure_app.constantize
        failure_action = CorpPass.configuration.failure_action.to_sym
        failure_app.send(failure_action, env).to_a
      end
    end
  end
end
