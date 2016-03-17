require 'timecop'

RSpec.describe CorpPass::Timeout do
  describe :timedout? do
    before(:all) do
      Timecop.freeze
      CorpPass.configuration.timeout = 10
    end

    after(:all) do
      Timecop.return
      # Reset configuration
      CorpPass::Test::Config.reset_configuration!
    end

    let(:now) { Time.current }

    context 'returns false correctly' do
      it { expect(CorpPass::Timeout.inactivity_timeout?(now)).to eq(false) }
      it { expect(CorpPass::Timeout.inactivity_timeout?(now - 9.seconds)).to eq(false) }
    end

    context 'returns true correctly' do
      it { expect(CorpPass::Timeout.inactivity_timeout?(now - 10.seconds)).to eq(true) }
      it { expect(CorpPass::Timeout.inactivity_timeout?(now - 9000.seconds)).to eq(true) }
    end
  end

  describe :session_expired? do
    before(:all) do
      Timecop.freeze
      CorpPass.configuration.session_max_lifetime = 10
    end

    after(:all) do
      Timecop.return
      # Reset configuration
      CorpPass::Test::Config.reset_configuration!
    end

    let(:now) { Time.current }

    context 'returns false correctly' do
      it { expect(CorpPass::Timeout.session_expired?(now)).to eq(false) }
      it { expect(CorpPass::Timeout.session_expired?(now - 9.seconds)).to eq(false) }
    end

    context 'returns true correctly' do
      it { expect(CorpPass::Timeout.session_expired?(nil)).to eq(true) }
      it { expect(CorpPass::Timeout.session_expired?(now - 10.seconds)).to eq(true) }
      it { expect(CorpPass::Timeout.session_expired?(now - 9000.seconds)).to eq(true) }
    end
  end

  describe :setup_warden_timeout do
    include CorpPass::Test::RackHelper

    class SkipMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        CorpPass::Timeout.skip_timeout_refresh(env) if env['PATH_INFO'] == '/skip'
        @app.call(env)
      end
    end

    before(:all) do
      ok_response = lambda do |e|
        if e['warden'].authenticated?
          [200, { 'Content-Type' => 'text/plain' }, 'OK']
        else
          [401, { 'Content-Type' => 'text/plain' }, 'You Fail']
        end
      end

      mapping = {
        '/foobar' => proc do
          run ok_response
        end,
        '/skip' => proc do
                     run ok_response
                   end
      }

      @app = setup_rack(nil, mapping, [SkipMiddleware]).to_app
      @user = create :corp_pass_user
      Timecop.freeze
      CorpPass.configuration.timeout = 10
      CorpPass.configuration.session_max_lifetime = 12
    end

    after(:each) do
      Warden.test_reset!
    end

    after(:all) do
      Timecop.return
      CorpPass::Test::Config.reset_configuration!
    end

    it 'should set last_request_at after each request' do
      initial_time = Time.now.utc.to_i
      env = env_with_params('/foobar')
      login_as(@user)
      @app.call(env)
      expect(CorpPass::Timeout.last_request(env['warden']).to_i).to eq(initial_time)

      Timecop.travel 5.seconds
      login_as(@user, event: :set_user)
      @app.call(env)
      expect(CorpPass::Timeout.last_request(env['warden']).to_i).to eq(initial_time + 5)
    end

    it 'should not touch the last_request_at when skip_timeout_refresh is called' do
      env = env_with_params('/foobar')
      login_as(@user)
      @app.call(env)
      expected_timestamp = CorpPass::Timeout.last_request(env['warden'])
      expect(expected_timestamp).to_not be_nil

      Timecop.travel 10.seconds
      env = env_with_params('/skip', {}, env)
      login_as(@user, event: :set_user)
      @app.call(env)
      expect(CorpPass::Timeout.last_request(env['warden'])).to eq(expected_timestamp)
    end

    it 'should not log the user out before timeout' do
      env = env_with_params('/foobar')
      login_as(@user)
      @app.call(env)

      Timecop.travel 5.seconds
      login_as(@user, event: :set_user)
      expect { @app.call(env) }.to_not throw_symbol(:warden, scope: CorpPass::WARDEN_SCOPE, type: :timeout)
      expect(env['warden'].authenticated?).to eq(true)
    end

    it 'should log the user out after timeout' do
      env = env_with_params('/foobar')
      login_as(@user)
      @app.call(env)

      Timecop.travel 11.seconds
      login_as(@user, event: :set_user)
      expect { @app.call(env) }.to throw_symbol(:warden, scope: CorpPass::WARDEN_SCOPE,
                                                         type: :timeout)
      expect(env['warden'].authenticated?).to eq(false)
    end

    it 'should not change the session_started_at timestamp after initial login' do
      expected = Time.now.utc.to_i
      env = env_with_params('/foobar')
      login_as(@user)
      @app.call(env)

      Timecop.travel 5.seconds
      login_as(@user, event: :set_user)
      @app.call(env)
      expect(CorpPass::Timeout.session_start(env['warden']).to_i).to eq(expected)
    end

    it 'should log the user out after the session maximum length' do
      env = env_with_params('/foobar')
      login_as(@user)
      @app.call(env)

      Timecop.travel 5.seconds
      login_as(@user, event: :set_user)
      @app.call(env)

      Timecop.travel 7.seconds
      login_as(@user, event: :set_user)
      expect { @app.call(env) }.to throw_symbol(:warden, scope: CorpPass::WARDEN_SCOPE,
                                                         type: :timeout)
      expect(env['warden'].authenticated?).to eq(false)
    end
  end
end
