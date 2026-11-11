import Foundation

/// Owns only the current, in-memory review. Does not retain its source input.
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
    public private(set) var isRefining = false
    public private(set) var refinementComments: [String] = []
    public private(set) var refinementError: EstimationError?
    public private(set) var refinementQuestion: String?
    private var requestID = UUID()

    public init() {}

    public func analyze(photo: MealPhoto, using estimator: any FoodEstimating) async {
        await analyze(input: .photo(photo), using: estimator)
    }

    public func analyze(description: MealDescription, using estimator: any FoodEstimating) async {
        await analyze(input: .description(description), using: estimator)
    }

    public func analyze(input: MealInput, using estimator: any FoodEstimating) async {
        guard !Task.isCancelled else { return }
        let currentID = UUID()
        requestID = currentID
        draft = nil
        reviewFinished = false
        isRefining = false
        refinementComments = []
        refinementError = nil
        refinementQuestion = nil
        state = .estimating
        do {
            let outcome: EstimationOutcome
            switch input {
            case .photo(let photo): outcome = try await estimator.estimate(photo: photo)
            case .description(let description): outcome = try await estimator.estimate(description: description)
            }
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

    /// A failed update keeps the prior estimate and manual edits intact.
    public func refine(photo: MealPhoto, comment: String, using estimator: any FoodEstimating) async {
        await refine(input: .photo(photo), comment: comment, using: estimator)
    }

    public func refine(description: MealDescription, comment: String, using estimator: any FoodEstimating) async {
        await refine(input: .description(description), comment: comment, using: estimator)
    }

    public func refine(input: MealInput, comment: String, using estimator: any FoodEstimating) async {
        guard !Task.isCancelled, !isRefining, !reviewFinished,
              case .reviewing(let estimate) = state else { return }
        let context: MealRefinement
        do {
            context = try MealRefinement(previousEstimate: estimate,
                                         comments: refinementComments + [comment],
                                         question: refinementQuestion ?? "")
        } catch {
            refinementError = error as? EstimationError ?? .invalidComment
            return
        }
        let currentID = UUID()
        requestID = currentID
        isRefining = true
        refinementError = nil
        do {
            let outcome: EstimationOutcome
            switch input {
            case .photo(let photo): outcome = try await estimator.refine(photo: photo, context: context)
            case .description(let description): outcome = try await estimator.refine(description: description, context: context)
            }
            try Task.checkCancellation()
            guard requestID == currentID else { return }
            switch outcome {
            case .estimate(let revised):
                let validated = try revised.validated()
                draft = ReviewDraft(estimate: validated)
                state = .reviewing(validated)
                refinementComments = context.comments
                refinementQuestion = nil
            case .needsMoreInformation(let reason):
                guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      reason.utf8.count <= 2048 else { throw EstimationError.invalidResponse }
                refinementComments = context.comments
                refinementQuestion = reason
            }
        } catch {
            guard requestID == currentID else { return }
            if !(error is CancellationError), !Task.isCancelled {
                refinementError = error as? EstimationError ?? .invalidResponse
            }
        }
        guard requestID == currentID else { return }
        isRefining = false
    }

    public func cancelRefinement() {
        guard isRefining else { return }
        requestID = UUID()
        isRefining = false
    }

    public func edit(_ updatedDraft: ReviewDraft) {
        guard case .reviewing = state, !isRefining else { return }
        draft = updatedDraft
        reviewFinished = false
    }

    @discardableResult
    public func finishReview(locale: Locale = .current, accept: (@MainActor (ReviewedMeal) -> Bool)? = nil) -> Bool {
        guard case .reviewing(let estimate) = state,
              !reviewFinished, !isRefining, refinementQuestion == nil,
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
        isRefining = false
        refinementComments = []
        refinementError = nil
        refinementQuestion = nil
    }
}
