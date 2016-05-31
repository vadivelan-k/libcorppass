RSpec.describe CorpPass::AuthAccess do
  subject { create(:corp_pass_user) }

  it 'should compare equality properly' do
    user = create(:corp_pass_user)
    expect(user).to eq(subject)
  end

  it 'should serialize and deserialize properly' do
    user = create(:corp_pass_user)
    serialized = user.serialize

    deserialized = CorpPass::AuthAccess.deserialize serialized

    expect(deserialized).to eq(user)
  end

  it { expect(subject.auth_access).to eq(File.read('spec/fixtures/corp_pass/auth_access.xml')) }
  it { expect(subject.id).to eq('foobar') }
  it { expect(subject.user_account_type).to eq('User') }
  it { expect(subject.user_id).to eq('S1234567A') }
  it { expect(subject.user_id_country).to eq('SG') }
  it { expect(subject.user_id_date).to eq(Date.new(2011, 1, 15)) }
  it { expect(subject.entity_id).to eq('201000758R') }
  it { expect(subject.entity_status).to eq('Active') }
  it { expect(subject.entity_type).to eq('UEN') }
  it { expect(subject.sp_holder?).to be true }
  it { expect(subject.eservice_count).to be 1 }

  it 'should return the correct set of eservice_result' do
    expected = {
      eservice_id: 'Foobar',
      auth_result_set: [
        {
          entity_id_sub: nil,
          role: 'Acceptor',
          start_date: Date.new(2016, 1, 15),
          end_date: Date.new(2016, 2, 15),
          parameters: [
            { name: 'foo', value: 'bar' },
            { name: 'lorem', value: 'ipsum' }
          ]
        },
        {
          entity_id_sub: 'foobar',
          role: 'Viewer',
          start_date: Date.new(2015, 1, 15),
          end_date: Date.new(2017, 2, 15),
          parameters: []
        }
      ]
    }

    expect(subject.eservice_result).to eq(expected)
  end

  describe 'Validation' do
    context 'Valid document' do
      it { expect(subject.validate).to be true }
      it { expect { subject.validate! }.to_not raise_error }
      it { expect(subject.valid_root?).to be true }
    end

    context 'Invalid document' do
      before(:all) do
        @invalid_user = create(:corp_pass_user, :invalid)
        @invalid_user.validate
      end

      it { expect(@invalid_user.valid?).to be false }
      it { expect { @invalid_user.validate! }.to raise_error CorpPass::InvalidAuthAccess }
      it { expect(@invalid_user.errors.empty?).to be false }

      it 'does not populate :errors before validation is called, and populates after' do
        invalid = described_class.new('<invalid>fail')
        expect(invalid.errors.empty?).to be true
        invalid.validate
        expect(invalid.errors.empty?).to be false
      end

      it 'validates badly formed XML documents properly' do
        invalid = described_class.new('<invalid>fail')
        expect(invalid.xml_valid?).to be false
        expect(invalid.validate).to be false
        expect(invalid.errors).to include('Invalid XML Document: Premature end of data in tag invalid line 1')
      end

      it 'validates invalid roots correctly' do
        invalid_root = '<?xml version="1.0" encoding="UTF-8"?> <invalid>fail</invalid>'
        invalid = described_class.new(invalid_root)
        expect(invalid.valid_root?).to be false
        expect(invalid.validate).to be false
        expect(invalid.errors).to include('Provided XML Document has an invalid root: invalid')
      end

      it 'validates the XSD correctly' do
        invalid_root = '<?xml version="1.0" encoding="UTF-8"?> <invalid>fail</invalid>'
        invalid = described_class.new(invalid_root)
        expect(invalid.xsd_valid?).to be false
        expect(invalid.validate).to be false
        expect(invalid.errors).to include("XSD Validation failed: Element 'invalid': "\
                                          'No matching global declaration available for the validation root.')
      end

      it 'validates entity status correctly' do
        expect(@invalid_user.valid_entity_status?).to be false
        expect(@invalid_user.errors).to include('Invalid Entity Status MIA')
      end

      it 'validates that there is only one eservice declared' do
        expect(@invalid_user.single_eservice_result?).to be false
        expect(@invalid_user.errors).to include('More than 1 eService Results were found')
      end

      it 'validates the number Auth_Result_Set declared versus the actual number Auth_Result_Set rows' do
        expect(@invalid_user.errors).to include('1 <Auth_Result_Set> rows was declared, but 2 found')
      end
    end
  end
end
