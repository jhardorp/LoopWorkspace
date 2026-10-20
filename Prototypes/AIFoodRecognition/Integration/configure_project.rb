require 'xcodeproj'

root = File.expand_path('../../..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'Loop', 'Loop.xcodeproj'))
target = project.targets.find { |item| item.name == 'Loop' }
abort('The Loop app target was not found') unless target
objects = Xcodeproj::Project::Object
reference = project.root_object.package_references.find do |item|
  item.is_a?(objects::XCLocalSwiftPackageReference) && item.relative_path == '../Prototypes/AIFoodRecognition'
end
unless reference
  reference = project.new(objects::XCLocalSwiftPackageReference)
  reference.relative_path = '../Prototypes/AIFoodRecognition'
  project.root_object.package_references << reference
end
([target].product(['FoodRecognitionUI', 'FoodRecognitionCore']) +
 [[project.targets.find { |item| item.name == 'LoopTests' }, 'FoodRecognitionCore']]).each do |target, product|
abort('Missing package consumer target') unless target
dependency = target.package_product_dependencies.find { |item| item.product_name == product }
unless dependency
  dependency = project.new(objects::XCSwiftPackageProductDependency)
  dependency.package = reference
  dependency.product_name = product
  target.package_product_dependencies << dependency
  build_file = project.new(objects::PBXBuildFile)
  build_file.product_ref = dependency
  target.frameworks_build_phase.files << build_file
end
end
project.save
puts 'Linked the shared meal-review UI into the Loop app target.'
