require 'nokogiri'
require 'xmldsig'
require 'openssl'
require 'libsaml'

module CorpPass
  module Metadata
    XPATH_SIG_CERT_ELEMENT = '//ds:Signature//ds:X509Certificate'.freeze
    XPATH_CERT_ELEMENT = '//md:KeyDescriptor[@use="%s"]//ds:X509Certificate'.freeze
    XPATH_ENTITY_ID = '/*/@entityID'.freeze
    XPATH_ACS_LOCATION = '//md:AssertionConsumerService/@Location'.freeze
    XPATH_SLO_LOCATION = '//md:SingleLogoutService/@Location'.freeze

    def self.generate(args)
      unsigned = template

      populate_key_descriptor_certificate!(unsigned, 'signing', args[:signing_crt])
      populate_key_descriptor_certificate!(unsigned, 'encryption', args[:encryption_crt])

      populate_attribute!(unsigned, XPATH_ENTITY_ID, args[:entity_id])
      populate_attribute!(unsigned, XPATH_ACS_LOCATION, args[:acs])
      populate_attribute!(unsigned, XPATH_SLO_LOCATION, args[:slo])

      populate_signature_certificate!(unsigned, args[:signing_crt])
      signed = sign_document(unsigned, args[:signing_key])
      fail 'Signature verification failed' unless validate_signature(signed, args[:signing_crt])

      validate_metadata(signed)

      write_xml(signed, args[:out_file])
    end

    def self.template
      xml = IO.read('lib/corp_pass/metadata_template.xml')
      Nokogiri::XML(xml)
    end

    def self.populate_signature_certificate!(xml, cert)
      encoded_cert = encode_certificate(cert)

      xml.xpath(XPATH_SIG_CERT_ELEMENT)[0].content = encoded_cert
    end

    def self.populate_key_descriptor_certificate!(xml, use, cert)
      encoded_cert = encode_certificate(cert)

      cert_element = xml.xpath(format(XPATH_CERT_ELEMENT, use))[0]
      cert_element.content = encoded_cert
    end

    def self.encode_certificate(cert)
      cert = OpenSSL::X509::Certificate.new(IO.read(cert))
      Base64.encode64(cert.to_der).delete("\n")
    end

    def self.populate_attribute!(xml, xpath, value)
      xml.xpath(xpath)[0].value = value
    end

    def self.sign_document(xml, key)
      private_key = OpenSSL::PKey::RSA.new(IO.read(key))

      unsigned_document = Xmldsig::SignedDocument.new(xml)
      unsigned_document.sign(private_key)
    end

    def self.validate_signature(xml, crt)
      certificate = OpenSSL::X509::Certificate.new(IO.read(crt))
      signed_document = Xmldsig::SignedDocument.new(xml)
      signed_document.validate do |signature_value, data|
        certificate.public_key.verify(OpenSSL::Digest::SHA256.new, signature_value, data)
      end
    end

    def self.validate_metadata(xml)
      Saml::Elements::EntityDescriptor.parse(xml, single: true)
    end

    def self.write_xml(xml, path)
      File.open(path, 'w:UTF-8') do |f|
        f.write xml
      end
    end
  end
end
