FactoryGirl.define do
  factory :saml_response, class: 'Saml::Response' do
    skip_create

    transient do
      xml_path 'spec/fixtures/corp_pass/saml_response.xml'
    end

    trait :invalid do
      transient do
        xml_path 'spec/fixtures/corp_pass/saml_response_invalid.xml'
      end
    end

    initialize_with { Saml::Response.parse File.read(xml_path) }

    trait :encrypt_id do
      after(:build) do |response|
        key_descriptor = response.provider.find_key_descriptor(nil, Saml::Elements::KeyDescriptor::UseTypes::ENCRYPTION)
        response.assertion.subject.encrypted_id = Saml::Util.encrypt_name_id(response.assertion.subject._name_id,
                                                                             key_descriptor)
        response.assertion.subject._name_id = nil
      end
    end

    trait :encrypt_assertion do
      after(:build) do |response|
        certificate = response.provider.certificate(nil, Saml::Elements::KeyDescriptor::UseTypes::ENCRYPTION)
        response.encrypt_assertions(certificate)
      end
    end
  end
end
