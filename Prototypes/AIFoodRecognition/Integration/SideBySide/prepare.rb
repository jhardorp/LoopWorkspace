require 'xcodeproj'
require 'fileutils'
require 'json'

abort('Separate test app preparation requires migration CI') unless
  ENV['CI'] == 'true' && ENV['GITHUB_REF'] == 'refs/heads/migration/loop4-ai-photo'
root = File.expand_path('../../../..', __dir__)
loop_dir = File.join(root, 'Loop')
pin = IO.popen(['git', '-C', loop_dir, 'rev-parse', 'HEAD'], &:read).strip
abort('Unexpected Loop source') unless pin == 'b55744981c2e589799754d19f73b8912c8809e12'
main = File.join(loop_dir, 'Loop/main.swift')
abort('Expected the normal application before sandbox preparation') unless File.read(main).include?('NSStringFromClass(AppDelegate.self)')
view = File.join(loop_dir, 'Loop/Views/CarbEntryView.swift')
contents = File.read(view)
abort('The reviewed photo adapter must be applied first') unless contents.include?('viewModel.applyPhotoReview')
abort('Unexpected native destination') unless contents.scan('BolusEntryView(viewModel: viewModel)').length == 1
File.write(view, contents.sub('BolusEntryView(viewModel: viewModel)', 'AIPhotoSandboxSummary(viewModel: viewModel)'))
FileUtils.cp(File.join(__dir__, 'SandboxMain.swift'), main)

project = Xcodeproj::Project.open(File.join(loop_dir, 'Loop.xcodeproj'))
target = project.targets.find { |item| item.name == 'Loop' }
abort('Loop app target missing') unless target
# Only framework dependencies survive. No watch, widgets, intent extension,
# device plugin copying, scenario loading or production startup is included.
target.dependencies.to_a.each do |dependency|
  dependency.remove_from_project unless dependency.target&.product_type == 'com.apple.product-type.framework'
end
target.copy_files_build_phases.to_a.each do |phase|
  phase.remove_from_project unless phase.name == 'Embed Frameworks'
end
target.shell_script_build_phases.to_a.each do |phase|
  phase.remove_from_project unless phase.name == 'Build Derived Assets'
end
target.resources_build_phase.files.to_a.each do |file|
  file.remove_from_project if file.file_ref&.path&.end_with?('.icon')
end
attributes = project.root_object.attributes.fetch('TargetAttributes', {}).fetch(target.uuid, {})
attributes['SystemCapabilities'] = {}
attributes['ProvisioningStyle'] = 'Manual'

objects = Xcodeproj::Project::Object
package = project.new(objects::XCLocalSwiftPackageReference)
package.relative_path = '../Prototypes/AIFoodRecognition/Integration/SideBySide/Support'
project.root_object.package_references << package
dependency = project.new(objects::XCSwiftPackageProductDependency)
dependency.package = package
dependency.product_name = 'MealPhotoSandboxSupport'
target.package_product_dependencies << dependency
link = project.new(objects::PBXBuildFile)
link.product_ref = dependency
target.frameworks_build_phase.files << link

identity = 'com.jhardorp.loopaiphototest'
target.build_configurations.each do |config|
  config.build_settings.merge!({
    'MAIN_APP_BUNDLE_IDENTIFIER' => identity,
    'PRODUCT_BUNDLE_IDENTIFIER' => identity,
    'MAIN_APP_DISPLAY_NAME' => 'Loop AI Test',
    'APP_GROUP_IDENTIFIER' => "group.#{identity}",
    'URL_SCHEME_NAME' => 'loop-ai-test',
    'LOOP_ENTITLEMENTS' => 'Loop/MealPhotoSandbox.entitlements',
    'CODE_SIGN_ENTITLEMENTS' => 'Loop/MealPhotoSandbox.entitlements',
    'CODE_SIGN_STYLE' => 'Manual',
    'APPICON_NAME' => 'SandboxIcon',
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'SandboxIcon',
    'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES' => '',
    'ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS' => 'NO',
    'ENABLE_APP_INTENTS_METADATA_EXTRACTION' => 'NO',
    'TARGETED_DEVICE_FAMILY' => '1',
    'LOOP_MARKETING_VERSION' => '0.1.0',
    'CURRENT_PROJECT_VERSION' => ENV.fetch('GITHUB_RUN_NUMBER', '1')
  })
end
Xcodeproj::Plist.write_to_path({}, File.join(loop_dir, 'Loop/MealPhotoSandbox.entitlements'))

plist = File.join(loop_dir, 'Loop/Info.plist')
settings = Xcodeproj::Plist.read_from_path(plist)
%w[UIApplicationSceneManifest UIMainStoryboardFile UIBackgroundModes
   BGTaskSchedulerPermittedIdentifiers LSApplicationQueriesSchemes
   NSHealthShareUsageDescription NSHealthUpdateUsageDescription
   NSBluetoothAlwaysUsageDescription NSBluetoothPeripheralUsageDescription
   NFCReaderUsageDescription NSAlarmKitUsageDescription NSFaceIDUsageDescription
   NSSiriUsageDescription NSUserActivityTypes NSSupportsLiveActivities
   NSSupportsLiveActivitiesFrequentUpdates UIRequiredDeviceCapabilities].each { |key| settings.delete(key) }
settings['CFBundleDisplayName'] = 'Loop AI Test'
settings['AppGroupIdentifier'] = "group.#{identity}"
settings['CFBundleURLTypes'] = [{'CFBundleURLName' => identity, 'CFBundleURLSchemes' => ['loop-ai-test']}]
settings['NSCameraUsageDescription'] = 'Photograph food to test AI meal estimates in this separate test app.'
# Apple scans linked Loop frameworks even though their Health/Siri/device paths
# are not started by the isolated app. Purpose text does not grant entitlements.
settings.merge!(JSON.parse(File.read(File.join(__dir__, 'PrivacyDescriptions.json'))))
settings['MealPhotoSandbox'] = true
settings['MealPhotoSandboxSchema'] = 1
settings['MealPhotoSandboxStorage'] = 'MemoryOnly'
settings['MealPhotoSandboxSource'] = ENV.fetch('GITHUB_SHA')
Xcodeproj::Plist.write_to_path(settings, plist)

assets = File.join(loop_dir, 'Loop/MealPhotoSandboxAssets.xcassets')
FileUtils.mkdir_p(assets)
reference = project.main_group.new_file('Loop/MealPhotoSandboxAssets.xcassets')
reference.last_known_file_type = 'folder.assetcatalog'
target.resources_build_phase.add_file_reference(reference)
project.save

tests = project.new_target(:ui_test_bundle, 'LoopAIPhotoSandboxUITests', :ios, '17.6')
tests.add_dependency(target)
project.root_object.attributes['TargetAttributes'] ||= {}
project.root_object.attributes['TargetAttributes'][tests.uuid] = {'TestTargetID' => target.uuid}
test_source = project.main_group.new_file('../Prototypes/AIFoodRecognition/Integration/SideBySide/SandboxUITests.swift')
tests.source_build_phase.add_file_reference(test_source)
tests.build_configurations.each do |config|
  config.build_settings.merge!({
    'SWIFT_VERSION' => '5.0', 'GENERATE_INFOPLIST_FILE' => 'YES',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'PRODUCT_MODULE_NAME' => 'LoopAIPhotoSandboxUITests',
    'PRODUCT_BUNDLE_IDENTIFIER' => identity + '.uitests',
    'TEST_TARGET_NAME' => 'Loop', 'CODE_SIGN_STYLE' => 'Manual',
    'TARGETED_DEVICE_FAMILY' => '1', 'SKIP_INSTALL' => 'YES'
  })
end
project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.add_test_target(tests)
scheme.save_as(File.join(loop_dir, 'Loop.xcodeproj'), 'LoopAIPhotoTest', true)
puts 'Prepared Loop AI Test: distinct identity, no shared entitlements, no extensions/plugins, memory-only test destination.'
