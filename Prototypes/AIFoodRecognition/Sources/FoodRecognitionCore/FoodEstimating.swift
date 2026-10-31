import Foundation

public struct MealPhoto: Sendable {
    public enum Kind: Sendable { case jpeg, demo }
    public let data: Data
    public let kind: Kind

    public init(jpegData: Data) throws {
        guard !jpegData.isEmpty, jpegData.count <= PrototypeLimits.maximumPhotoBytes else {
            throw EstimationError.invalidPhoto
        }
        self.data = jpegData
        self.kind = .jpeg
    }

    private init() {
        data = Data()
        kind = .demo
    }

    /// Simulator input for mock providers only; a real provider must reject this kind.
    public static let demo = MealPhoto()
}

/// Only a description of the current meal; no photo or treatment data is required.
public struct MealDescription: Equatable, Sendable {
    public static let maximumBytes = 2048
    public let text: String

    public init(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= Self.maximumBytes else {
            throw EstimationError.invalidDescription
        }
        self.text = trimmed
    }
}

public enum MealInput: Sendable {
    case photo(MealPhoto)
    case description(MealDescription)
}

public enum EstimationOutcome: Equatable, Sendable {
    case estimate(MealEstimate)
    case needsMoreInformation(String)
}

public enum EstimationError: Error, Equatable, Sendable {
    case networkUnavailable, timedOut, invalidResponse, invalidPhoto
    case authenticationRequired, rateLimited, serviceUnavailable, invalidConfiguration, uploadConsentRequired
    case invalidComment, invalidDescription
}

/// Receives only the current meal input and corrections to its current review.
public protocol FoodEstimating: Sendable {
    func estimate(photo: MealPhoto) async throws -> EstimationOutcome
    func refine(photo: MealPhoto, context: MealRefinement) async throws -> EstimationOutcome
    func estimate(description: MealDescription) async throws -> EstimationOutcome
    func refine(description: MealDescription, context: MealRefinement) async throws -> EstimationOutcome
}

public extension FoodEstimating {
    func refine(photo: MealPhoto, context: MealRefinement) async throws -> EstimationOutcome {
        throw EstimationError.serviceUnavailable
    }

    func estimate(description: MealDescription) async throws -> EstimationOutcome {
        throw EstimationError.serviceUnavailable
    }

    func refine(description: MealDescription, context: MealRefinement) async throws -> EstimationOutcome {
        throw EstimationError.serviceUnavailable
    }
}
