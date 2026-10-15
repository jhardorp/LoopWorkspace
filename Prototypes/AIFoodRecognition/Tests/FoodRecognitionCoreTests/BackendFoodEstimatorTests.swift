import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import FoodRecognitionCore

final class BackendFoodEstimatorTests: XCTestCase {
    private let address = "https://meal-review.example.workers.dev"
    private let jpeg = Data([0xff, 0xd8, 0xff, 0xd9])
    private var session: BackendSession {
        BackendSession(token: String(repeating: "a", count: 40), expiresAt: Date().addingTimeInterval(1800))
    }

    private func estimateBody(version: Int = 1) async throws -> Data {
        let outcome = try await MockFoodEstimator(scenario: .uncertainPortion, delayNanoseconds: 0).estimate(photo: .demo)
        guard case .estimate(let estimate) = outcome else { throw EstimationError.invalidResponse }
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(estimate))
        return try JSONSerialization.data(withJSONObject: ["schemaVersion": version, "status": "estimate", "reason": "", "estimate": object])
    }

    func testOnlyExplicitRootHTTPSBackendAddressesAreAccepted() {
        for invalid in ["http://example.com", "example.com", "https://user:secret@example.com", "https://example.com?token=secret", "https://example.com/#secret", "https://example.com/another/path", "https://example.com:8080"] {
            XCTAssertThrowsError(try FoodBackendClient(serverAddress: invalid), invalid)
        }
        XCTAssertNoThrow(try FoodBackendClient(serverAddress: address + "/"))
    }

    func testConnectSendsOnlyTesterCodeAndAcceptsShortLivedAppSession() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let expected = session
        let transport = RecordingTransport(.success(BackendHTTPResponse(data: try encoder.encode(expected), statusCode: 200)))
        let client = try FoodBackendClient(serverAddress: address, transport: transport)
        let result = try await client.connect(testerCode: String(repeating: "z", count: 32))
        XCTAssertEqual(result.token, expected.token)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.path, "/v1/session")
        XCTAssertNil(requests[0].value(forHTTPHeaderField: "Authorization"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[0].httpBody)) as? [String: String])
        XCTAssertEqual(Set(object.keys), ["accessCode"])
    }

    func testProviderAPIKeyAndWeakTesterCodeAreRejectedWithoutNetwork() async throws {
        let transport = RecordingTransport(.failure(EstimationError.serviceUnavailable))
        let client = try FoodBackendClient(serverAddress: address, transport: transport)
        for code in ["short", "sk-" + String(repeating: "a", count: 50), String(repeating: "a", count: 31) + " "] {
            do { _ = try await client.connect(testerCode: code); XCTFail("Should reject login code") }
            catch { XCTAssertEqual(error as? EstimationError, .invalidConfiguration) }
        }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testRealEstimateSendsOnlyCurrentJPEGAndAuthorizationThenValidatesReview() async throws {
        let transport = RecordingTransport(.success(BackendHTTPResponse(data: try await estimateBody(), statusCode: 200)))
        let client = try FoodBackendClient(serverAddress: address, transport: transport)
        let outcome = try await BackendFoodEstimator(client: client, session: session).estimate(photo: MealPhoto(jpegData: jpeg))
        guard case .estimate(let estimate) = outcome else { return XCTFail("Expected editable estimate") }
        XCTAssertEqual(estimate.confidence, .low)
        XCTAssertEqual(try estimate.validated(), estimate)
        let requests = await transport.requests
        XCTAssertEqual(requests[0].httpBody, jpeg)
        XCTAssertEqual(requests[0].url?.path, "/v1/estimate")
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
        XCTAssertTrue(requests[0].value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true)
    }

    func testDemoMalformedAndOversizedPhotosNeverReachRealBackend() async throws {
        let transport = RecordingTransport(.failure(EstimationError.serviceUnavailable))
        let client = try FoodBackendClient(serverAddress: address, transport: transport)
        for photo in [MealPhoto.demo, try MealPhoto(jpegData: Data([1, 2, 3])), try MealPhoto(jpegData: Data(count: FoodBackendClient.maximumPhotoBytes + 1))] {
            do { _ = try await client.estimate(photo: photo, session: session); XCTFail("Should reject photo") }
            catch { XCTAssertEqual(error as? EstimationError, .invalidPhoto) }
        }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testRefinementSendsCurrentPhotoPriorEstimateAndOrderedComments() async throws {
        let data = try await estimateBody()
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let original = try JSONDecoder().decode(MealEstimate.self, from: JSONSerialization.data(withJSONObject: XCTUnwrap(envelope["estimate"])))
        let context = try MealRefinement(previousEstimate: original, comments: ["Bigger slice", "Two of those"], question: "Which item?")
        let transport = RecordingTransport(.success(BackendHTTPResponse(data: data, statusCode: 200)))
        let client = try FoodBackendClient(serverAddress: address, transport: transport)
        let outcome = try await client.refine(photo: MealPhoto(jpegData: jpeg), context: context, session: session)
        XCTAssertEqual(outcome, .estimate(original))
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.path, "/v1/refine")
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[0].httpBody)) as? [String: Any])
        XCTAssertEqual(Set(body.keys), ["imageBase64", "refinement"])
        XCTAssertEqual(body["imageBase64"] as? String, jpeg.base64EncodedString())
        let sent = try JSONDecoder().decode(MealRefinement.self, from: JSONSerialization.data(withJSONObject: XCTUnwrap(body["refinement"])))
        XCTAssertEqual(sent, context)
    }

    func testRefinementTransportFailureDoesNotRetry() async throws {
        let data = try await estimateBody()
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let original = try JSONDecoder().decode(MealEstimate.self, from: JSONSerialization.data(withJSONObject: XCTUnwrap(envelope["estimate"])))
        let context = try MealRefinement(previousEstimate: original, comments: ["Banana is not ripe"])
        for (status, expected) in [(429, EstimationError.rateLimited), (503, .serviceUnavailable), (422, .invalidComment)] {
            let transport = RecordingTransport(.success(BackendHTTPResponse(data: Data(), statusCode: status)))
            let client = try FoodBackendClient(serverAddress: address, transport: transport)
            do {
                _ = try await client.refine(photo: MealPhoto(jpegData: jpeg), context: context, session: session)
                XCTFail("Expected failure")
            } catch { XCTAssertEqual(error as? EstimationError, expected) }
            let requests = await transport.requests
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testExpiredSessionRequiresReconnectWithoutSendingPhoto() async throws {
        let transport = RecordingTransport(.failure(EstimationError.serviceUnavailable))
        let client = try FoodBackendClient(serverAddress: address, transport: transport)
        do {
            _ = try await client.estimate(photo: MealPhoto(jpegData: jpeg), session: BackendSession(token: "expired", expiresAt: Date().addingTimeInterval(-1)))
            XCTFail("Should require a new session")
        } catch { XCTAssertEqual(error as? EstimationError, .authenticationRequired) }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testClarificationHasNoNumericFallback() async throws {
        let body = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "status": "needsMoreInformation", "reason": "Please show the portion and ingredients.", "estimate": NSNull()])
        let client = try FoodBackendClient(serverAddress: address, transport: RecordingTransport(.success(BackendHTTPResponse(data: body, statusCode: 200))))
        let outcome = try await client.estimate(photo: MealPhoto(jpegData: jpeg), session: session)
        XCTAssertEqual(outcome, .needsMoreInformation("Please show the portion and ingredients."))
    }

    func testUnknownSchemaInconsistentTotalsAndMalformedRepliesAreDiscarded() async throws {
        let valid = try await estimateBody()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: valid) as? [String: Any])
        var estimate = try XCTUnwrap(object["estimate"] as? [String: Any])
        estimate["carbohydrateGrams"] = ["value": 1, "lower": 0, "upper": 2]
        object["estimate"] = estimate
        let inconsistent = try JSONSerialization.data(withJSONObject: object)
        for body in [try await estimateBody(version: 2), inconsistent, Data("not JSON".utf8)] {
            let client = try FoodBackendClient(serverAddress: address, transport: RecordingTransport(.success(BackendHTTPResponse(data: body, statusCode: 200))))
            do { _ = try await client.estimate(photo: MealPhoto(jpegData: jpeg), session: session); XCTFail("Should discard reply") }
            catch { XCTAssertEqual(error as? EstimationError, .invalidResponse) }
        }
    }

    func testHTTPFailuresAreMappedWithoutRetriesOrFallback() async throws {
        for (status, expected) in [(401, EstimationError.authenticationRequired), (403, .authenticationRequired), (429, .rateLimited), (504, .timedOut), (503, .serviceUnavailable), (413, .invalidPhoto), (302, .invalidResponse)] {
            let transport = RecordingTransport(.success(BackendHTTPResponse(data: Data(), statusCode: status)))
            let client = try FoodBackendClient(serverAddress: address, transport: transport)
            do { _ = try await client.estimate(photo: MealPhoto(jpegData: jpeg), session: session); XCTFail("Should report HTTP failure") }
            catch { XCTAssertEqual(error as? EstimationError, expected) }
            let requests = await transport.requests
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testResponseSizeAndContentTypeAreBounded() async throws {
        for response in [BackendHTTPResponse(data: Data(count: FoodBackendClient.maximumResponseBytes + 1), statusCode: 200), BackendHTTPResponse(data: try await estimateBody(), statusCode: 200, contentType: "text/html")] {
            let client = try FoodBackendClient(serverAddress: address, transport: RecordingTransport(.success(response)))
            do { _ = try await client.estimate(photo: MealPhoto(jpegData: jpeg), session: session); XCTFail("Should discard reply") }
            catch { XCTAssertEqual(error as? EstimationError, .invalidResponse) }
        }
    }

    func testOfflineAndTimeoutAreActualTransportFailures() async throws {
        for (code, expected) in [(URLError.notConnectedToInternet, EstimationError.networkUnavailable), (.timedOut, .timedOut)] {
            let client = try FoodBackendClient(serverAddress: address, transport: RecordingTransport(.failure(URLError(code))))
            do { _ = try await client.estimate(photo: MealPhoto(jpegData: jpeg), session: session); XCTFail("Should report transport failure") }
            catch { XCTAssertEqual(error as? EstimationError, expected) }
        }
    }

    func testCancelledRequestDoesNotStartANetworkCall() async throws {
        let transport = RecordingTransport(.failure(EstimationError.serviceUnavailable))
        let client = try FoodBackendClient(serverAddress: address, transport: transport)
        let photo = try MealPhoto(jpegData: jpeg)
        let task = Task {
            // Suspend until the test has cancelled this task.
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            return try await client.estimate(photo: photo, session: session)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Should cancel") }
        catch { XCTAssertTrue(error is CancellationError) }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }
}

private actor RecordingTransport: BackendHTTPTransport {
    private(set) var requests: [URLRequest] = []
    let result: Result<BackendHTTPResponse, Error>
    init(_ result: Result<BackendHTTPResponse, Error>) { self.result = result }
    func send(_ request: URLRequest) async throws -> BackendHTTPResponse {
        requests.append(request)
        return try result.get()
    }
}
