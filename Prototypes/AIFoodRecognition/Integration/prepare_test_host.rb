require 'xcodeproj'
require 'fileutils'
require 'json'

abort('Unsigned adapter test host is restricted to migration CI') unless
  ENV['CI'] == 'true' && ENV['GITHUB_REF'] == 'refs/heads/migration/loop4-ai-photo'
root = File.expand_path('../../..', __dir__)
loop_dir = File.join(root, 'Loop')
pin = IO.popen(['git', '-C', loop_dir, 'rev-parse', 'HEAD'], &:read).strip
expected_pin = JSON.parse(File.read(File.join(__dir__, 'upstream-lock.json'))).fetch('submodules').fetch('Loop')
abort('Unexpected Loop pin') unless pin == expected_pin
main = File.join(loop_dir, 'Loop/main.swift')
abort('Unexpected application entry point') unless File.read(main).include?('NSStringFromClass(AppDelegate.self)')
FileUtils.cp(File.join(__dir__, 'TestHostMain.swift'), main)
plist = File.join(loop_dir, 'Loop/Info.plist')
settings = Xcodeproj::Plist.read_from_path(plist)
abort('Expected upstream scene manifest') unless settings.delete('UIApplicationSceneManifest')
Xcodeproj::Plist.write_to_path(settings, plist)
project = Xcodeproj::Project.open(File.join(loop_dir, 'Loop.xcodeproj'))
tests = project.targets.find { |target| target.name == 'LoopTests' }
abort('Native test target was not found') unless tests
tests.build_configurations.each do |config|
  conditions = Array(config.build_settings.fetch('SWIFT_ACTIVE_COMPILATION_CONDITIONS', '$(inherited)'))
  conditions << 'MEAL_PHOTO_ADAPTER_TEST_HOST'
  config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = conditions.join(' ')
end
project.save
puts 'Prepared a minimal Simulator test host; LoopAppManager, Siri and device services are not started.'
