// Replaces main.swift only in the ephemeral unsigned Simulator test checkout,
// after the full, unmodified application has passed its separate build.
import UIKit
import FoodRecognitionCore

final class MealPhotoAdapterTestAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// Owns the fixture in the host, so the test bundle does not link a second copy
/// of the Swift package. The real session and native adapter remain under test.
@MainActor
final class MealPhotoTestReview {
    private let meal: ReviewedMeal
    private init(_ meal: ReviewedMeal) { self.meal = meal }
    private enum FixtureError: Error { case missingDraft, reviewRejected }

    static func make(fromDescription: Bool = false) async throws -> MealPhotoTestReview {
        let session = MealEstimateSession()
        if fromDescription {
            await session.analyze(description: try MealDescription("one tablespoon of honey"), using: MockFoodEstimator(scenario: .uncertainPortion, delayNanoseconds: 0))
        } else {
            await session.analyze(photo: .demo, using: MockFoodEstimator(delayNanoseconds: 0))
        }
        guard var draft = session.draft else { throw FixtureError.missingDraft }
        draft.carbohydrateText = "12,5"
        draft.absorptionMinutesText = "90,5"
        draft.mealNotes = "Two large slices; banana not ripe"
        draft.acknowledgesUncertainty = true
        session.edit(draft)
        var result: ReviewedMeal?
        guard session.finishReview(locale: Locale(identifier: "de_DE"), accept: { result = $0; return true }),
              let result else { throw FixtureError.reviewRejected }
        return MealPhotoTestReview(result)
    }

    func apply(to viewModel: CarbEntryViewModel, request: UUID) -> Bool {
        viewModel.applyPhotoReview(meal, request: request)
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv,
                  NSStringFromClass(UIApplication.self),
                  NSStringFromClass(MealPhotoAdapterTestAppDelegate.self))
