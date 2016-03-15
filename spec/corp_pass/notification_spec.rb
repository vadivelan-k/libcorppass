RSpec.describe CorpPass::Notification do
  describe :notify do
    class Foobar
      include CorpPass::Notification

      def invoke(payload)
        notify('event', payload)
      end

      def subscriber(_name, _payload); end
    end

    before(:all) do
      @obj = Foobar.new
      @subscription = ActiveSupport::Notifications
                      .subscribe('corp_pass.foobar.event') do |name, _start, _end, _id, payload|
        @obj.subscriber(name, payload)
      end
    end

    after(:all) do
      ActiveSupport::Notifications.unsubscribe(@subscription)
    end

    it 'instruments and returns the payload' do
      expect(@obj).to receive(:subscriber).with('corp_pass.foobar.event', 'baz')
      expect(@obj.invoke('baz')).to eq('baz')
    end
  end
end
