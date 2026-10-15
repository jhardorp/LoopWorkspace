import Foundation

/// The tester password belongs in device-only Keychain storage, never in app source.
/// Optional fields also decode the 0.2.0 record, which contained only address/session.
public struct StoredBackendConnection: Codable, Equatable, Sendable {
    public let address: String
    public let session: BackendSession?
    public let testerCode: String?

    public init(address: String, session: BackendSession?, testerCode: String? = nil) {
        self.address = address
        self.session = session
        self.testerCode = testerCode
    }
}

@MainActor
public protocol BackendConnectionStoring {
    func load() throws -> StoredBackendConnection?
    func save(_ connection: StoredBackendConnection) throws
    func remove() throws
}

/// Renews app authorization only. It never uploads or retries a meal photograph.
@MainActor
public final class RememberedBackendConnection {
    private struct Authorization {
        let id: UUID
        let generation: UUID
        let client: FoodBackendClient
        let code: String
        let isRenewal: Bool
        let task: Task<BackendSession, Error>
    }

    private let storage: any BackendConnectionStoring
    private let transport: any BackendHTTPTransport
    private let defaultAddress: String
    private let now: () -> Date
    private var saved: StoredBackendConnection?
    private var client: FoodBackendClient?
    private var generation = UUID()
    private var pending: Authorization?

    public init(storage: any BackendConnectionStoring,
                defaultServerAddress: String,
                transport: any BackendHTTPTransport = BoundedURLSessionTransport(),
                now: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.transport = transport
        self.defaultAddress = defaultServerAddress
        self.now = now
        if let record = try? storage.load(),
           let restoredClient = try? FoodBackendClient(serverAddress: record.address, transport: transport) {
            let validCode = record.testerCode.flatMap { code in
                (try? FoodBackendClient.validateTesterCode(code)) != nil ? code : nil
            }
            saved = StoredBackendConnection(address: restoredClient.baseURL.absoluteString,
                                            session: record.session, testerCode: validCode)
            client = restoredClient
        }
    }

    public var serverAddress: String { saved?.address ?? defaultAddress }
    public var serverHost: String { URL(string: serverAddress)?.host ?? "your AI service" }
    public var hasSavedLogin: Bool { saved?.testerCode != nil }
    public var sessionExpiry: Date? { saved?.session?.expiresAt }
    public var canAuthorize: Bool {
        client != nil && (hasSavedLogin || (sessionExpiry ?? .distantPast) > now())
    }

    public func connect(serverAddress: String, testerCode: String) async throws -> BackendSession {
        let destination = try FoodBackendClient(serverAddress: serverAddress, transport: transport)
        try FoodBackendClient.validateTesterCode(testerCode)
        cancelPendingAuthorization()
        return try await begin(client: destination, code: testerCode, isRenewal: false)
    }

    public func authorizedSession() async throws -> BackendSession {
        try Task.checkCancellation()
        if let pending { return try await finish(pending) }
        // Refresh before expiry so time spent on capture/consent does not require typing again.
        if let session = saved?.session, session.expiresAt.timeIntervalSince(now()) > 60 {
            return session
        }
        guard let client, let code = saved?.testerCode else {
            // A legacy 0.2.0 session may still be usable, but cannot renew without one-time setup.
            if let session = saved?.session, session.expiresAt > now() { return session }
            throw EstimationError.authenticationRequired
        }
        return try await begin(client: client, code: code, isRenewal: true)
    }

    public func estimator() async throws -> BackendFoodEstimator {
        let session = try await authorizedSession()
        try Task.checkCancellation()
        guard let client, saved?.session == session else { throw CancellationError() }
        return BackendFoodEstimator(client: client, session: session)
    }

    public func cancelPendingAuthorization() {
        generation = UUID()
        pending?.task.cancel()
        pending = nil
    }

    public func forgetLogin() throws {
        cancelPendingAuthorization()
        saved = nil
        client = nil
        try storage.remove()
    }

    public func invalidateSession() throws {
        guard let saved else { return }
        let updated = StoredBackendConnection(address: saved.address, session: nil, testerCode: saved.testerCode)
        self.saved = updated
        try storage.save(updated)
    }

    private func begin(client: FoodBackendClient, code: String, isRenewal: Bool) async throws -> BackendSession {
        let authorization = Authorization(id: UUID(), generation: generation, client: client,
                                          code: code, isRenewal: isRenewal,
                                          task: Task { try await client.connect(testerCode: code) })
        pending = authorization
        return try await finish(authorization)
    }

    private func finish(_ authorization: Authorization) async throws -> BackendSession {
        do {
            let session = try await withTaskCancellationHandler {
                try await authorization.task.value
            } onCancel: {
                authorization.task.cancel()
            }
            try Task.checkCancellation()
            guard generation == authorization.generation else { throw CancellationError() }
            if pending?.id == authorization.id {
                let record = StoredBackendConnection(address: authorization.client.baseURL.absoluteString,
                                                     session: session, testerCode: authorization.code)
                try storage.save(record)
                saved = record
                client = authorization.client
                pending = nil
            } else {
                // Another waiter may have completed this same shared login already.
                guard saved?.session == session,
                      saved?.address == authorization.client.baseURL.absoluteString else {
                    throw CancellationError()
                }
            }
            return session
        } catch {
            if generation == authorization.generation, pending?.id == authorization.id {
                pending = nil
                if authorization.isRenewal, error as? EstimationError == .authenticationRequired {
                    // A revoked password needs new setup; do not retry it on every foreground event.
                    let record = StoredBackendConnection(address: authorization.client.baseURL.absoluteString, session: nil)
                    saved = record
                    try? storage.save(record)
                }
            }
            throw error
        }
    }
}
