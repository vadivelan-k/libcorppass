module CorpPass
  module Test
    module Config
      def self.reset_configuration!
        CorpPass.load_yaml('spec/fixtures/corp_pass/corp_pass.yml', 'default')
      end
    end
  end
end
