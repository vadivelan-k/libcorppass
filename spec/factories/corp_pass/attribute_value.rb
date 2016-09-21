FactoryGirl.define do
  factory :attribute_value, class: 'String' do
    skip_create

    transient do
      xml_path 'spec/fixtures/corp_pass/attribute_value.xml'
    end

    initialize_with { File.read(xml_path) }
  end
end
