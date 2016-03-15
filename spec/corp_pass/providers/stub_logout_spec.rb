RSpec.describe CorpPass::Providers::StubLogout do
  let(:sp_entity) { 'https://sp.example.com/saml/metadata' }
  let(:idp_entity) { 'https://idp.example.com/saml2/idp/metadata' }

  before(:all) do
    Saml.current_provider = Saml.provider(CorpPass.configuration.sp_entity)
  end

  subject do
    @object = Object.new
    @object.instance_eval do
      def sp
        Saml.provider(CorpPass.configuration.sp_entity)
      end
    end
    @object.extend(CorpPass::Providers::StubLogout)
    @object
  end

  context 'HTTP-Redirect' do
    it 'creates a successful LogoutResponse' do
      _, slo_response = subject.slo_request_redirect('S1234567A')
      expect(slo_response.in_response_to).to eq('foobar')
    end

    it 'does not implement IDP initiated LogoutRequest handling' do
      expect { subject.slo_response_redirect(nil) }.to raise_error(NotImplementedError)
      expect { subject.parse_logout_request(nil) }.to raise_error(NotImplementedError)
    end
  end
end
