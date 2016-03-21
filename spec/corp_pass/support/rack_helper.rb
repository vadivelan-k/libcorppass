require 'corp_pass'
require 'rack'

module CorpPass
  module Test
    module RackHelper
      include Warden::Test::Helpers
      FAILURE_RESPONSE = [401, { 'Content-Type' => 'text/plain' }, ['You Fail!']].freeze
      SUCCESS_RESPONSE = [200, { 'Content-Type' => 'text/plain' }, ['You Win']].freeze
      FAILURE_APP = ->(_e) { FAILURE_RESPONSE }
      SUCCESS_APP = ->(_e) { SUCCESS_RESPONSE }

      def setup_rack(app = nil, mapping = {}, middlewares = [], &block)
        app ||= block if block_given?

        Rack::Builder.new do
          use Rack::Session::Cookie, secret: 'foobar'
          middlewares.each do |middleware|
            use middleware
          end
          use Warden::Manager do |warden_config|
            CorpPass.setup_warden_manager!(warden_config)
          end
          use CorpPass::Test::RackHelper::HookMiddleware
          if app.nil? && !mapping.empty?
            mapping.each do |route, proc|
              map route, &proc
            end
          else
            run app
          end
        end
      end

      def env_with_params(path = '/', params = {}, env = {})
        method = params.delete(:method) || 'GET'
        env = { 'HTTP_VERSION' => '1.1', 'REQUEST_METHOD' => method.to_s }.merge(env)
        # Delete the following keys to prevent the new URL from being overwritten when 
        # MockRequest merges the provided `env` hash
        %w(SERVER_NAME SERVER_PORT QUERY_STRING PATH_INFO rack.url_scheme).each do |key|
          env.delete(key)
        end
        Rack::MockRequest.env_for("#{path}?#{Rack::Utils.build_query(params)}", env)
      end

      def env_with_url(url, env = {})
        # Delete the following keys to prevent the new URL from being overwritten when 
        # MockRequest merges the provided `env` hash
        %w(SERVER_NAME SERVER_PORT QUERY_STRING PATH_INFO rack.url_scheme).each do |key|
          env.delete(key)
        end
        Rack::MockRequest.env_for(url, env)
      end

      # This middleware is used to cause the Warden hooks to be run
      class HookMiddleware
        def initialize(app)
          @app = app
        end

        def call(env)
          CorpPass.authenticated?(env['warden'])
          @app.call(env)
        end
      end
    end
  end
end
