# Pure configuration guards: no credentials are logged and no API calls happen here.
module PrototypeDistribution
  BUNDLE_ID = 'com.jhardorp.foodrecognitionprototype'.freeze
  REQUIRED_SECRETS = %w[TEAMID GH_PAT MATCH_PASSWORD FASTLANE_KEY_ID FASTLANE_ISSUER_ID FASTLANE_KEY].freeze
  OPERATIONS = %w[check_configuration prepare_signed_build upload_testflight].freeze

  def self.validate_operation(operation)
    raise ArgumentError, 'Unknown prototype distribution operation' unless OPERATIONS.include?(operation)
    operation
  end

  def self.validate_environment(environment)
    missing = REQUIRED_SECRETS.select { |name| environment.fetch(name, '').strip.empty? }
    raise ArgumentError, "Missing repository signing secrets: #{missing.join(', ')}" unless missing.empty?
    raise ArgumentError, 'TEAMID must be a ten-character Apple team identifier' unless environment.fetch('TEAMID').match?(/\A[A-Z0-9]{10}\z/)
    owner = environment.fetch('GITHUB_REPOSITORY_OWNER', '')
    raise ArgumentError, 'This distribution setup belongs to jhardorp/LoopWorkspace' unless owner == 'jhardorp'
    true
  end
end
