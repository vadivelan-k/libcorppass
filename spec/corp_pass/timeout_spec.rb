require 'action_controller'

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

  # FIXME: We really have to test this in a "real" integration test
  # describe 'Mock Controller Integration Tests', type: :controller do
  #   controller(ActionController::Base) do
  #     def self.user
  #       @user ||= create :user
  #     end
  #
  #     prepend_before_filter :skip_timeout_refresh, only: :skip
  #     before_action :set_user
  #     def foobar
  #       render nothing: true
  #     end
  #
  #     def skip
  #       render nothing: true
  #     end
  #
  #     protected
  #
  #     def skip_timeout_refresh
  #       CorpPass::Timeout.skip_timeout_refresh(request)
  #     end
  #
  #     def set_user
  #       warden.set_user(user)
  #     end
  #   end
  #
  #   before(:all) do
  #     @user = create :corp_pass_user
  #     Timecop.freeze
  #     CorpPass.configuration.timeout = 10
  #     CorpPass.configuration.session_max_lifetime = 12
  #   end
  #
  #   around(:each) do |spec|
  #     login_as(@user)
  #     spec.run
  #   end
  #
  #   after(:all) do
  #     Timecop.return
  #     # Reset configuration
  #     CorpPass.load_yaml('config/corp_pass.yml', Rails.env)
  #   end
  #
  #   it 'should set last_request_at after each request' do
  #     routes.draw do
  #       get '/anonymous/foobar'
  #     end
  #
  #     initial_time = Time.now.utc.to_i
  #     get :foobar
  #     expect(CorpPass::Timeout.last_request(warden).to_i).to eq(initial_time)
  #
  #     Timecop.travel 5.seconds
  #     get :foobar
  #     expect(CorpPass::Timeout.last_request(warden).to_i).to eq(initial_time + 5)
  #   end
  #
  #   it 'should not touch the last_request_at when skip_timeout_refresh is called' do
  #     routes.draw do
  #       get '/anonymous/foobar'
  #       get '/anonymous/skip'
  #     end
  #
  #     get :foobar
  #     expected_timestamp = CorpPass::Timeout.last_request(warden)
  #     expect(expected_timestamp).to_not be_nil
  #     Timecop.travel 10.seconds
  #     get :skip
  #     expect(CorpPass::Timeout.last_request(warden)).to eq(expected_timestamp)
  #   end
  #
  #   it 'should not log the user out before timeout' do
  #     routes.draw do
  #       get '/anonymous/foobar'
  #     end
  #     get :foobar
  #     Timecop.travel 5.seconds
  #     expect { get :foobar }.to_not throw_symbol(:warden, scope: CorpPass::WARDEN_SCOPE, type: :timeout)
  #     expect(warden.authenticated?).to eq(true)
  #   end
  #
  #   it 'should log the user out after timeout' do
  #     routes.draw do
  #       get '/anonymous/foobar'
  #     end
  #     get :foobar
  #     Timecop.travel 11.seconds
  #     expect { get :foobar }.to throw_symbol(:warden, scope: CorpPass::WARDEN_SCOPE,
  #                                                     type: :timeout)
  #     expect(warden.authenticated?).to eq(false)
  #   end
  #
  #   it 'should not change the session_started_at timestamp after initial login' do
  #     routes.draw do
  #       get '/anonymous/foobar'
  #     end
  #     expected = Time.now.utc.to_i
  #     Timecop.travel 5.seconds
  #     get :foobar
  #     expect(CorpPass::Timeout.session_start(warden).to_i).to eq(expected)
  #   end
  #
  #   it 'should log the user out after the session maximum length' do
  #     routes.draw do
  #       get '/anonymous/foobar'
  #     end
  #     Timecop.travel 5.seconds
  #     get :foobar
  #
  #     Timecop.travel 7.seconds
  #     expect { get :foobar }.to throw_symbol(:warden, scope: CorpPass::WARDEN_SCOPE,
  #                                                     type: :timeout)
  #     expect(warden.authenticated?).to eq(false)
  #   end
  # end
end
