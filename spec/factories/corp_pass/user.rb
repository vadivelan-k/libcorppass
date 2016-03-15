FactoryGirl.define do
  factory :corp_pass_user, class: 'CorpPass::User' do
    skip_create

    transient do
      xml_path 'spec/fixtures/corp_pass/auth_access.xml'
    end

    trait :invalid do
      transient do
        xml_path 'spec/fixtures/corp_pass/auth_access_invalid.xml'
      end
    end

    initialize_with { new File.read(xml_path) }
  end
end
