RSpec.describe CorpPass::Logger do
  before(:all) do
    @string_io = StringIO.new
    @logger = ::Logger.new(@string_io)
    @cp_logger = CorpPass::Logger.new(@logger)
  end

  after(:each) do
    @string_io.rewind
  end

  after(:all) do
    @cp_logger.unsubscribe_all
    @string_io.close
  end

  it 'should log with the default tag' do
    @cp_logger.info('foobar')
    @string_io.rewind
    expect(@string_io.gets).to eq("[CorpPass] foobar\n")
  end

  it 'should log with the tags set' do
    @cp_logger.tags = %w(foo bar)
    @cp_logger.info('foobar')
    @string_io.rewind
    expect(@string_io.gets).to eq("[foo] [bar] foobar\n")
    @cp_logger.default_tags!
  end

  it 'sets default tags' do
    @cp_logger.tags = %w(foo bar)
    @cp_logger.default_tags!
    expect(@cp_logger.tags).to eq(['CorpPass'])
  end

  describe 'Logging with severity adds message with the right severity' do
    it 'logs debug correctly' do
      expect(@logger).to receive(:add).with(::Logger::DEBUG, 'foobar')
      @cp_logger.debug('foobar')
    end

    it 'logs error correctly' do
      expect(@logger).to receive(:add).with(::Logger::ERROR, 'foobar')
      @cp_logger.error('foobar')
    end

    it 'logs fatal correctly' do
      expect(@logger).to receive(:add).with(::Logger::FATAL, 'foobar')
      @cp_logger.fatal('foobar')
    end

    it 'logs info correctly' do
      expect(@logger).to receive(:add).with(::Logger::INFO, 'foobar')
      @cp_logger.info('foobar')
    end

    it 'logs warn correctly' do
      expect(@logger).to receive(:add).with(::Logger::WARN, 'foobar')
      @cp_logger.warn('foobar')
    end
  end

  describe 'Subscription' do
    it 'subscribe_all subscribes to libsaml and CorpPass events, and unsubcribe_all removes them' do
      expect(ActiveSupport::Notifications).to receive(:subscribe)
        .with(CorpPass::Logger::LIBSAML_EVENTS).and_call_original
      expect(ActiveSupport::Notifications).to receive(:subscribe)
        .with(CorpPass::Events::PREFIX).and_call_original
      @cp_logger.subscribe_all

      ActiveSupport::Notifications.instrument 'corp_pass.foobar', 'foobar'
      @string_io.rewind
      expect(@string_io.gets).to eq("[CorpPass] [corp_pass.foobar] foobar\n")

      expect(ActiveSupport::Notifications).to receive(:unsubscribe).twice.and_call_original
      @cp_logger.unsubscribe_all
    end
  end
end
