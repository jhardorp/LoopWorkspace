require 'xcodeproj'
require 'fileutils'
require 'digest'
require 'rexml/document'

abort('Full test-app preparation requires migration CI') unless
  ENV['CI'] == 'true' && ENV['GITHUB_REF'] == 'refs/heads/migration/loop4-ai-photo'
root = File.expand_path('../../../../..', __dir__)
loop_dir = File.join(root, 'Loop')
pin = IO.popen(['git', '-C', loop_dir, 'rev-parse', 'HEAD'], &:read).strip
abort('Unexpected Loop source') unless pin == 'b55744981c2e589799754d19f73b8912c8809e12'
main = File.join(loop_dir, 'Loop/main.swift')
view = File.join(loop_dir, 'Loop/Views/CarbEntryView.swift')
abort('The normal application entry point is required') unless
  File.read(main).include?('NSStringFromClass(AppDelegate.self)')
abort('The normal bolus destination and reviewed photo adapter are required') unless
  File.read(view).scan('BolusEntryView(viewModel: viewModel)').length == 1 &&
  File.read(view).include?('viewModel.applyPhotoReview')
# Packaging must not substitute startup, a memory ledger, therapy or device code.
swift_before = Dir[File.join(loop_dir, '**/*.swift')].to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }

project_path = File.join(loop_dir, 'Loop.xcodeproj')
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |item| item.name == 'Loop' }
abort('Loop app target missing') unless target
companions = %w[WatchApp] + ['Loop Widget Extension', 'Loop Intent Extension']
target.dependencies.to_a.each do |dependency|
  dependency.remove_from_project if companions.include?(dependency.target&.name)
end
target.copy_files_build_phases.to_a.each do |phase|
  phase.remove_from_project if ['Embed Watch Content', 'Embed Foundation Extensions'].include?(phase.name)
end
abort('Normal plugin installation phases missing') unless
  ['Install Plugins', 'Install Scenarios'].all? { |name| target.shell_script_build_phases.any? { |phase| phase.name == name } }
target.resources_build_phase.files.to_a.each do |file|
  file.remove_from_project if file.file_ref&.path&.end_with?('.icon')
end

identity = 'com.jhardorp.loopaiphototest'
group = 'group.' + identity
# The upstream project appends .Loop at project scope. Override BOTH scopes so
# neither inherited identity nor a production app group can survive expansion.
(project.build_configurations + target.build_configurations).each do |config|
  config.build_settings.merge!({
    'MAIN_APP_BUNDLE_IDENTIFIER' => identity,
    'APP_GROUP_IDENTIFIER' => group,
    'MAIN_APP_DISPLAY_NAME' => 'Loop Next AI',
    'URL_SCHEME_NAME' => 'loop-next-ai'
  })
end
target.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => identity,
    'CODE_SIGN_STYLE' => 'Manual',
    'APPICON_NAME' => 'SandboxIcon',
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'SandboxIcon',
    'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES' => '',
    'ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS' => 'NO',
    'TARGETED_DEVICE_FAMILY' => '1',
    'CURRENT_PROJECT_VERSION' => ENV.fetch('GITHUB_RUN_NUMBER'),
    'LOOP_ENTITLEMENTS' => 'Loop/Loop.entitlements',
    'CODE_SIGN_ENTITLEMENTS' => 'Loop/Loop.entitlements'
  })
end
project.root_object.attributes.fetch('TargetAttributes').fetch(target.uuid)['ProvisioningStyle'] = 'Manual'
assets = File.join(loop_dir, 'Loop/MealPhotoFullTestAssets.xcassets')
FileUtils.mkdir_p(assets)
reference = project.main_group.new_file('Loop/MealPhotoFullTestAssets.xcassets')
reference.last_known_file_type = 'folder.assetcatalog'
target.resources_build_phase.add_file_reference(reference)
project.save

plist_path = File.join(loop_dir, 'Loop/Info.plist')
info = Xcodeproj::Plist.read_from_path(plist_path)
abort('Normal scene and Health purpose strings required') unless
  %w[UIApplicationSceneManifest NSHealthShareUsageDescription NSHealthUpdateUsageDescription NSSiriUsageDescription].all? { |key| info.key?(key) }
abort('Sandbox metadata must not be present') if info.keys.any? { |key| key.start_with?('MealPhotoSandbox') }
info['CFBundleDisplayName'] = 'Loop Next AI'
info['AppGroupIdentifier'] = group
info['CFBundleURLTypes'] = [{'CFBundleURLName' => identity, 'CFBundleURLSchemes' => ['loop-next-ai']}]
info['NSCameraUsageDescription'] = 'Photograph meals for AI carbohydrate review or scan diabetes device barcodes.'
info['MealPhotoFullAppExperimental'] = true
info['MealPhotoFullAppSource'] = ENV.fetch('GITHUB_SHA')
info['MealPhotoFullAppCompanions'] = false
Xcodeproj::Plist.write_to_path(info, plist_path)

# Retain the workspace's normal plugin targets and order; omit only companion
# app entries from this candidate scheme. The upstream scheme stays untouched.
scheme_dir = File.join(root, 'LoopWorkspace.xcworkspace/xcshareddata/xcschemes')
document = REXML::Document.new(File.read(File.join(scheme_dir, 'LoopWorkspace.xcscheme')))
entries = document.root.elements['BuildAction/BuildActionEntries']
entries.get_elements('BuildActionEntry').each do |entry|
  entries.delete_element(entry) if companions.include?(entry.elements['BuildableReference']&.attributes&.[]('BlueprintName'))
end
File.write(File.join(scheme_dir, 'LoopNextAI.xcscheme'), document.to_s)

abort('Packaging changed application Swift source') unless swift_before.all? { |path, hash| Digest::SHA256.file(path).hexdigest == hash }
puts 'Prepared normal Loop Next AI main app: own identity/group, normal startup/plugins/bolus flow, no companion installs; Swift application sources unchanged.'
