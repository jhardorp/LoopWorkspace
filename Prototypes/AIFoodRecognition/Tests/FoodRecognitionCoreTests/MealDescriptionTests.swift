import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import FoodRecognitionCore

@MainActor
final class MealDescriptionTests: XCTestCase {
    private let description = try! MealDescription("one tablespoon of honey")

    private func fixture(_ scenario: MockScenario = .uncertainPortion) async throws -> MealEstimate {
        guard case .estimate(let estimate) = try await MockFoodEstimator(scenario: scenario, delayNanoseconds: 0).estimate(photo: .demo) else {
            throw EstimationError.invalidResponse
        }
        return estimate
    }

    func testDescriptionTrimsAndBoundsUTF8WithoutRequiringAPhoto() throws {
        XCTAssertEqual(try MealDescription(" \n one tablespoon of honey \n").text, description.text)
        for invalid in ["", " \n", String(repeating: "é", count: 1025)] {
            XCTAssertThrowsError(try MealDescription(invalid)) { XCTAssertEqual($0 as? EstimationError, .invalidDescription) }
        }
        XCTAssertNoThrow(try MealDescription(String(repeating: "é", count: 1024)))
    }

    func testDescriptionUsesTheSameEditableReviewAndExplicitOnceOnlyHandoff() async throws {
        let estimate = try await fixture(), provider = DescriptionProvider(initial: .estimate(try await fixture()))
        let session = MealEstimateSession(), handoff = MealReviewHandoff()
        let request = handoff.begin()
        await session.analyze(description: description, using: provider)
        XCTAssertEqual(session.state, .reviewing(estimate))
        var deliveries = 0
        let accept: @MainActor (ReviewedMeal) -> Bool = { meal in
            handoff.accept(meal, request: request, maximumCarbohydrateGrams: 250, absorptionSeconds: 1800...28800) { reviewed in
                deliveries += 1
                XCTAssertEqual(reviewed.carbohydrateGrams, 17.5)
                XCTAssertEqual(reviewed.absorptionMinutes, 60)
                XCTAssertEqual(reviewed.foodDescription, "My honey")
            }
        }
        XCTAssertFalse(session.finishReview(accept: accept))
        var draft = try XCTUnwrap(session.draft)
        draft.carbohydrateText = "17.5"
        draft.absorptionMinutesText = "60"
        draft.mealNotes = "My honey"
        draft.acknowledgesUncertainty = true
        session.edit(draft)
        XCTAssertTrue(session.finishReview(locale: Locale(identifier: "en_US"), accept: accept))
        XCTAssertFalse(session.finishReview(accept: accept))
        XCTAssertEqual(deliveries, 1)
        let inputs = await provider.descriptions
        XCTAssertEqual(inputs, [description.text])
    }

    func testDescriptionRefinementCarriesSourceAndOrderedCorrectionsAndResetsReview() async throws {
        let original = try await fixture(), revised = try await fixture(.highFatMeal)
        let provider = DescriptionProvider(initial: .estimate(original), revised: .estimate(revised))
        let session = MealEstimateSession()
        await session.analyze(description: description, using: provider)
        var draft = try XCTUnwrap(session.draft); draft.acknowledgesUncertainty = true; session.edit(draft)
        await session.refine(description: description, comment: "two tablespoons", using: provider)
        XCTAssertEqual(session.state, .reviewing(revised))
        XCTAssertFalse(try XCTUnwrap(session.draft).acknowledgesUncertainty)
        let contexts = await provider.contexts
        XCTAssertEqual(contexts.first?.previousEstimate, original)
        XCTAssertEqual(contexts.first?.comments, ["two tablespoons"])
        let inputs = await provider.descriptions
        XCTAssertEqual(inputs, [description.text, description.text])
    }

    func testFailedTextRefinementKeepsManualValuesAndQuestionHasNoFallback() async throws {
        let original = try await fixture(), session = MealEstimateSession()
        let provider = DescriptionProvider(initial: .estimate(original), revised: .needsMoreInformation("Level or heaped?"))
        await session.analyze(description: description, using: provider)
        var draft = try XCTUnwrap(session.draft); draft.carbohydrateText = "19"; session.edit(draft)
        await session.refine(description: description, comment: "larger spoon", using: provider)
        XCTAssertEqual(session.draft, draft)
        XCTAssertEqual(session.refinementQuestion, "Level or heaped?")
        XCTAssertFalse(session.finishReview())
        await session.refine(description: description, comment: " ", using: provider)
        XCTAssertEqual(session.refinementError, .invalidComment)
        XCTAssertEqual(session.draft, draft)
        session.reset()
        await session.analyze(description: description, using: DescriptionProvider(initial: .needsMoreInformation("How much?")))
        XCTAssertNil(session.draft)
        XCTAssertFalse(session.finishReview())
    }

    func testCancellationDiscardsLateTextResultAndCannotDeliver() async throws {
        let provider = SuspendedDescription(), session = MealEstimateSession()
        let task = Task { await session.analyze(description: description, using: provider) }
        while !(await provider.started) { await Task.yield() }
        task.cancel(); session.reset()
        await provider.complete(.estimate(try await fixture()))
        await task.value
        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.draft)
        XCTAssertFalse(session.finishReview())
    }

    func testNewPhotoSupersedesPendingDescriptionEvenIfProviderIgnoresCancellation() async throws {
        let provider = SuspendedDescription(), session = MealEstimateSession()
        let task = Task { await session.analyze(description: description, using: provider) }
        while !(await provider.started) { await Task.yield() }
        let photo = try await fixture(.highFatMeal)
        await session.analyze(photo: .demo, using: DescriptionProvider(initial: .estimate(photo)))
        await provider.complete(.estimate(try await fixture()))
        await task.value
        XCTAssertEqual(session.state, .reviewing(photo))
    }

    func testBackendDescriptionAndRefinementSendTextOnlyWithAuthentication() async throws {
        let estimate = try await fixture()
        let response = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "status": "estimate", "reason": "",
            "estimate": JSONSerialization.jsonObject(with: JSONEncoder().encode(estimate))])
        let transport = DescriptionTransport(response: response)
        let client = try FoodBackendClient(serverAddress: "https://meal.example.workers.dev", transport: transport)
        let login = BackendSession(token: String(repeating: "a", count: 40), expiresAt: Date().addingTimeInterval(1800))
        let estimator = BackendFoodEstimator(client: client, session: login)
        let initialOutcome = try await estimator.estimate(description: description)
        XCTAssertEqual(initialOutcome, .estimate(estimate))
        let context = try MealRefinement(previousEstimate: estimate, comments: ["Two tablespoons"])
        let revisedOutcome = try await estimator.refine(description: description, context: context)
        XCTAssertEqual(revisedOutcome, .estimate(estimate))
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 2)
        for request in requests {
            XCTAssertEqual(request.url?.path, "/v1/describe")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(login.token)")
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
            XCTAssertEqual(body["description"] as? String, description.text)
            XCTAssertNil(body["imageBase64"])
        }
        let initial = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[0].httpBody)) as? [String: Any])
        XCTAssertEqual(Set(initial.keys), ["description"])
        let revised = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[1].httpBody)) as? [String: Any])
        let sent = try JSONDecoder().decode(MealRefinement.self, from: JSONSerialization.data(withJSONObject: XCTUnwrap(revised["refinement"])))
        XCTAssertEqual(sent, context)
    }

    func testExpiredSessionAndCancellationNeverSendDescription() async throws {
        let transport = DescriptionTransport(response: Data())
        let client = try FoodBackendClient(serverAddress: "https://meal.example.workers.dev", transport: transport)
        let expired = BackendSession(token: "expired", expiresAt: .distantPast)
        do { _ = try await client.estimate(description: description, session: expired); XCTFail("Expected rejection") }
        catch { XCTAssertEqual(error as? EstimationError, .authenticationRequired) }
        let task = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            return try await client.estimate(description: description, session: BackendSession(token: "valid", expiresAt: .distantFuture))
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }
}

private actor DescriptionProvider: FoodEstimating {
    let initial: EstimationOutcome
    let revised: EstimationOutcome
    private(set) var descriptions: [String] = []
    private(set) var contexts: [MealRefinement] = []
    init(initial: EstimationOutcome, revised: EstimationOutcome? = nil) { self.initial = initial; self.revised = revised ?? initial }
    func estimate(photo: MealPhoto) async throws -> EstimationOutcome { initial }
    func estimate(description: MealDescription) async throws -> EstimationOutcome { descriptions.append(description.text); return initial }
    func refine(description: MealDescription, context: MealRefinement) async throws -> EstimationOutcome {
        descriptions.append(description.text); contexts.append(context); return revised
    }
}

private actor SuspendedDescription: FoodEstimating {
    private var pending: CheckedContinuation<EstimationOutcome, Never>?
    var started: Bool { pending != nil }
    func estimate(photo: MealPhoto) async throws -> EstimationOutcome { throw EstimationError.invalidPhoto }
    func estimate(description: MealDescription) async throws -> EstimationOutcome { await withCheckedContinuation { pending = $0 } }
    func complete(_ outcome: EstimationOutcome) { pending?.resume(returning: outcome); pending = nil }
}

private actor DescriptionTransport: BackendHTTPTransport {
    let response: Data
    private(set) var requests: [URLRequest] = []
    init(response: Data) { self.response = response }
    func send(_ request: URLRequest) async throws -> BackendHTTPResponse {
        requests.append(request); return BackendHTTPResponse(data: response, statusCode: 200)
    }
}
