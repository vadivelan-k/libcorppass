require 'yaml'
require 'saml'
require 'warden'

module CorpPass
  class Error < ::StandardError; end

  require 'corp_pass/logger'
  require 'corp_pass/events'
  require 'corp_pass/notification'
  require 'corp_pass/response'
  require 'corp_pass/session_serializer'
  require 'corp_pass/config'
  require 'corp_pass/user'
  require 'corp_pass/providers/actual'
  require 'corp_pass/providers/stub_logout'

  include CorpPass::Notification

  WARDEN_SCOPE = :corp_pass
  DEFAULT_PROVIDER = CorpPass::Providers::Actual

  def self.configuration
    @configuration ||= CorpPass::Config.new
  end

  def self.load_yaml(file, environment)
    yaml = read_yaml(file)
    config = yaml[environment] || yaml['default']
    fail 'Invalid CorpPass configuration file' unless config

    config.keys.each do |key|
      method = "#{key}="
      if configuration.respond_to?(method)
        configuration.send(method, config[key])
      else
        fail "Unknown CorpPass configuration option #{key}"
      end
    end
    yield configuration if block_given?
  end

  def self.read_yaml(file)
    YAML.load(ERB.new(File.read(file)).result)
  end
  private_class_method :read_yaml

  def self.configure
    yield configuration
  end

  # CorpPass Setup can only be run once
  def self.setup!
    fail 'Setup already completed' if @setup
    @setup = true

    setup_libsaml
    CorpPass::Timeout.setup_warden_timeout
    setup_provider!
  end

  def self.setup_warden_manager!(config)
    config_class = config.class
    fail "Config provided #{config_class} does not inherit Warden::Config" unless config_class <= Warden::Config
    default_provider = DEFAULT_PROVIDER.new
    strategy_name = default_provider.warden_strategy_name
    Warden::Strategies.add(strategy_name, default_provider.warden_strategy)

    config.failure_app = configuration.failure_app.constantize
    config.default_scope = CorpPass::WARDEN_SCOPE
    config.scope_defaults CorpPass::WARDEN_SCOPE,
                          { store: true,
                            strategies: [strategy_name],
                            action: configuration.failure_action }.compact
  end

  # Clears the current provider and makes a new one
  # This allows you to change a provider at run time
  def self.setup_provider!
    @provider = nil
    provider.setup
  end

  def self.provider
    @provider ||= make_provider
  end

  def self.warden(request)
    request.env['warden']
  end

  def self.authenticate!(request)
    warden(request).authenticate!(provider.warden_strategy_name, scope: WARDEN_SCOPE)
  end

  def self.sso_idp_initiated_url
    provider.sso_idp_initiated_url
  end

  def self.slo_request_redirect(name_id)
    provider.slo_request_redirect name_id
  end

  def self.slo_response_redirect(logout_request)
    provider.slo_response_redirect logout_request
  end

  def self.parse_logout_response(request)
    provider.parse_logout_response request
  end

  def self.parse_logout_request(request)
    provider.parse_logout_request request
  end

  def self.logout(request)
    provider.logout(request)
  end

  def self.make_provider
    new_provider = configuration.provider.new
    if Warden::Strategies[new_provider.warden_strategy_name].nil?
      Warden::Strategies.add(new_provider.warden_strategy_name, new_provider.warden_strategy)
    end
    unless configuration.slo_enabled
      class << new_provider
        include CorpPass::Providers::StubLogout
      end
    end
    new_provider
  end
  private_class_method :make_provider

  def self.encryption_key
    Saml.current_provider.encryption_key
  end

  def self.session(warden)
    warden.session(CorpPass::WARDEN_SCOPE)
  end

  def self.setup_libsaml
    Saml.setup do |config|
      config.register_store :file, Saml::ProviderStores::File.new(configuration.metadata_directory,
                                                                  configuration.encryption_key, nil,
                                                                  configuration.signing_key),
                            default: true
    end
  end
  private_class_method :setup_libsaml
end
