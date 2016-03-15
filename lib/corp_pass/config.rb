require 'logger'
require 'uri'

module CorpPass
  class Config
    attr_accessor :idp_entity
    attr_accessor :sp_entity

    attr_accessor :metadata_directory
    attr_accessor :encryption_key
    attr_accessor :signing_key

    attr_accessor :artifact_resolution_service_url_index
    @artifact_resolution_service_url_index = nil

    attr_accessor :failure_app
    attr_accessor :failure_action

    attr_reader :provider
    @provider = 'CorpPass::Providers::Actual'
    def provider=(value)
      klass = value.is_a?(String) ? value.constantize : value
      fail "Provider #{klass} does not inherit from CorpPass::Providers::Base" unless klass < CorpPass::Providers::Base
      @provider = klass
    end

    attr_accessor :timeout
    @timeout = 1800 # timeout since last activity, in seconds
    attr_accessor :session_max_lifetime
    @session_max_lifetime = 86400 # maximum session lifetime, in seconds

    attr_accessor :eservice_id # E-Service ID For CorpPass

    attr_writer :sso_target
    @sso_target = nil
    def sso_target
      @sso_target ||= begin
                        uri = URI(sp_entity)
                        port = uri.port == uri.class::DEFAULT_PORT ? '' : ":#{uri.port}"
                        "#{uri.scheme}://#{uri.host}#{port}"
                      end
    end

    attr_accessor :sso_idp_initiated_base_url

    attr_accessor :proxy_address
    attr_accessor :proxy_port

    @slo_enabled = true
    attr_reader :slo_enabled

    def slo_enabled=(value)
      @slo_enabled = CorpPass::Util.string_to_boolean(value)
    end
  end
end
