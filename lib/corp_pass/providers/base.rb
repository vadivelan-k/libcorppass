require 'saml'
require 'corp_pass/timeout'
require 'corp_pass/notification'

module CorpPass
  module Providers
    class Base
      include CorpPass::Notification

      def initialize
      end

      # Override to perform any kinds of setup required
      def setup
      end

      # Returns a URL to redirect to for IdP initiated SSO
      def sso_idp_initiated_url
        fail NotImplementedError, 'Method not implemented'
      end

      # Build a SAML <LogoutRequest> and a URL to redirect to
      # `name_id` should be a string for the name_id we are logging out
      # (i.e. the <NameID> from <Subject> in the SAML Assertion)
      # Should return [url, logout_request] where logout_request is a Saml::Elements::LogoutRequest
      # and url is the URL to redirect to
      def slo_request_redirect(name_id) # rubocop:disable Lint/UnusedMethodArgument
        fail NotImplementedError, 'Method not implemented'
      end

      # Build a SAML <LogoutResponse> and a URL to redirect to
      # `logout_request` should be a Saml::Elements::LogoutRequest (received from the IdP)
      # Should return [url, logout_response] where logout_response is a Saml::Elements::LogoutResponse
      # and URL is the URL to redirect to
      def slo_response_redirect(logout_request) # rubocop:disable Lint/UnusedMethodArgument
        fail NotImplementedError, 'Method not implemented'
      end

      # Parse a SAML <LogoutResponse> received via a HTTP Request
      # `request` should be a Rack::Request (or similarly behaved, like ActionDispatch::Request from rails)
      # Returns a Saml::Elements::LogoutResponse
      def parse_logout_response(request)
        message = Saml::Bindings::HTTPRedirect.receive_message(request, type: :logout_response)
        notify(CorpPass::Events::SLO_RESPONSE, message.to_xml)
        message
      end

      # Parse a SAML <LogoutRequest> received via a HTTP Request
      # `request` should be a Rack::Request (or similarly behaved, like ActionDispatch::Request from rails)
      # Returns a Saml::Elements::LogoutRequest
      def parse_logout_request(request)
        message = Saml::Bindings::HTTPRedirect.receive_message(request, type: :logout_request)
        notify(CorpPass::Events::SLO_REQUEST, message.to_xml)
        message
      end

      # Performs a Warden logout
      def logout(warden)
        warden.logout(CorpPass::WARDEN_SCOPE)
      end

      # Returns the warden strategy name associated with this provider
      def warden_strategy_name
        fail NotImplementedError, 'Method not implemented'
      end

      # Returns the warden strategy class associated with this provider
      def warden_strategy
        fail NotImplementedError, 'Method not implemented'
      end

      private

      def configuration
        CorpPass.configuration
      end

      def sp
        @sp ||= Saml.provider(configuration.sp_entity)
      end

      def idp
        @idp ||= Saml.provider(configuration.idp_entity)
      end
    end

    class BaseStrategy < Warden::Strategies::Base
      def warden
        env['warden']
      end

      def valid?
        self.class == CorpPass.provider.warden_strategy
      end

      def configuration
        CorpPass.configuration
      end

      # Return a string to print to the console
      def test_authentication!
        raise NotImplementedError # rubocop:disable Style/SignalException
      end
    end
  end
end
