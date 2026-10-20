require 'xcodeproj'
require 'fileutils'

abort('Unsigned adapter test host is restricted to migration CI') unless
  ENV['CI'] == 'true' && ENV['GITHUB_REF'] == 'refs/heads/migration/loop4-ai-photo'
root = File.expand_path('../../..', __dir__)
loop_dir = File.join(root, 'Loop')
pin = IO.popen(['git', '-C', loop_dir, 'rev-parse', 'HEAD'], &:read).strip
abort('Unexpected Loop pin') unless pin == 'b55744981c2e589799754d19f73b8912c8809e12'
main = File.join(loop_dir, 'Loop/main.swift')
abort('Unexpected application entry point') unless File.read(main).include?('NSStringFromClass(AppDelegate.self)')
FileUtils.cp(File.join(__dir__, 'TestHostMain.swift'), main)
plist = File.join(loop_dir, 'Loop/Info.plist')
settings = Xcodeproj::Plist.read_from_path(plist)
abort('Expected upstream scene manifest') unless settings.delete('UIApplicationSceneManifest')
Xcodeproj::Plist.write_to_path(settings, plist)
puts 'Prepared a minimal unsigned test host; LoopAppManager, Siri and device services are not started.'
