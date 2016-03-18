module CorpPass
  module Test
    module Config
      def self.reset_configuration!
        CorpPass.load_yaml!('spec/fixtures/corp_pass/corp_pass.yml', 'default')
        CorpPass.configuration.failure_app = CorpPass::Test::RackHelper::FAILURE_APP
        CorpPass.configuration.failure_action = nil
      end
    end
  end
end
