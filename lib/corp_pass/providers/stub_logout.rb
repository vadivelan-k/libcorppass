module CorpPass
  module Providers
    # To be included in a provider to provide stub logout
    module StubLogout
      def slo_request_redirect(_name_id)
        destination = sp.single_logout_service_url(Saml::ProtocolBinding::HTTP_REDIRECT)
        slo_response = make_stub_logout_response(destination)
        [Saml::Bindings::HTTPRedirect.create_url(slo_response), slo_response]
      end

      def slo_response_redirect(_logout_request)
        fail NotImplementedError
      end

      def parse_logout_response(_request)
        destination = idp.single_logout_service_url(Saml::ProtocolBinding::HTTP_REDIRECT)
        make_stub_logout_response(destination)
      end

      def parse_logout_request(_request)
        fail NotImplementedError
      end

      private

      def make_stub_logout_response(destination)
        response = Saml::LogoutResponse.new destination: destination,
                                            in_response_to: 'foobar',
                                            status_value: Saml::TopLevelCodes::SUCCESS
        response._id = 'foobar'
        response
      end
    end
  end
end
