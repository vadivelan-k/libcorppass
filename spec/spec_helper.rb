require 'factory_girl'
require 'warden/test/mock'
require 'rack'
require 'webmock/rspec'
require 'corp_pass'
require 'corp_pass/test/controller_helpers'
require 'corp_pass/support/config'

require 'byebug'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # The settings below are suggested to provide a good initial experience
  # with RSpec, but feel free to customize to your heart's content.
  #   # These two settings work together to allow you to limit a spec run
  #   # to individual examples or groups you care about by tagging them with
  #   # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  #   # get run.
  #   config.filter_run :focus
  #   config.run_all_when_everything_filtered = true
  #
  #   # Allows RSpec to persist some state between runs in order to support
  #   # the `--only-failures` and `--next-failure` CLI options. We recommend
  #   # you configure your source control system to ignore this file.
  #   config.example_status_persistence_file_path = "spec/examples.txt"
  #
  #   # Limits the available syntax to the non-monkey patched syntax that is
  #   # recommended. For more details, see:
  #   #   - http://rspec.info/blog/2012/06/rspecs-new-expectation-syntax/
  #   #   - http://www.teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/
  #   #   - http://rspec.info/blog/2014/05/notable-changes-in-rspec-3/#zero-monkey-patching-mode
  #   config.disable_monkey_patching!
  #
  #   # This setting enables warnings. It's recommended, but in some cases may
  #   # be too noisy due to issues in dependencies.
  #   config.warnings = true
  #
  #   # Many RSpec users commonly either run the entire suite or an individual
  #   # file, and it's useful to allow more verbose output when running an
  #   # individual spec file.
  #   if config.files_to_run.one?
  #     # Use the documentation formatter for detailed output,
  #     # unless a formatter has already been configured
  #     # (e.g. via a command-line flag).
  #     config.default_formatter = 'doc'
  #   end
  #
  #   # Print the 10 slowest examples and example groups at the
  #   # end of the spec run, to help surface which specs are running
  #   # particularly slow.
  #   config.profile_examples = 10
  #
  #   # Run specs in random order to surface order dependencies. If you find an
  #   # order dependency and want to debug it, you can fix the order by providing
  #   # the seed, which is printed after each run.
  #   #     --seed 1234
  config.order = :random
  #
  #   # Seed global randomization in this process using the `--seed` CLI option.
  #   # Setting this allows you to use `--seed` to deterministically reproduce
  #   # test failures related to randomization by passing the same `--seed` value
  #   # as the one that triggered the failure.
  #   Kernel.srand config.seed

  config.include FactoryGirl::Syntax::Methods
  FactoryGirl.definition_file_paths = [File.expand_path('../factories', __FILE__)]
  FactoryGirl.find_definitions

  config.before(:suite) do
    CorpPass::Test::Config.reset_configuration!
    CorpPass.setup!
    default_provider = CorpPass::DEFAULT_PROVIDER.new
    strategy_name = default_provider.warden_strategy_name
    Warden::Strategies.add(strategy_name, default_provider.warden_strategy)

    failure_app = CorpPass.configuration.failure_app.constantize

    Rack::Builder.new do
      use Rack::Session::Cookie, secret: 'foobar'

      use Warden::Manager do |manager|
        manager.failure_app = failure_app

        manager.default_scope = CorpPass::WARDEN_SCOPE
        manager.scope_defaults CorpPass::WARDEN_SCOPE,
                               { store: true,
                                 strategies: [strategy_name],
                                 action: configuration.failure_action }.compact!
      end

      run Warden::Test::Mock
    end
  end

  config.include(CorpPass::Test::ControllerHelpers, type: :controller)
  config.after(:each, type: :controller) do
    Warden.test_reset!
  end
  config.include(Warden::Test::Helpers, type: :feature)
  config.after(:each, type: :feature) do
    Warden.test_reset!
  end
  config.include(Warden::Test::Helpers, type: :request)
  config.after(:each, type: :request) do
    Warden.test_reset!
  end
end
