RSpec.describe CorpPass::Util do
  describe ':string_to_boolean' do
    it 'should return a boolean value unchanged' do
      expect(CorpPass::Util.string_to_boolean(true)).to be true
      expect(CorpPass::Util.string_to_boolean(false)).to be false
    end

    it 'should convert a "true" string to true in a case-insensitive manner' do
      expect(CorpPass::Util.string_to_boolean('TRUE')).to be true
      expect(CorpPass::Util.string_to_boolean('true')).to be true
      expect(CorpPass::Util.string_to_boolean('TRue')).to be true
    end

    it 'should convert a "false" string to false in a case-insensitive manner' do
      expect(CorpPass::Util.string_to_boolean('FALSE')).to be false
      expect(CorpPass::Util.string_to_boolean('false')).to be false
      expect(CorpPass::Util.string_to_boolean('FAlsE')).to be false
    end

    it 'allows you to set your own custom true and false strings' do
      expect(CorpPass::Util.string_to_boolean('YES', true_string: 'yes', false_string: 'no')).to be true
      expect(CorpPass::Util.string_to_boolean('no', true_string: 'yes', false_string: 'no')).to be false
    end

    it 'raises an error if a string cannot be converted' do
      expect { CorpPass::Util.string_to_boolean('foobar') }.to raise_error ArgumentError
      expect { CorpPass::Util.string_to_boolean('foobar', true_string: 'foo', false_string: 'bar') }
        .to raise_error ArgumentError
    end
  end
end
