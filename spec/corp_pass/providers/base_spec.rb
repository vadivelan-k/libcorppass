require 'saml'

RSpec.describe CorpPass::Providers::Base do
  include CorpPass::Test::RackHelper

  before(:all) do
    @sp_entity = 'https://sp.example.com/saml/metadata'
    @sp = Saml.provider(@sp_entity)
    Saml.current_provider = @sp
  end

  subject { described_class.new }

  it 'parses a LogoutResponse correctly' do
    destination = @sp.single_logout_service_url(Saml::ProtocolBinding::HTTP_REDIRECT)
    logout_response = Saml::LogoutResponse.new(in_response_to: 'foobar',
                                               status_value: Saml::TopLevelCodes::SUCCESS,
                                               destination: destination)
    url = Saml::Bindings::HTTPRedirect.create_url(logout_response)
    env = env_with_params(url)
    parsed = subject.parse_logout_response(Rack::Request.new(env))
    expect(parsed).to be_a Saml::LogoutResponse
    expect(parsed.in_response_to).to eq('foobar')
    expect(parsed.status.status_code.value).to eq(Saml::TopLevelCodes::SUCCESS)
    expect(parsed.issuer).to eq(@sp_entity)
    expect(parsed.destination).to eq(destination)
  end

  it 'parses LogoutRequest correctly' do
    destination = @sp.single_logout_service_url(Saml::ProtocolBinding::HTTP_REDIRECT)
    logout_request = Saml::LogoutRequest.new(name_id: 'foobar',
                                             destination: destination)
    url = Saml::Bindings::HTTPRedirect.create_url(logout_request)
    env = env_with_params(url)
    parsed = subject.parse_logout_request(Rack::Request.new(env))
    expect(parsed).to be_a Saml::LogoutRequest
    expect(parsed.name_id).to eq('foobar')
    expect(parsed.issuer).to eq(@sp_entity)
    expect(parsed.destination).to eq(destination)
  end

  describe 'Abstract methods' do
    it { expect { subject.sso_idp_initiated_url }.to raise_error(NotImplementedError) }
    it { expect { subject.slo_request_redirect('foobar') }.to raise_error(NotImplementedError) }
    it { expect { subject.slo_response_redirect('foobar') }.to raise_error(NotImplementedError) }
    it { expect { subject.warden_strategy_name }.to raise_error(NotImplementedError) }
    it { expect { subject.warden_strategy }.to raise_error(NotImplementedError) }
  end
end
