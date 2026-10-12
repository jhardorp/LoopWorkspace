import Foundation

/// Owns only the current, in-memory review. Does not retain the photo.
@MainActor
public final class MealEstimateSession {
    public enum State: Equatable {
        case idle, estimating
        case reviewing(MealEstimate)
        case needsMoreInformation(String)
        case failed(EstimationError)
    }

    public private(set) var state: State = .idle
    public private(set) var draft: ReviewDraft?
    public private(set) var reviewFinished = false
    private var requestID = UUID()

    public init() {}

    public func analyze(photo: MealPhoto, using estimator: any FoodEstimating) async {
        guard !Task.isCancelled else { return }
        let currentID = UUID()
        requestID = currentID
        draft = nil
        reviewFinished = false
        state = .estimating
        do {
            let outcome = try await estimator.estimate(photo: photo)
            try Task.checkCancellation()
            guard requestID == currentID else { return }
            switch outcome {
            case .estimate(let estimate):
                let validated = try estimate.validated()
                draft = ReviewDraft(estimate: validated)
                state = .reviewing(validated)
            case .needsMoreInformation(let reason):
                state = .needsMoreInformation(reason)
            }
        } catch is CancellationError {
            guard requestID == currentID else { return }
            reset()
        } catch {
            guard requestID == currentID else { return }
            if Task.isCancelled { reset() }
            else { state = .failed(error as? EstimationError ?? .invalidResponse) }
        }
    }

    public func edit(_ updatedDraft: ReviewDraft) {
        guard case .reviewing = state else { return }
        draft = updatedDraft
        reviewFinished = false
    }

    @discardableResult
    public func finishReview(locale: Locale = .current, accept: (@MainActor (ReviewedMeal) -> Bool)? = nil) -> Bool {
        guard case .reviewing(let estimate) = state,
              !reviewFinished,
              let draft, draft.canFinish(estimate: estimate, locale: locale),
              let meal = ReviewedMeal(draft: draft, locale: locale) else { return false }
        // Keep the draft editable if its recipient rejects it. Completion means delivery succeeded.
        if let accept, !accept(meal) { return false }
        reviewFinished = true
        return true
    }

    public func reset() {
        requestID = UUID() // Invalidate even a provider that ignores cancellation.
        state = .idle
        draft = nil
        reviewFinished = false
    }
}
