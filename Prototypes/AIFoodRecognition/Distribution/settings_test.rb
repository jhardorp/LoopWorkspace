require 'minitest/autorun'
require_relative 'settings'

class PrototypeDistributionSettingsTest < Minitest::Test
  def valid_environment
    PrototypeDistribution::REQUIRED_SECRETS.to_h { |name| [name, 'test-only-placeholder'] }
      .merge('TEAMID' => 'ABCDEFGHIJ', 'GITHUB_REPOSITORY_OWNER' => 'jhardorp')
  end

  def test_valid_configuration_and_separate_bundle
    assert PrototypeDistribution.validate_environment(valid_environment)
    assert_equal 'com.jhardorp.foodrecognitionprototype', PrototypeDistribution::BUNDLE_ID
    refute_includes PrototypeDistribution::BUNDLE_ID, '.loopkit.Loop'
  end

  def test_missing_secret_reports_names_only
    error = assert_raises(ArgumentError) do
      PrototypeDistribution.validate_environment(valid_environment.merge('MATCH_PASSWORD' => ''))
    end
    assert_includes error.message, 'MATCH_PASSWORD'
    refute_includes error.message, 'test-only-placeholder'
  end

  def test_invalid_team_and_other_owner_fail_closed
    assert_raises(ArgumentError) { PrototypeDistribution.validate_environment(valid_environment.merge('TEAMID' => 'invalid')) }
    assert_raises(ArgumentError) { PrototypeDistribution.validate_environment(valid_environment.merge('GITHUB_REPOSITORY_OWNER' => 'other')) }
  end

  def test_only_explicit_operations_are_accepted
    PrototypeDistribution::OPERATIONS.each { |operation| assert_equal operation, PrototypeDistribution.validate_operation(operation) }
    ['', 'release', 'upload_testflight; other_command'].each do |operation|
      assert_raises(ArgumentError) { PrototypeDistribution.validate_operation(operation) }
    end
  end
end
