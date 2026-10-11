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
    @Published var serverAddress = ""
    @Published var testerCode = ""
    @Published private(set) var connecting = false
    @Published private(set) var connectionError: String?
    @Published private(set) var sessionExpiry: Date?

    private let session = MealEstimateSession()
    private var task: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var connectionID = UUID()
    private var client: FoodBackendClient?
    private var backendSession: BackendSession?

    init() {
        if let saved = ConnectionKeychain.load(), saved.session.expiresAt > Date(),
           let client = try? FoodBackendClient(serverAddress: saved.address) {
            serverAddress = saved.address
            self.client = client
            backendSession = saved.session
            sessionExpiry = saved.session.expiresAt
        }
    }

    var canUseAI: Bool { client != nil && (backendSession?.expiresAt ?? .distantPast) > Date() }
    var serverHost: String { client?.baseURL.host ?? "your configured backend" }

    func connect() {
        connectionTask?.cancel()
        clear()
        let id = UUID()
        connectionID = id
        let address = serverAddress, code = testerCode
        testerCode = ""
        connecting = true
        connectionError = nil
        connectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let client = try FoodBackendClient(serverAddress: address)
                let authorized = try await client.connect(testerCode: code)
                try Task.checkCancellation()
                guard connectionID == id else { return }
                try ConnectionKeychain.save(StoredConnection(address: client.baseURL.absoluteString, session: authorized))
                self.client = client
                backendSession = authorized
                sessionExpiry = authorized.expiresAt
                serverAddress = client.baseURL.absoluteString
            } catch {
                guard connectionID == id else { return }
                if !(error is CancellationError) {
                    connectionError = (error as? EstimationError).map(errorMessage) ?? "The login could not be stored securely. Try connecting again."
                }
            }
            guard connectionID == id else { return }
            connecting = false
            connectionTask = nil
        }
    }

    func disconnect() {
        pause()
        client = nil
        backendSession = nil
        sessionExpiry = nil
        connectionError = nil
        ConnectionKeychain.remove()
    }

    func pause() {
        clear()
        connectionID = UUID()
        connectionTask?.cancel()
        connectionTask = nil
        connecting = false
        testerCode = ""
    }

    func analyze(_ image: UIImage? = nil, consentToUpload: Bool = false) {
        clear()
        let estimator: any FoodEstimating
        if mode == .openAI {
            guard consentToUpload else { state = .failed(.uploadConsentRequired); return }
            guard canUseAI, let client, let backendSession else { state = .failed(.authenticationRequired); return }
            estimator = BackendFoodEstimator(client: client, session: backendSession)
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

    func errorMessage(_ error: EstimationError) -> String {
        switch error {
        case .networkUnavailable: return mode == .demo ? "Simulated network failure. No estimate was produced." : "The service could not be reached. Check your connection and try again."
        case .timedOut: return "The request timed out. No estimate was produced."
        case .invalidPhoto: return "The photo could not be prepared. Try taking another meal photo."
        case .invalidResponse: return "The response failed validation and was discarded."
        case .authenticationRequired: return "The app login is missing, expired, or was revoked. Connect to the AI service again."
        case .rateLimited: return "The request limit was reached. Wait before trying another photo; no fallback estimate was used."
        case .serviceUnavailable: return "The AI service is unavailable or still needs server setup. No estimate was produced."
        case .invalidConfiguration: return "Enter the HTTPS server address and its separate tester access code (32 or more characters). Keep the OpenAI API key on the server."
        case .uploadConsentRequired: return "Confirm the photo upload before requesting an AI estimate."
        }
    }
}

private struct StoredConnection: Codable {
    let address: String
    let session: BackendSession
}

private enum ConnectionKeychain {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "LoopPlus.MealReview.Session",
         kSecAttrAccount as String: "single-owner-prototype"]
    }

    static func load() -> StoredConnection? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(StoredConnection.self, from: data)
    }

    static func save(_ connection: StoredConnection) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        var item = query
        item[kSecValueData as String] = try encoder.encode(connection)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        remove()
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw EstimationError.invalidConfiguration }
    }

    static func remove() { SecItemDelete(query as CFDictionary) }
}
