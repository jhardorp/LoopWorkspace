import Foundation

/// Context for this meal only; discarded with its in-memory review.
public struct MealRefinement: Codable, Equatable, Sendable {
    public static let maximumComments = 20
    public static let maximumCommentBytes = 2048
    public static let maximumTotalCommentBytes = 16_384
    public let previousEstimate: MealEstimate
    public let comments: [String]
    public let question: String

    public init(previousEstimate: MealEstimate, comments: [String], question: String = "") throws {
        self.previousEstimate = try previousEstimate.validated()
        let trimmed = comments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !trimmed.isEmpty, trimmed.count <= Self.maximumComments,
              trimmed.allSatisfy({ !$0.isEmpty && $0.utf8.count <= Self.maximumCommentBytes }),
              trimmed.reduce(0, { $0 + $1.utf8.count }) <= Self.maximumTotalCommentBytes,
              question.utf8.count <= 2048 else { throw EstimationError.invalidComment }
        self.comments = trimmed
        self.question = question
    }
}
