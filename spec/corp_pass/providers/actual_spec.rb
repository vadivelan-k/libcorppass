RSpec.describe CorpPass::Providers::Actual do
  let(:sp_entity) { 'https://sp.example.com/saml/metadata' }
  let(:idp_entity) { 'https://idp.example.com/saml2/idp/metadata' }
  let(:idp_host) { URI.parse(idp_entity).host }

  subject { described_class.new }

  before(:all) do
    sp = 'https://sp.example.com/saml/metadata'
    Saml.current_provider = Saml.provider(sp)
    CorpPass.configuration.sp_entity = sp
    Timecop.freeze(Time.utc(2015, 11, 30, 4, 45))
  end

  after(:all) do
    Timecop.return
    CorpPass::Test::Config.reset_configuration!
  end

  describe 'Entity Metadata' do
    it { expect(subject.send(:sp).entity_id).to eq(sp_entity) }
    it { expect(subject.send(:idp).entity_id).to eq(idp_entity) }
    # Disabled until CorpPass gives us a finalised URL
    it { expect(subject.send(:sso_url)).to eq(CorpPass.configuration.sso_idp_initiated_base_url) }
    it do
      expect(subject.send(:artifact_resolution_url))
        .to eq('https://idp.example.com/saml2/idp/ArtifactResolutionService')
    end
    it do
      expect(subject.send(:slo_url_redirect))
        .to eq('https://idp.example.com/saml2/idp/SingleLogoutService')
    end
    it do
      expect(subject.send(:slo_url_soap))
        .to eq('https://idp.example.com/saml2/idp/SingleLogoutService')
    end
  end

  describe 'SSO' do
    context 'IDP Initiated SSO HTTP-Redirect' do
      it 'returns a correctly formatted SSO URL' do
        expected_params = []
        expected_params << %w(RequestBinding HTTPArtifact)
        expected_params << %w(ResponseBinding HTTPArtifact)
        expected_params << ['PartnerId', sp_entity]
        expected_params << %w(Target https://sp.example.com)
        expected_params << %w(NameIdFormat Email)
        expected_params << %w(esrvcId Foobar)
        # expected_params << %w(param1 NULL)
        # expected_params << %w(param2 NULL)
        actual_url = subject.sso_idp_initiated_url
        actual_uri = URI(actual_url)
        actual_params = URI.decode_www_form(actual_uri.query.nil? ? '' : actual_uri.query)
        expect(actual_params).to match_array(expected_params)
      end
    end
  end

  describe 'SLO' do
    context 'HTTP-Redirect' do
      it 'creates the right SP initiated request' do
        _, slo_request = subject.slo_request_redirect('S1234567A')
        expect(slo_request.name_id).to eq('S1234567A')
        expect(slo_request.issuer).to eq(sp_entity)
      end

      it 'creates the right IDP Initiated response' do
        request = Saml::LogoutRequest.parse(File.read('spec/fixtures/corp_pass/logout_request.xml'))
        _, slo_response = subject.slo_response_redirect request
        expect(slo_response.in_response_to).to eq(request._id)
      end
    end
  end

  describe CorpPass::Providers::ActualStrategy do
    subject { CorpPass::Providers::ActualStrategy.new(nil) }

    let(:request) do
      req = double(:request)
      allow(req).to receive(:params).and_return('SAMLArt': 'foobar')
      req
    end

    let(:artifact_resolution_url) do
      subject.send(:artifact_resolution_url)
    end

    describe :resolve_artifact! do
      let(:saml_response) { create(:saml_response, :encrypt_id, :encrypt_assertion) }
      let(:artifact_response) do
        artifact_response = Saml::ArtifactResponse.new(status_value: Saml::TopLevelCodes::SUCCESS)
        artifact_response.response = saml_response
        artifact_response
      end

      context 'Successful resolution' do
        it 'resolves the artifact' do
          expect(Saml::Bindings::HTTPArtifact).to(receive(:resolve)) { saml_response }
          response = nil
          expect { response = subject.resolve_artifact!(double(:request)) }.to_not throw_symbol(:warden)
          expect(response).to_not be nil
          expect(response.class).to eq(CorpPass::Response)
        end
      end

      context 'Network error' do
        it 'retries after a first network error' do
          expect(Saml::Util).to(receive(:verify_xml)) { artifact_response }
          stub_request(:any, artifact_resolution_url).to_timeout.times(1)
                                                     .then.to_return(body: artifact_response.to_soap)
          expect(subject).to receive(:resolve_artifact!).twice.and_call_original
          expect { subject.resolve_artifact!(request) }.to_not throw_symbol
        end

        it 'throws with the right details when it timesout twice' do
          stub_request(:any, artifact_resolution_url).to_timeout.times(2)
          expect(subject).to receive(:resolve_artifact!).twice.and_call_original
          expect { subject.resolve_artifact!(request) }
            .to throw_symbol(:warden, scope: CorpPass::WARDEN_SCOPE,
                                      exception: instance_of(Timeout::Error),
                                      type: :exception)
        end
      end

      context 'Saml error' do
        it 'throws with the right details' do
          expect(Saml::Bindings::HTTPArtifact).to receive(:resolve) do |_, _|
            Saml::ArtifactResponse.parse('<badxml>')
          end
          expect { subject.resolve_artifact!(double(:request)) }
            .to throw_symbol(:warden, scope: CorpPass::WARDEN_SCOPE,
                                      type: :exception,
                                      exception: instance_of(Saml::Errors::UnparseableMessage))
        end
      end

      context 'ArtifactResolutionFailure' do
        let(:exception) { CorpPass::Providers::ArtifactResolutionFailure.new('Artifact resolution failed', nil) }
        it 'throws with the right details' do
          expect(Saml::Bindings::HTTPArtifact).to receive(:resolve) do |_, _|
            raise exception # rubocop:disable Style/SignalException)
          end
          expect { subject.resolve_artifact!(double(:request)) }
            .to throw_symbol(:warden, scope: CorpPass::WARDEN_SCOPE,
                                      exception: exception,
                                      type: :exception)
        end
      end

      context 'SamlResponseValidationFailure' do
        let(:exception) { CorpPass::Providers::SamlResponseValidationFailure.new(['Validation failed!'], nil) }
        it 'throws with the right details' do
          expect(Saml::Bindings::HTTPArtifact).to receive(:resolve) do |_, _|
            raise exception # rubocop:disable Style/SignalException)
          end
          expect { subject.resolve_artifact!(double(:request)) }
            .to throw_symbol(:warden, scope: CorpPass::WARDEN_SCOPE,
                                      exception: exception,
                                      type: :exception)
        end
      end
    end

    describe :check_response! do
      it 'raises an exception when the status is not success' do
        response = Saml::Response.new(sub_status_value: Saml::SubStatusCodes::AUTHN_FAILED)
        expect { subject.check_response!(response) }.to raise_error(CorpPass::Providers::ArtifactResolutionFailure)
      end

      it 'raises an exception when the SAML Response received is invalid' do
        response = create(:saml_response, :invalid)
        expect(response).to receive(:success?).twice.and_return(true) # Skip the ArtifactResolutionFailure exception
        expect { subject.check_response!(response) }.to raise_error(CorpPass::Providers::SamlResponseValidationFailure)
      end
    end

    describe :authenticate! do
      let(:response) do
        saml_response = create(:saml_response, :encrypt_id, :encrypt_assertion)
        CorpPass::Response.new(saml_response)
      end

      before(:each) do
        expect(subject).to receive(:resolve_artifact!).and_return(response)
      end

      it 'successfully authenticates given the right response' do
        expect(subject).to receive(:success!)
        subject.authenticate!
      end

      it 'throws :warden if the user provided fails validation' do
        expect(response.cp_user).to receive(:validate!) do
          raise CorpPass::InvalidUser.new('', nil) # rubocop:disable Style/SignalException)
        end
        expect { subject.authenticate! }
          .to throw_symbol(:warden,
                           scope: CorpPass::WARDEN_SCOPE, type: :exception,
                           exception: instance_of(CorpPass::InvalidUser))
      end
    end

    describe :test_authentication! do
      it 'returns a string of the thrown hash' do
        stub_request(:any, artifact_resolution_url).to_timeout
        exception_message = 'execution expired'
        expected = {
          type: :exception,
          scope: :corp_pass,
          exception: ::Timeout::Error.new(exception_message)
        }
        expect(subject.test_authentication!).to eq(expected.to_s + "\nException: #{exception_message}")
      end
    end
  end
end
