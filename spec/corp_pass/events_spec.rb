RSpec.describe CorpPass::Events do
  it { expect(CorpPass::Events.extract_class('corp_pass.foobar.baz')).to eq('foobar') }
  it { expect(CorpPass::Events.extract_event('corp_pass.foobar.baz.is.cool')).to eq('baz.is.cool') }

  describe :find_log_level do
    it 'extracts the right log level' do
      expect(CorpPass::Events.find_log_level('network_error')).to be ::Logger::ERROR
    end

    it 'defaults to DEBUG for unknown events' do
      expect(CorpPass::Events.find_log_level('foobar.foobar')).to be ::Logger::DEBUG
    end
  end
end
