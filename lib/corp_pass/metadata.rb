require 'xmldsig'
require 'openssl'
require 'saml'

module CorpPass
  module Metadata
    def self.generate(entity_id:, acs:, slo:, encryption_crt:, signing_key:, signing_crt:)
      entity_descriptor = Saml::Elements::EntityDescriptor.new(entity_id: entity_id)
      sp_descriptor = Saml::Elements::SPSSODescriptor.new(authn_requests_signed: true, want_assertions_signed: true)
      sp_descriptor.add_assertion_consumer_service(Saml::ProtocolBinding::HTTP_REDIRECT, acs, 0, true)
      sp_descriptor.single_logout_services << Saml::ComplexTypes::
              SSODescriptorType::SingleLogoutService.new(binding: Saml::ProtocolBinding::HTTP_REDIRECT, location: slo)

      signing_key_info = Saml::Elements::KeyInfo.new(IO.read(signing_crt))
      sp_descriptor.key_descriptors << Saml::Elements::KeyDescriptor
                                       .new(use: Saml::Elements::KeyDescriptor::UseTypes::SIGNING,
                                            key_info: signing_key_info)
      encryption_key_info = Saml::Elements::KeyInfo.new(IO.read(encryption_crt))
      sp_descriptor.key_descriptors << Saml::Elements::KeyDescriptor
                                       .new(use: Saml::Elements::KeyDescriptor::UseTypes::ENCRYPTION,
                                            key_info: encryption_key_info)
      entity_descriptor.sp_sso_descriptor = sp_descriptor

      key = OpenSSL::PKey::RSA.new(IO.read(signing_key))
      Saml::Util.sign_xml(entity_descriptor) do |data, signature_algorithm|
        key.sign(digest_method(signature_algorithm).new, data)
      end
    end

    def self.digest_method(signature_algorithm)
      digest = signature_algorithm && signature_algorithm =~ /sha(.*?)$/i && $1.to_i
      case digest
        when 256 then
          OpenSSL::Digest::SHA256
        else
          OpenSSL::Digest::SHA1
      end
    end
    private_class_method :digest_method

    def self.write_xml(xml, path)
      File.open(path, 'w:UTF-8') do |f|
        f.write xml
      end
    end
    private_class_method :write_xml
  end
end
