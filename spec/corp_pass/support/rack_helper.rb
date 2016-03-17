require 'corp_pass'
require 'rack'

module CorpPass
  module Test
    module RackHelper
      include Warden::Test::Helpers

      FAILURE_APP = ->(_e) { [401, { 'Content-Type' => 'text/plain' }, ['You Fail!']] }
      SUCCESS_APP = ->(_e) { [200, { 'Content-Type' => 'text/plain' }, ['You Win']] }

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
        env.delete('PATH_INFO')
        Rack::MockRequest.env_for("#{path}?#{Rack::Utils.build_query(params)}", env)
      end
    end
  end
end
