import FoodRecognitionCore
import SwiftUI
import UIKit

@MainActor
final class PrototypeViewModel: ObservableObject {
    @Published private(set) var state: MealEstimateSession.State = .idle
    @Published private(set) var draft: ReviewDraft?
    @Published private(set) var reviewFinished = false
    @Published private(set) var photo: UIImage?
    @Published var scenario: MockScenario = .balancedMeal

    private let session = MealEstimateSession()
    private var task: Task<Void, Never>?

    func analyze(_ image: UIImage? = nil) {
        clear()
        let input: MealPhoto
        if let image {
            // Redraw to normalize orientation, bound size, and omit source EXIF/location metadata.
            let scale = min(1, 1280 / max(image.size.width, image.size.height))
            let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let data = normalized.jpegData(compressionQuality: 0.75),
                  let mealPhoto = try? MealPhoto(jpegData: data) else {
                state = .failed(.invalidPhoto)
                return
            }
            input = mealPhoto
            photo = normalized
        } else {
            input = .demo
        }
        let estimator = MockFoodEstimator(scenario: scenario)
        state = .estimating
        task = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            await session.analyze(photo: input, using: estimator)
            guard !Task.isCancelled else { return }
            sync()
            task = nil
        }
    }

    func binding<Value>(for keyPath: WritableKeyPath<ReviewDraft, Value>, default fallback: Value) -> Binding<Value> {
        Binding(get: { self.draft?[keyPath: keyPath] ?? fallback }, set: { value in
            guard var draft = self.draft else { return }
            draft[keyPath: keyPath] = value
            self.session.edit(draft)
            self.sync()
        })
    }

    func finishReview() {
        session.finishReview()
        sync()
    }

    func clear() {
        task?.cancel()
        task = nil
        session.reset()
        photo = nil
        sync()
    }

    private func sync() {
        state = session.state
        draft = session.draft
        reviewFinished = session.reviewFinished
    }
}
