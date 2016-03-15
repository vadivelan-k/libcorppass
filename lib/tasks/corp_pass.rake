require 'corp_pass/metadata'

namespace :corp_pass do
  namespace :metadata do
    ARGUMENTS = [:entity_id, :acs, :slo, :encryption_key, :encryption_crt, :signing_key, :signing_crt, :out_file].freeze
    desc 'Generate metadata for CorpPass Service Provider'
    task :generate, ARGUMENTS => :environment do |_, args|
      missing = []
      ARGUMENTS.each do |arg|
        # args is of type Rake::TaskArguments -- it is not a hash and has no `key?` method
        missing.push "Missing argument #{arg}" unless args.has_key?(arg) # rubocop:disable Style/DeprecatedHashMethods
      end

      fail missing.join "\n" unless missing.empty?

      CorpPass::Metadata.generate args
    end
  end

  desc 'Test authentication connectivity to IdP'
  task test_connectivity: :environment do
    begin
      Saml.current_provider = Saml.provider(CorpPass.configuration.sp_entity)
      logger = CorpPass::Logger.new(::Logger.new(STDOUT))
      logger.subscribe_all
      puts CorpPass.provider.warden_strategy.new(nil).test_authentication!
    rescue NotImplementedError
      puts "The current provider #{CorpPass.provider.class} does not support this operation."
    end
  end
end
