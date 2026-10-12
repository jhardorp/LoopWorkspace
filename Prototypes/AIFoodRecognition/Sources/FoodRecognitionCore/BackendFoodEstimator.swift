import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct BackendHTTPResponse: Sendable {
    public let data: Data
    public let statusCode: Int
    public let contentType: String?

    public init(data: Data, statusCode: Int, contentType: String? = "application/json") {
        self.data = data
        self.statusCode = statusCode
        self.contentType = contentType
    }
}

public protocol BackendHTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> BackendHTTPResponse
}

/// App authorization only. This is never an OpenAI/provider API key.
public struct BackendSession: Codable, Equatable, Sendable {
    public let token: String
    public let expiresAt: Date

    public init(token: String, expiresAt: Date) {
        self.token = token
        self.expiresAt = expiresAt
    }
}

/// A single-owner prototype backend. Receives only a current JPEG, with no therapy/history inputs.
public struct FoodBackendClient: Sendable {
    public static let maximumPhotoBytes = 1024 * 1024
    public static let maximumResponseBytes = 256 * 1024
    public let baseURL: URL
    private let transport: any BackendHTTPTransport

    public init(serverAddress: String, transport: any BackendHTTPTransport = BoundedURLSessionTransport()) throws {
        guard let url = URL(string: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.port == nil || url.port == 443, url.path.isEmpty || url.path == "/" else {
            throw EstimationError.invalidConfiguration
        }
        baseURL = url
        self.transport = transport
    }

    public func connect(testerCode: String) async throws -> BackendSession {
        try Self.validateTesterCode(testerCode)
        var request = makeRequest(path: "v1/session")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(LoginRequest(accessCode: testerCode))
        let response = try await send(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let session = try? decoder.decode(BackendSession.self, from: response.data),
              (32...2048).contains(session.token.utf8.count),
              session.token.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.").contains($0) }),
              session.expiresAt.timeIntervalSinceNow > 0,
              session.expiresAt.timeIntervalSinceNow <= 1860 else {
            throw EstimationError.invalidResponse
        }
        return session
    }

    public static func validateTesterCode(_ testerCode: String) throws {
        // Prevent accidentally sending a provider API key to an app-login endpoint.
        guard (32...256).contains(testerCode.utf8.count), !testerCode.hasPrefix("sk-"),
              !testerCode.contains(where: { $0.isWhitespace }) else {
            throw EstimationError.invalidConfiguration
        }
    }

    public func estimate(photo: MealPhoto, session: BackendSession) async throws -> EstimationOutcome {
        guard photo.kind == .jpeg, photo.data.count <= Self.maximumPhotoBytes,
              photo.data.starts(with: [0xff, 0xd8]), photo.data.suffix(2) == Data([0xff, 0xd9]) else {
            throw EstimationError.invalidPhoto
        }
        guard session.expiresAt > Date(), !session.token.isEmpty,
              session.token.utf8.count <= 2048, !session.token.contains(where: { $0.isWhitespace }) else {
            throw EstimationError.authenticationRequired
        }
        var request = makeRequest(path: "v1/estimate")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = photo.data
        let response = try await send(request)
        guard let envelope = try? JSONDecoder().decode(EstimateEnvelope.self, from: response.data),
              envelope.schemaVersion == 1 else { throw EstimationError.invalidResponse }
        switch envelope.status {
        case "estimate":
            guard let estimate = envelope.estimate, envelope.reason.isEmpty,
                  estimate.confidence == .low else { throw EstimationError.invalidResponse }
            return .estimate(try estimate.validated())
        case "needsMoreInformation":
            guard envelope.estimate == nil, !envelope.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  envelope.reason.utf8.count <= 2048 else { throw EstimationError.invalidResponse }
            return .needsMoreInformation(envelope.reason)
        default: throw EstimationError.invalidResponse
        }
    }

    private func makeRequest(path: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send(_ request: URLRequest) async throws -> BackendHTTPResponse {
        do {
            try Task.checkCancellation()
            let response = try await transport.send(request)
            try Task.checkCancellation()
            switch response.statusCode {
            case 200: break
            case 401, 403: throw EstimationError.authenticationRequired
            case 429: throw EstimationError.rateLimited
            case 408, 504: throw EstimationError.timedOut
            case 413, 415: throw EstimationError.invalidPhoto
            case 500...599: throw EstimationError.serviceUnavailable
            default: throw EstimationError.invalidResponse
            }
            guard response.data.count <= Self.maximumResponseBytes,
                  response.contentType?.lowercased().split(separator: ";").first?.trimmingCharacters(in: .whitespaces) == "application/json" else {
                throw EstimationError.invalidResponse
            }
            return response
        } catch is CancellationError { throw CancellationError() }
        catch let error as EstimationError { throw error }
        catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw EstimationError.timedOut
            default: throw EstimationError.networkUnavailable
            }
        } catch { throw EstimationError.invalidResponse }
    }

    private struct LoginRequest: Encodable { let accessCode: String }
    private struct EstimateEnvelope: Decodable {
        let schemaVersion: Int
        let status: String
        let estimate: MealEstimate?
        let reason: String
    }
}

public struct BackendFoodEstimator: FoodEstimating {
    public let client: FoodBackendClient
    public let session: BackendSession

    public init(client: FoodBackendClient, session: BackendSession) {
        self.client = client
        self.session = session
    }

    public func estimate(photo: MealPhoto) async throws -> EstimationOutcome {
        try await client.estimate(photo: photo, session: session)
    }
}
