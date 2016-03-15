require 'saml'
require 'corp_pass/timeout'
require 'corp_pass/notification'

module CorpPass
  module Providers
    class Base
      def initialize
      end

      # Override to perform any kinds of setup required
      def setup
      end

      def sso_idp_initiated_url
        fail NotImplementedError, 'Method not implemented'
      end

      # Should return [url, logout_request] where logout_request is an object that responds to :_id
      def slo_request_redirect(_name_id)
        fail NotImplementedError, 'Method not implemented'
      end

      # Should return [url, logout_response] where logout_request is an object that responds to :status
      def slo_response_redirect(_logout_request)
        fail NotImplementedError, 'Method not implemented'
      end

      # Should return an object that responds to :in_response_to
      def parse_logout_response(_request)
        fail NotImplementedError, 'Method not implemented'
      end

      # Should return an object that responds to :name_id
      def parse_logout_request(_request)
        fail NotImplementedError, 'Method not implemented'
      end

      def logout(request)
        CorpPass.warden(request).logout CorpPass::WARDEN_SCOPE
      end

      def warden_strategy_name
        fail NotImplementedError, 'Method not implemented'
      end

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
