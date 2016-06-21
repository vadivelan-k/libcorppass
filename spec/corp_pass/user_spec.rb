RSpec.describe CorpPass::User do
  subject { create(:corp_pass_user) }

  it 'should compare equality properly' do
    user = create(:corp_pass_user)
    expect(user).to eq(subject)
  end

  it 'should serialize and deserialize properly' do
    user = create(:corp_pass_user)
    serialized = user.serialize

    deserialized = CorpPass::User.deserialize serialized

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
  it { expect(subject.given_eservices_count).to be 1 }

  it 'should return the correct set of eservice_result' do
    foobar_service = subject.eservices[0]
    expect(foobar_service.auths.length).to eq 2
    expect(foobar_service.auths[0].start_date).to eq Date.new(2016, 1, 15)
    expect(foobar_service.auths[0].end_date).to eq Date.new(2016, 2, 15)
    expect(foobar_service.auths[0].entity_id_sub).to eq nil
    expect(foobar_service.auths[0].role).to eq 'Acceptor'
    expect(foobar_service.auths[0].parameters.length).to eq 2
    expect(foobar_service.auths[0].parameters[0].name).to eq 'foo'
    expect(foobar_service.auths[0].parameters[0].value).to eq 'bar'
    expect(foobar_service.auths[0].parameters[1].name).to eq 'lorem'
    expect(foobar_service.auths[0].parameters[1].value).to eq 'ipsum'

    expect(foobar_service.auths.length).to eq 2
    expect(foobar_service.auths[1].start_date).to eq Date.new(2015, 1, 15)
    expect(foobar_service.auths[1].end_date).to eq Date.new(2017, 2, 15)
    expect(foobar_service.auths[1].entity_id_sub).to eq 'foobar'
    expect(foobar_service.auths[1].role).to eq 'Viewer'
    expect(foobar_service.auths[1].parameters.length).to eq 0
  end

  it 'should return eservices as a Hash' do
    hash = subject.eservices_to_h
    foobar_service = hash['Foobar']
    expect(foobar_service.auths.length).to eq 2
  end

  it 'should return auth results for an eservice' do
    auths = subject.auth_results_for('Foobar')
    expect(auths.length).to eq 2
    expect(auths[0].role).to eq 'Acceptor'
    expect(auths[1].role).to eq 'Viewer'
  end

  describe 'Validation' do
    context 'Valid document' do
      it { expect(subject.valid?).to be true }
      it { expect { subject.validate! }.to_not raise_error }
      it { expect(subject.valid_root?).to be true }
    end

    context 'Invalid document' do
      before(:all) do
        @invalid_user = create(:corp_pass_user, :invalid)
        @invalid_user.valid?
      end

      it { expect(@invalid_user.valid?).to be false }
      it { expect { @invalid_user.validate! }.to raise_error CorpPass::InvalidUser }
      it { expect(@invalid_user.errors.empty?).to be false }

      it 'validates badly formed XML documents properly' do
        invalid = described_class.new('<invalid>fail')
        expect(invalid.xml_valid?).to be false
        expect(invalid.valid?).to be false
        expect(invalid.errors).to include('Invalid XML Document: Premature end of data in tag invalid line 1')
      end

      it 'validates invalid roots correctly' do
        invalid_root = '<?xml version="1.0" encoding="UTF-8"?> <invalid>fail</invalid>'
        invalid = described_class.new(invalid_root)
        expect(invalid.valid_root?).to be false
        expect(invalid.errors).to include('Provided XML Document has an invalid root: invalid')
        expect(invalid.valid?).to be false
      end

      it 'validates the XSD correctly' do
        invalid_root = '<?xml version="1.0" encoding="UTF-8"?> <invalid>fail</invalid>'
        invalid = described_class.new(invalid_root)
        expect(invalid.xsd_valid?).to be false
        expect(invalid.valid?).to be false
        expect(invalid.errors).to include("XSD Validation failed: Element 'invalid': "\
                                          'No matching global declaration available for the validation root.')
      end

      it 'validates entity status correctly' do
        expect(@invalid_user.valid_entity_status?).to be false
        expect(@invalid_user.errors).to include('Invalid Entity Status MIA')
      end

      it 'validates the number Auth_Result_Set declared versus the actual number Auth_Result_Set rows' do
        expect(@invalid_user.errors).to include('1 <Auth_Result_Set> rows was declared, but 2 found')
      end
    end
  end
end
