import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import FoodRecognitionCore

final class RememberedBackendConnectionTests: XCTestCase {
    private let address = "https://meal-review.example.workers.dev"
    private let code = String(repeating: "t", count: 48)

    private func session(expiresIn seconds: TimeInterval = 1800) -> BackendSession {
        BackendSession(token: String(repeating: "a", count: 40), expiresAt: Date().addingTimeInterval(seconds))
    }

    private func reply(_ session: BackendSession) throws -> BackendHTTPResponse {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return BackendHTTPResponse(data: try encoder.encode(session), statusCode: 200)
    }

    @MainActor
    func testOneTimeLoginIsSavedAndRestoredWithoutAnotherRequest() async throws {
        let storage = MemoryConnectionStore()
        let transport = LoginTransport([.success(try reply(session()))])
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: address, transport: transport)
        _ = try await connection.connect(serverAddress: address, testerCode: code)
        XCTAssertTrue(connection.hasSavedLogin)
        XCTAssertEqual(storage.record?.testerCode, code)
        let restored = RememberedBackendConnection(storage: storage, defaultServerAddress: "https://another.example", transport: transport)
        _ = try await restored.authorizedSession()
        XCTAssertEqual(restored.serverAddress, address)
        XCTAssertTrue(restored.canAuthorize)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(storage.saveCount, 1)
    }

    @MainActor
    func testExpiredSavedLoginRenewsOnlyAuthorizationAtItsSavedAddress() async throws {
        let storage = MemoryConnectionStore(StoredBackendConnection(address: address, session: session(expiresIn: -1), testerCode: code))
        let transport = LoginTransport([.success(try reply(session()))])
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: "https://another.example", transport: transport)
        XCTAssertTrue(connection.canAuthorize)
        _ = try await connection.estimator()
        _ = try await connection.authorizedSession()
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.host, URL(string: address)?.host)
        XCTAssertEqual(requests[0].url?.path, "/v1/session")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[0].httpBody)) as? [String: String])
        XCTAssertEqual(body, ["accessCode": code])
        XCTAssertNil(requests[0].value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(storage.record?.testerCode, code)
    }

    @MainActor
    func testSessionCloseToExpiryRenewsBeforeUse() async throws {
        let storage = MemoryConnectionStore(StoredBackendConnection(address: address, session: session(expiresIn: 30), testerCode: code))
        let transport = LoginTransport([.success(try reply(session()))])
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: address, transport: transport)
        let refreshed = try await connection.authorizedSession()
        XCTAssertGreaterThan(refreshed.expiresAt.timeIntervalSinceNow, 1700)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }

    @MainActor
    func testExpiredLegacyRecordKeepsAddressAndRequiresPasswordOnlyOnce() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let oldRecord: [String: Any] = ["address": address, "session": try JSONSerialization.jsonObject(with: encoder.encode(session(expiresIn: -1)))]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let record = try decoder.decode(StoredBackendConnection.self, from: JSONSerialization.data(withJSONObject: oldRecord))
        let storage = MemoryConnectionStore(record)
        let transport = LoginTransport([.success(try reply(session()))])
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: "https://another.example", transport: transport)
        XCTAssertEqual(connection.serverAddress, address)
        XCTAssertFalse(connection.hasSavedLogin)
        do { _ = try await connection.authorizedSession(); XCTFail("Legacy record has no saved password") }
        catch { XCTAssertEqual(error as? EstimationError, .authenticationRequired) }
        let before = await transport.requests
        XCTAssertTrue(before.isEmpty)
        _ = try await connection.connect(serverAddress: connection.serverAddress, testerCode: code)
        XCTAssertTrue(connection.hasSavedLogin)
    }

    @MainActor
    func testConcurrentRenewalSharesOneLoginAndOneStorageWrite() async throws {
        let storage = MemoryConnectionStore(StoredBackendConnection(address: address, session: session(expiresIn: -1), testerCode: code))
        let transport = LoginTransport([.success(try reply(session()))], held: true)
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: address, transport: transport)
        let first = Task { try await connection.authorizedSession() }
        await transport.waitUntilStarted()
        let second = Task { try await connection.authorizedSession() }
        await Task.yield()
        await transport.release()
        let a = try await first.value, b = try await second.value
        XCTAssertEqual(a, b)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(storage.saveCount, 1)
    }

    @MainActor
    func testOfflineRenewalKeepsPasswordWithoutAutomaticRetry() async throws {
        let original = StoredBackendConnection(address: address, session: session(expiresIn: -1), testerCode: code)
        let storage = MemoryConnectionStore(original)
        let transport = LoginTransport([.failure(URLError(.notConnectedToInternet)), .success(try reply(session()))])
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: address, transport: transport)
        do { _ = try await connection.authorizedSession(); XCTFail("Should report offline") }
        catch { XCTAssertEqual(error as? EstimationError, .networkUnavailable) }
        XCTAssertEqual(storage.record, original)
        let failed = await transport.requests
        XCTAssertEqual(failed.count, 1)
        _ = try await connection.authorizedSession() // A separate user/foreground action, not a retry loop.
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(connection.hasSavedLogin)
    }

    @MainActor
    func testRevokedPasswordIsClearedWhileAddressIsKept() async throws {
        let storage = MemoryConnectionStore(StoredBackendConnection(address: address, session: session(expiresIn: -1), testerCode: code))
        let transport = LoginTransport([.success(BackendHTTPResponse(data: Data(), statusCode: 401))])
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: address, transport: transport)
        for _ in 0..<2 {
            do { _ = try await connection.authorizedSession(); XCTFail("Should require updated credentials") }
            catch { XCTAssertEqual(error as? EstimationError, .authenticationRequired) }
        }
        XCTAssertFalse(connection.hasSavedLogin)
        XCTAssertFalse(connection.canAuthorize)
        XCTAssertEqual(connection.serverAddress, address)
        XCTAssertNil(storage.record?.testerCode)
        XCTAssertNil(storage.record?.session)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }

    @MainActor
    func testForgetLoginPreventsLateRenewalFromRestoringCredentials() async throws {
        let storage = MemoryConnectionStore(StoredBackendConnection(address: address, session: session(expiresIn: -1), testerCode: code))
        let transport = LoginTransport([.success(try reply(session()))], held: true)
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: address, transport: transport)
        let pending = Task { try await connection.authorizedSession() }
        await transport.waitUntilStarted()
        try connection.forgetLogin()
        await transport.release() // Intentionally complete a transport that ignores cancellation.
        do { _ = try await pending.value; XCTFail("Late login must be cancelled") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertNil(storage.record)
        XCTAssertFalse(connection.canAuthorize)
        XCTAssertEqual(storage.saveCount, 0)
    }

    @MainActor
    func testBackgroundCancellationPreservesLoginButDoesNotSaveLateToken() async throws {
        let original = StoredBackendConnection(address: address, session: session(expiresIn: -1), testerCode: code)
        let storage = MemoryConnectionStore(original)
        let transport = LoginTransport([.success(try reply(session()))], held: true)
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: address, transport: transport)
        let pending = Task { try await connection.authorizedSession() }
        await transport.waitUntilStarted()
        connection.cancelPendingAuthorization()
        await transport.release()
        do { _ = try await pending.value; XCTFail("Background login must cancel") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(storage.record, original)
        XCTAssertEqual(storage.saveCount, 0)
    }

    @MainActor
    func testChangingServerRequiresExplicitNewCodeAndNeverForwardsOldCode() async throws {
        let storage = MemoryConnectionStore(StoredBackendConnection(address: address, session: session(expiresIn: -1), testerCode: code))
        let transport = LoginTransport([.success(try reply(session()))])
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: address, transport: transport)
        let newAddress = "https://new-meal-review.example.workers.dev"
        let newCode = String(repeating: "n", count: 48)
        _ = try await connection.connect(serverAddress: newAddress, testerCode: newCode)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.host, URL(string: newAddress)?.host)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[0].httpBody)) as? [String: String])
        XCTAssertEqual(body["accessCode"], newCode)
        XCTAssertNotEqual(body["accessCode"], code)
        XCTAssertEqual(storage.record?.address, newAddress)
        XCTAssertEqual(storage.record?.testerCode, newCode)
    }

    @MainActor
    func testProviderKeyInStoredRecordIsNeverUsedForAutomaticLogin() async throws {
        let storage = MemoryConnectionStore(StoredBackendConnection(address: address, session: session(expiresIn: -1), testerCode: "sk-" + code))
        let transport = LoginTransport([])
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: address, transport: transport)
        XCTAssertFalse(connection.hasSavedLogin)
        do { _ = try await connection.authorizedSession(); XCTFail("Must not send provider key") }
        catch { XCTAssertEqual(error as? EstimationError, .authenticationRequired) }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }

    @MainActor
    func testStorageFailureDoesNotPretendLoginWasRemembered() async throws {
        let storage = MemoryConnectionStore()
        storage.failSaving = true
        let transport = LoginTransport([.success(try reply(session()))])
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: address, transport: transport)
        do { _ = try await connection.connect(serverAddress: address, testerCode: code); XCTFail("Storage failure must be visible") }
        catch { XCTAssertEqual(error as? EstimationError, .invalidConfiguration) }
        XCTAssertFalse(connection.hasSavedLogin)
        XCTAssertFalse(connection.canAuthorize)
        XCTAssertNil(storage.record)
    }

    @MainActor
    func testInvalidatedTokenRenewsWithoutForgettingPassword() async throws {
        let storage = MemoryConnectionStore(StoredBackendConnection(address: address, session: session(), testerCode: code))
        let transport = LoginTransport([.success(try reply(session()))])
        let connection = RememberedBackendConnection(storage: storage, defaultServerAddress: address, transport: transport)
        try connection.invalidateSession()
        XCTAssertTrue(connection.hasSavedLogin)
        XCTAssertNil(storage.record?.session)
        _ = try await connection.authorizedSession()
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.path, "/v1/session")
    }
}

@MainActor
private final class MemoryConnectionStore: BackendConnectionStoring {
    var record: StoredBackendConnection?
    var saveCount = 0
    var failSaving = false
    init(_ record: StoredBackendConnection? = nil) { self.record = record }
    func load() throws -> StoredBackendConnection? { record }
    func save(_ connection: StoredBackendConnection) throws {
        if failSaving { throw EstimationError.invalidConfiguration }
        record = connection
        saveCount += 1
    }
    func remove() throws { record = nil }
}

private actor LoginTransport: BackendHTTPTransport {
    private(set) var requests: [URLRequest] = []
    private var replies: [Result<BackendHTTPResponse, Error>]
    private var held: Bool
    private var gate: CheckedContinuation<Void, Never>?
    private var started: [CheckedContinuation<Void, Never>] = []
    init(_ replies: [Result<BackendHTTPResponse, Error>], held: Bool = false) {
        self.replies = replies
        self.held = held
    }
    func send(_ request: URLRequest) async throws -> BackendHTTPResponse {
        requests.append(request)
        started.forEach { $0.resume() }
        started.removeAll()
        guard !replies.isEmpty else { throw EstimationError.serviceUnavailable }
        let reply = replies.removeFirst()
        if held { await withCheckedContinuation { gate = $0 } }
        return try reply.get()
    }
    func waitUntilStarted() async {
        if !requests.isEmpty { return }
        await withCheckedContinuation { started.append($0) }
    }
    func release() {
        held = false
        gate?.resume()
        gate = nil
    }
}
