RSpec.describe CorpPass::Config do
  subject { CorpPass::Config.new }

  describe :provider do
    it 'constantizes the value provided' do
      subject.provider = 'CorpPass::Providers::Actual'
      expect(subject.provider).to be CorpPass::Providers::Actual
    end

    it { expect { subject.provider = 'Foobar::Does::Not::Exist' }.to raise_error(NameError) }
    it 'raises an error when provided with a class that does not inherit properly' do
      expect { subject.provider = 'CorpPass::Config' }
        .to raise_error(RuntimeError, 'Provider CorpPass::Config does not inherit from CorpPass::Providers::Base')
    end
  end

  describe :sso_target do
    context 'when unprovided' do
      it 'returns the correct base domain of the provided SP Entity with the default port' do
        subject.sp_entity = 'https://www.example.com/saml/metadata'
        expect(subject.sso_target).to eq('https://www.example.com')
      end

      it 'returns the correct base domain of the provided SP Entity with the right port' do
        subject.sp_entity = 'http://www.example.com:443/saml/metadata'
        expect(subject.sso_target).to eq('http://www.example.com:443')
      end
    end

    context 'when provided' do
      it 'returns the provided value regardless of the SP Entity' do
        subject.sp_entity = 'http://www.example.com:443/saml/metadata'
        subject.sso_target = 'foobar'
        expect(subject.sso_target).to eq('foobar')
      end
    end
  end
end
