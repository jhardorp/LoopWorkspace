#if canImport(UIKit)
import FoodRecognitionCore
import SwiftUI
import UIKit
import Security

enum RecognitionMode: String, CaseIterable {
    case openAI, demo
}

@MainActor
final class PrototypeViewModel: ObservableObject {
    @Published private(set) var state: MealEstimateSession.State = .idle
    @Published private(set) var draft: ReviewDraft?
    @Published private(set) var reviewFinished = false
    @Published private(set) var photo: UIImage?
    @Published var scenario: MockScenario = .balancedMeal
    @Published var mode: RecognitionMode = .openAI {
        didSet { if oldValue != mode { clear() } }
    }
    // Public connection configuration only; all provider credentials stay on the server.
    private static let defaultServerAddress = "https://loop-plus-meal-review.jan-1af.workers.dev"
    @Published var serverAddress = PrototypeViewModel.defaultServerAddress
    @Published var testerCode = ""
    @Published private(set) var connecting = false
    @Published private(set) var connectionError: String?
    @Published private(set) var sessionExpiry: Date?
    @Published private(set) var hasSavedLogin = false

    private let session = MealEstimateSession()
    private var task: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var connectionID = UUID()
    private let connection: RememberedBackendConnection

    init() {
        connection = RememberedBackendConnection(storage: ConnectionKeychain(),
                                                  defaultServerAddress: Self.defaultServerAddress)
        serverAddress = connection.serverAddress
        syncConnection()
    }

    var canUseAI: Bool { connection.canAuthorize }
    var serverHost: String { connection.serverHost }
    var hasPreconfiguredLogin: Bool { preconfiguredTesterCode != nil }

    private var preconfiguredTesterCode: String? {
        guard let code = Bundle.main.object(forInfoDictionaryKey: "LoopMealReviewTesterAccessCode") as? String,
              (try? FoodBackendClient.validateTesterCode(code)) != nil else { return nil }
        return code
    }

    var reviewedMeal: ReviewedMeal? {
        draft.flatMap { ReviewedMeal(draft: $0) }
    }

    func connect() {
        clear()
        let address = serverAddress, code = testerCode
        testerCode = ""
        runConnection { [connection] in
            try await connection.connect(serverAddress: address, testerCode: code)
        }
    }

    func resume() {
        syncConnection()
        guard !connecting, state != .estimating else { return }
        if !hasSavedLogin, let code = preconfiguredTesterCode {
            runConnection { [connection] in
                try await connection.connect(serverAddress: Self.defaultServerAddress, testerCode: code)
            }
            return
        }
        guard hasSavedLogin else { return }
        runConnection { [connection] in try await connection.authorizedSession() }
    }

    private func runConnection(_ operation: @escaping @MainActor () async throws -> BackendSession) {
        connectionTask?.cancel()
        let id = UUID()
        connectionID = id
        connecting = true
        connectionError = nil
        connectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await operation()
                try Task.checkCancellation()
                guard connectionID == id else { return }
                serverAddress = connection.serverAddress
            } catch {
                guard connectionID == id else { return }
                if !(error is CancellationError) {
                    connectionError = (error as? EstimationError).map(errorMessage) ?? "The login could not be stored securely. Try connecting again."
                }
            }
            guard connectionID == id else { return }
            syncConnection()
            connecting = false
            connectionTask = nil
        }
    }

    func disconnect() {
        pause()
        connectionError = nil
        do { try connection.forgetLogin() }
        catch { connectionError = "The saved login could not be removed. Try again while your iPhone is unlocked." }
        serverAddress = connection.serverAddress
        syncConnection()
    }

    func pause() {
        clear()
        connectionID = UUID()
        connectionTask?.cancel()
        connection.cancelPendingAuthorization()
        connectionTask = nil
        connecting = false
        testerCode = ""
    }

    func analyze(_ image: UIImage? = nil, consentToUpload: Bool = false) {
        clear()
        let estimator: (any FoodEstimating)?
        if mode == .openAI {
            guard consentToUpload else { state = .failed(.uploadConsentRequired); return }
            guard canUseAI else { state = .failed(.authenticationRequired); return }
            estimator = nil
        } else {
            estimator = MockFoodEstimator(scenario: scenario)
        }
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
            guard let data = normalized.jpegData(compressionQuality: 0.7),
                  data.count <= (mode == .openAI ? FoodBackendClient.maximumPhotoBytes : PrototypeLimits.maximumPhotoBytes),
                  let mealPhoto = try? MealPhoto(jpegData: data) else {
                state = .failed(.invalidPhoto)
                return
            }
            input = mealPhoto
            photo = normalized
        } else {
            guard mode == .demo else { state = .failed(.invalidPhoto); return }
            input = .demo
        }
        state = .estimating
        task = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            do {
                let provider: any FoodEstimating
                if let estimator { provider = estimator }
                else { provider = try await connection.estimator() }
                try Task.checkCancellation()
                syncConnection()
                await session.analyze(photo: input, using: provider)
                guard !Task.isCancelled else { return }
                sync()
                if case .failed(.authenticationRequired) = state {
                    try? connection.invalidateSession()
                    syncConnection()
                }
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                syncConnection()
                state = .failed((error as? EstimationError) ?? .invalidConfiguration)
            }
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

    private func syncConnection() {
        hasSavedLogin = connection.hasSavedLogin
        sessionExpiry = connection.sessionExpiry
    }

    func errorMessage(_ error: EstimationError) -> String {
        switch error {
        case .networkUnavailable: return mode == .demo ? "Simulated network failure. No estimate was produced." : "The service could not be reached. Check your connection and try again."
        case .timedOut: return "The request timed out. No estimate was produced."
        case .invalidPhoto: return "The photo could not be prepared. Try taking another meal photo."
        case .invalidResponse: return "The response failed validation and was discarded."
        case .authenticationRequired: return "The login was not accepted. Retry the connection; if the tester password was changed or revoked, enter the current password once."
        case .rateLimited: return "The request limit was reached. Wait before trying another photo; no fallback estimate was used."
        case .serviceUnavailable: return "The AI service is unavailable or still needs server setup. No estimate was produced."
        case .invalidConfiguration: return "Enter your tester password once (32 or more characters). The service address is prefilled; your OpenAI API key belongs on the server."
        case .uploadConsentRequired: return "Confirm the photo upload before requesting an AI estimate."
        }
    }
}

private struct ConnectionKeychain: BackendConnectionStoring {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "LoopPlus.MealReview.Session",
         kSecAttrAccount as String: "single-owner-prototype",
         kSecAttrSynchronizable as String: false]
    }

    func load() throws -> StoredBackendConnection? {
        var request = Self.query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw EstimationError.invalidConfiguration }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(StoredBackendConnection.self, from: data)
    }

    func save(_ connection: StoredBackendConnection) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let values: [String: Any] = [
            kSecValueData as String: try encoder.encode(connection),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(Self.query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            let item = Self.query.merging(values) { _, value in value }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw EstimationError.invalidConfiguration }
        } else if status != errSecSuccess { throw EstimationError.invalidConfiguration }
    }

    func remove() throws {
        let status = SecItemDelete(Self.query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw EstimationError.invalidConfiguration }
    }
}
#endif
