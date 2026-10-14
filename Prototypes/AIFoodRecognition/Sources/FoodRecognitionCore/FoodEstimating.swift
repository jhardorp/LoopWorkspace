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

public enum EstimationOutcome: Equatable, Sendable {
    case estimate(MealEstimate)
    case needsMoreInformation(String)
}

public enum EstimationError: Error, Equatable, Sendable {
    case networkUnavailable, timedOut, invalidResponse, invalidPhoto
    case authenticationRequired, rateLimited, serviceUnavailable, invalidConfiguration, uploadConsentRequired
    case invalidComment
}

/// Receives the current photo and optional corrections to its current review only.
public protocol FoodEstimating: Sendable {
    func estimate(photo: MealPhoto) async throws -> EstimationOutcome
    func refine(photo: MealPhoto, context: MealRefinement) async throws -> EstimationOutcome
}

public extension FoodEstimating {
    func refine(photo: MealPhoto, context: MealRefinement) async throws -> EstimationOutcome {
        throw EstimationError.serviceUnavailable
    }
}
