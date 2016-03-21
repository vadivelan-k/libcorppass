RSpec.describe CorpPass::Util do
  describe ':string_to_boolean' do
    it 'should return a boolean value unchanged' do
      expect(CorpPass::Util.string_to_boolean(true)).to be true
      expect(CorpPass::Util.string_to_boolean(false)).to be false
    end

    it 'should convert a "true" string to true in a case-insensitive manner' do
      expect(CorpPass::Util.string_to_boolean('TRUE')).to be true
      expect(CorpPass::Util.string_to_boolean('true')).to be true
      expect(CorpPass::Util.string_to_boolean('TRue')).to be true
    end

    it 'should convert a "false" string to false in a case-insensitive manner' do
      expect(CorpPass::Util.string_to_boolean('FALSE')).to be false
      expect(CorpPass::Util.string_to_boolean('false')).to be false
      expect(CorpPass::Util.string_to_boolean('FAlsE')).to be false
    end

    it 'allows you to set your own custom true and false strings' do
      expect(CorpPass::Util.string_to_boolean('YES', true_string: 'yes', false_string: 'no')).to be true
      expect(CorpPass::Util.string_to_boolean('no', true_string: 'yes', false_string: 'no')).to be false
    end

    it 'raises an error if a string cannot be converted' do
      expect { CorpPass::Util.string_to_boolean('foobar') }.to raise_error ArgumentError
      expect { CorpPass::Util.string_to_boolean('foobar', true_string: 'foo', false_string: 'bar') }
        .to raise_error ArgumentError
    end
  end

  describe 'Warden Throwing' do
    include CorpPass::Test::RackHelper

    after(:each) do
      CorpPass::Test::Config.reset_configuration!
    end

    it 'expect failure app to be called when throwing warden' do
      failure_app = double(:failure_app)
      CorpPass.configuration.failure_app = failure_app

      expect(failure_app).to receive(:call)
      app = lambda do |_env|
        CorpPass::Util.throw_exception(CorpPass::Error.new, CorpPass::WARDEN_SCOPE)
      end
      setup_rack(app).call(env_with_params('/'))
    end

    it 'expect :warden_options and :authentication_error? to find errors thrown by :throw_warden' do
      failure_app = lambda do |env|
        warden_options = CorpPass::Util.warden_options(env)
        expect(warden_options).to be_a(Hash)
        expect(CorpPass::Util.authentication_error?(warden_options)).to be true
        expect(warden_options).to include(type: :exception, scope: CorpPass::WARDEN_SCOPE,
                                          exception: instance_of(CorpPass::Error))
        CorpPass::Test::RackHelper::FAILURE_RESPONSE
      end
      CorpPass.configuration.failure_app = failure_app
      app = lambda do |_env|
        CorpPass::Util.throw_exception(CorpPass::Error.new, CorpPass::WARDEN_SCOPE)
      end
      setup_rack(app).call(env_with_params('/'))
    end
  end
end
