#if canImport(UIKit)
import AVFoundation
import FoodRecognitionCore
import SwiftUI
import UIKit

@MainActor
public struct FoodRecognitionView: View {
    @StateObject private var model = PrototypeViewModel()
    @Environment(\.dismiss) private var dismiss
    private let startsWithCamera: Bool
    private let onUseMeal: (@MainActor (ReviewedMeal) -> Bool)?
    @State private var startedCamera = false
    @State private var showCamera = false
    @State private var cameraError: String?
    @State private var requestingCamera = false
    @State private var transferError: String?
    @State private var manualCarbs = ""
    @State private var manualMinutes = "180"
    @State private var manualFood = ""
    @State private var mealTime = Date()

    public init(startsWithCamera: Bool = false, onUseMeal: (@MainActor (ReviewedMeal) -> Bool)? = nil) {
        self.startsWithCamera = startsWithCamera
        self.onUseMeal = onUseMeal
    }

    public var body: some View {
        NavigationView {
            Group {
                if case .reviewing(let estimate) = model.state {
                    review(estimate)
                        .id("mealReviewResult")
                } else {
                    entry
                        .id("mealReviewEntry")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(onUseMeal == nil ? "Discard" : "Cancel") {
                        discard()
                        if onUseMeal != nil { dismiss() }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .fullScreenCover(isPresented: $showCamera) {
            MealCameraView(onCapture: { image in
                showCamera = false
                guard UIApplication.shared.applicationState == .active else { return }
                // Capturing a meal authorizes its analysis; no separate upload screen is shown.
                model.analyze(image, consentToUpload: true)
            }, onCancel: { showCamera = false })
                .ignoresSafeArea()
        }
        .alert("Camera unavailable", isPresented: Binding(get: { cameraError != nil }, set: {
            if !$0 { cameraError = nil }
        })) {
            Button("OK", role: .cancel) { cameraError = nil }
        } message: {
            Text(cameraError ?? "")
        }
        // UIKit hosts do not reliably supply SwiftUI's scenePhase environment.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            discard()
            model.pause()
            showCamera = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            model.resume()
        }
        .onAppear { model.resume(); startCameraIfRequested() }
        .onChange(of: model.canUseAI) { _ in startCameraIfRequested() }
    }

    private var title: String {
        if case .reviewing = model.state { return model.mode == .demo ? "Review Meal · Demo" : "Review Meal · AI" }
        return onUseMeal == nil ? "Loop+ Meal Review" : "Meal photo review"
    }

    private var entry: some View {
        Form {
            if onUseMeal == nil { Section("Recognition") {
                Picker("Provider", selection: $model.mode) {
                    Text("OpenAI photo analysis").tag(RecognitionMode.openAI)
                    Text("Mock demo").tag(RecognitionMode.demo)
                }
                .disabled(model.state == .estimating || model.connecting)
            } }
            Section(onUseMeal == nil ? "Meal" : "Meal photo") {
                if onUseMeal == nil {
                    TextField("Amount consumed (g)", text: $manualCarbs).keyboardType(.decimalPad)
                    DatePicker("Time", selection: $mealTime)
                    TextField("Food type", text: $manualFood)
                    TextField("Absorption duration (minutes)", text: $manualMinutes).keyboardType(.decimalPad)
                }
                Button(action: openCamera) {
                    Label("Photograph meal", systemImage: "camera")
                }
                .accessibilityIdentifier("photographMeal")
                .disabled(model.state == .estimating || requestingCamera || (model.mode == .openAI && !model.canUseAI))
            }
            if model.mode == .demo { Section {
                Picker("Demo result", selection: $model.scenario) {
                    ForEach(MockScenario.allCases, id: \.self) { scenario in
                        Text(scenarioTitle(scenario)).tag(scenario)
                    }
                }
                .disabled(model.state == .estimating)
                Button("Use demo meal without camera") { model.analyze() }
                    .disabled(model.state == .estimating)
                    .accessibilityIdentifier("useDemoMeal")
                Text("Every photograph returns the selected fictional example. This prototype does not recognize food.")
                    .font(.footnote).foregroundColor(.secondary)
            } }
            status
            if model.mode == .openAI { connection }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch model.state {
        case .estimating:
            Section {
                ProgressView(model.mode == .demo ? "Preparing mock estimate…" : "Analyzing current meal photo…")
                Button("Cancel estimate", role: .cancel) { model.clear() }
            }
        case .failed(let error):
            Section("Estimate unavailable") {
                Text(model.errorMessage(error))
                Text("Retake the photo to retry. Your manual preview remains editable.")
                    .font(.footnote)
            }
        case .needsMoreInformation(let reason):
            Section("More information needed") { Text(reason) }
        case .idle, .reviewing:
            EmptyView()
        }
    }

    private func review(_ estimate: MealEstimate) -> some View {
        Form {
            Section(model.mode == .demo ? "Demo result" : "Meal result") {
                Text("Photo estimate: \(estimate.carbohydrateGrams.value, specifier: "%.1f") g · \(estimate.absorptionMinutes.value, specifier: "%.0f") min")
                    .font(.headline)
                    .accessibilityIdentifier("mealEstimateSummary")
                labeledField("Carbohydrates (g)", binding: model.binding(for: \.carbohydrateText, default: ""))
                    .accessibilityIdentifier("reviewCarbohydrates")
                labeledField("Absorption duration (minutes)", binding: model.binding(for: \.absorptionMinutesText, default: ""))
                    .accessibilityIdentifier("reviewAbsorption")
                TextField("Meal notes", text: model.binding(for: \.mealNotes, default: ""))
                if estimate.confidence == .low {
                    Toggle("Reviewed estimate", isOn: model.binding(for: \.acknowledgesUncertainty, default: false))
                }
                Button(onUseMeal == nil ? "Finish review" : "Use in Loop") {
                    transferError = nil
                    if !model.finishReview(using: onUseMeal), onUseMeal != nil {
                        transferError = "Loop could not accept these values. Your result is still here; review the amounts and try again."
                    }
                }
                .disabled(!(model.draft?.canFinish(estimate: estimate) ?? false) || model.reviewedMeal == nil || model.reviewFinished)
                .accessibilityIdentifier("finishReview")
                if model.reviewFinished, onUseMeal == nil {
                    Text("Review complete. These values remain here for you to enter in Loop.").foregroundColor(.green)
                }
                if let error = transferError {
                    Text(error).foregroundColor(.orange)
                } else if estimate.confidence == .low, model.draft?.acknowledgesUncertainty != true {
                    Text(onUseMeal == nil ? "Check the portion and values, then turn on Reviewed estimate to finish." : "Check the portion and values, then turn on Reviewed estimate to use them in Loop.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            Section("Estimated ranges") {
                Text("Carbohydrates: \(quantity(estimate.carbohydrateGrams, unit: "g"))")
                Text("Absorption duration: \(quantity(estimate.absorptionMinutes, unit: "min"))")
            }
            if let photo = model.photo { Section("Meal photo") {
                Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 180)
                    .accessibilityLabel("Current meal photograph")
            } }
            Section(model.mode == .demo ? "Example foods and portions" : "Foods and estimated portions") {
                ForEach(Array(estimate.foods.enumerated()), id: \.offset) { _, food in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(food.name).font(.headline)
                        Text(food.portionDescription)
                        Text("Portion: \(quantity(food.portionGrams, unit: "g"))")
                        Text("Carbohydrates: \(quantity(food.carbohydrateGrams, unit: "g"))")
                        Text("Fat \(food.fatGrams, specifier: "%.0f") g · Protein \(food.proteinGrams, specifier: "%.0f") g · Fiber \(food.fiberGrams, specifier: "%.0f") g")
                        Text(food.carbohydrateType)
                        Text(food.glycemicCharacteristics).font(.footnote).foregroundColor(.secondary)
                    }
                }
            }
            Section("Explanation") {
                if model.mode == .openAI {
                    Text("Nutrition is inferred from the photo, not checked against a nutrition database. Total carbohydrate includes fiber; check ingredients, portions and nutrition labels.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Text(estimate.confidence == .low ? "Low confidence — confirm ingredients and portion size." : "Moderate confidence — manual verification required.")
                    .foregroundColor(.orange)
                Text(estimate.absorptionRationale)
                ForEach(estimate.assumptions, id: \.self) { Text($0).font(.footnote) }
                Text(estimate.provenance).font(.caption).foregroundColor(.secondary)
            }
            Section("Review details") {
                Text("Enter 0–250 g and 30–480 minutes. These are prototype bounds, not recommended treatment values.")
                    .font(.footnote).foregroundColor(.secondary)
                Button("Discard photo and review", role: .destructive) { discard() }
            }
        }
    }

    private func labeledField(_ label: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField(label, text: binding).keyboardType(.decimalPad)
        }
    }

    private func quantity(_ quantity: EstimatedQuantity, unit: String) -> String {
        String(format: "%.0f %@ (range %.0f–%.0f)", quantity.value, unit, quantity.lower, quantity.upper)
    }

    private func discard() {
        model.clear()
        transferError = nil
        manualCarbs = ""
        manualMinutes = "180"
        manualFood = ""
        mealTime = Date()
    }

    private func openCamera() {
        guard model.mode == .demo || model.canUseAI else {
            cameraError = "Connect to the AI service before photographing a meal."
            return
        }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraError = "This device has no available camera. Use the demo meal button in the simulator."
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: showCamera = true
        case .notDetermined:
            requestingCamera = true
            Task { @MainActor in
                let allowed = await AVCaptureDevice.requestAccess(for: .video)
                requestingCamera = false
                guard UIApplication.shared.applicationState == .active else { return }
                if allowed { showCamera = true }
                else { cameraError = "Camera access was denied. You can allow access in Settings or use the demo meal button." }
            }
        case .denied, .restricted:
            cameraError = "Camera access is denied or restricted. You can check Settings or use the demo meal button."
        @unknown default:
            cameraError = "Camera access could not be determined. Use the demo meal button."
        }
    }

    private func scenarioTitle(_ scenario: MockScenario) -> String {
        switch scenario {
        case .balancedMeal: return "Mixed meal"
        case .highFatMeal: return "High fat meal"
        case .uncertainPortion: return "Uncertain portion"
        case .unrecognizable: return "Unrecognizable meal"
        case .offline: return "Offline failure"
        case .timeout: return "Timeout failure"
        }
    }

    private func startCameraIfRequested() {
        guard startsWithCamera, !startedCamera, model.canUseAI else { return }
        startedCamera = true
        openCamera()
    }

    private var connection: some View {
        Section("AI connection") {
            if model.hasPreconfiguredLogin {
                Label(model.canUseAI ? "AI photo analysis ready" : "Preparing AI photo analysis", systemImage: model.canUseAI ? "checkmark.circle" : "arrow.triangle.2.circlepath")
            } else if model.hasSavedLogin {
                Label("Login saved on this iPhone", systemImage: "checkmark.circle")
                Text("Your connection renews automatically. You can photograph meals without entering your password again.")
                    .font(.footnote).foregroundColor(.secondary)
                Button("Forget saved login", role: .destructive) { model.disconnect() }
            } else {
                SecureField("Tester password (one-time setup)", text: $model.testerCode)
                    .textInputAutocapitalization(.never).disableAutocorrection(true)
                Text("Enter the separate tester password once. It is saved securely on this iPhone after you connect.")
                    .font(.footnote).foregroundColor(.secondary)
                Button("Connect to AI service") { model.connect() }.disabled(model.connecting)
                DisclosureGroup("Service settings") {
                    TextField("HTTPS server address", text: $model.serverAddress)
                        .keyboardType(.URL).textInputAutocapitalization(.never).disableAutocorrection(true)
                        .disabled(model.connecting)
                    Text("The Loop+ address is already filled in. Keep your OpenAI API key on the server.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            if model.connecting { ProgressView("Connecting…") }
            if let error = model.connectionError {
                Text(error).foregroundColor(.orange)
                if model.hasSavedLogin || model.hasPreconfiguredLogin {
                    Button("Retry connection") { model.resume() }.disabled(model.connecting)
                }
            } else if case .failed(.authenticationRequired) = model.state, model.hasSavedLogin || model.hasPreconfiguredLogin {
                Button("Retry connection") { model.resume() }.disabled(model.connecting)
            }
            Text("OpenAI requests consume API credits. The prototype backend allows up to 10 photos per day and 3 per minute. Failed provider requests also count; there are no automatic retries.")
                .font(.footnote).foregroundColor(.secondary)
            Text("Captured meal photos are analyzed automatically by OpenAI.")
                .font(.footnote).foregroundColor(.secondary)
            Link("OpenAI photo data policy", destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!)
                .font(.footnote)
        }
    }
}
#endif
