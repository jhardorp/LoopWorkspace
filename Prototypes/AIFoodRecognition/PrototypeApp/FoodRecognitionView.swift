#if canImport(UIKit)
import AVFoundation
import FoodRecognitionCore
import SwiftUI
import UIKit

@MainActor
public struct FoodRecognitionView: View {
    @StateObject private var model = PrototypeViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let startsWithCamera: Bool
    private let startsWithPhotoLibrary: Bool
    private let onUseMeal: (@MainActor (ReviewedMeal) -> Bool)?
    @State private var startedCamera = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var loadingLibraryPhoto = false
    @State private var cameraError: String?
    @State private var requestingCamera = false
    @State private var transferError: String?
    @FocusState private var commentFocused: Bool
    @State private var manualCarbs = ""
    @State private var manualMinutes = "180"
    @State private var manualFood = ""
    @State private var mealTime = Date()

    public init(startsWithCamera: Bool = false, startsWithPhotoLibrary: Bool = false, onUseMeal: (@MainActor (ReviewedMeal) -> Bool)? = nil) {
        self.startsWithCamera = startsWithCamera
        self.startsWithPhotoLibrary = startsWithPhotoLibrary
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
        .alert("Photo unavailable", isPresented: Binding(get: { cameraError != nil }, set: {
            if !$0 { cameraError = nil }
        })) {
            Button("OK", role: .cancel) { cameraError = nil }
        } message: {
            Text(cameraError ?? "")
        }
        .sheet(isPresented: $showPhotoLibrary, onDismiss: { loadingLibraryPhoto = false }) {
            MealPhotoLibraryView(onSelect: { image in
                showPhotoLibrary = false
                loadingLibraryPhoto = false
                guard UIApplication.shared.applicationState == .active else { return }
                model.analyze(image, consentToUpload: true)
            }, onCancel: { showPhotoLibrary = false }, onFailure: {
                showPhotoLibrary = false
                cameraError = "The selected photo could not be loaded. Try another image."
            }, onLoading: { loadingLibraryPhoto = true })
            .overlay {
                if loadingLibraryPhoto {
                    VStack(spacing: 12) {
                        ProgressView("Loading photo…")
                        Button("Cancel", role: .cancel) { showPhotoLibrary = false }
                    }
                    .padding().background(.regularMaterial).cornerRadius(12)
                }
            }
        }
        // UIKit hosts do not reliably supply SwiftUI's scenePhase environment.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            discard()
            model.pause()
            showCamera = false
            showPhotoLibrary = false
            loadingLibraryPhoto = false
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
                Button(action: openPhotoLibrary) {
                    Label("Choose photo", systemImage: "photo.on.rectangle")
                }
                .accessibilityIdentifier("chooseMealPhoto")
                .disabled(model.state == .estimating || (model.mode == .openAI && !model.canUseAI))
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

    @ViewBuilder
    private func review(_ estimate: MealEstimate) -> some View {
        if #available(iOS 17.0, *) {
            reviewList(estimate).listSectionSpacing(12)
        } else {
            reviewList(estimate)
        }
    }

    private var reviewRowInsets: EdgeInsets {
        EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
    }

    private func reviewList(_ estimate: MealEstimate) -> some View {
        List {
            Section(model.mode == .demo ? "Demo result" : "Meal result") {
                Text("\(model.estimateLabel): \(estimate.carbohydrateGrams.value, specifier: "%.1f") g · \(estimate.absorptionMinutes.value, specifier: "%.0f") min")
                    .font(.headline)
                    .accessibilityIdentifier("mealEstimateSummary")
                labeledField("Carbohydrates", unit: "g", binding: model.binding(for: \.carbohydrateText, default: ""))
                    .accessibilityIdentifier("reviewCarbohydrates")
                labeledField("Absorption", unit: "min", binding: model.binding(for: \.absorptionMinutesText, default: ""))
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
                .disabled(!(model.draft?.canFinish(estimate: estimate) ?? false) || model.reviewedMeal == nil || model.reviewFinished || model.refining || model.hasPendingComment || model.refinementQuestion != nil)
                .accessibilityIdentifier("finishReview")
                if model.hasPendingComment, !model.refining {
                    Text("Refine the comment below, or clear it to keep the current estimate.")
                        .font(.footnote).foregroundColor(.secondary)
                }
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
            .disabled(model.refining)
            .listRowInsets(reviewRowInsets)
            if model.mode == .openAI, !model.reviewFinished {
                refinementSection.listRowInsets(reviewRowInsets)
            }
            Section("Estimated ranges") {
                Text("Carbohydrates: \(quantity(estimate.carbohydrateGrams, unit: "g"))")
                Text("Absorption duration: \(quantity(estimate.absorptionMinutes, unit: "min"))")
            }
            .listRowInsets(reviewRowInsets)
            if let photo = model.photo { Section("Meal photo") {
                Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 180)
                    .accessibilityLabel("Current meal photograph")
            }.listRowInsets(reviewRowInsets) }
            Section(model.mode == .demo ? "Example foods and portions" : "Foods and estimated portions") {
                ForEach(Array(estimate.foods.enumerated()), id: \.offset) { _, food in
                    VStack(alignment: .leading, spacing: 3) {
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
            .listRowInsets(reviewRowInsets)
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
            .listRowInsets(reviewRowInsets)
            Section("Review details") {
                Text("Enter 0–250 g and 30–480 minutes. These are prototype bounds, not recommended treatment values.")
                    .font(.footnote).foregroundColor(.secondary)
                Button("Discard photo and review", role: .destructive) { discard() }
            }
            .listRowInsets(reviewRowInsets)
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 44)
        .environment(\.defaultMinListHeaderHeight, 16)
    }

    private var refinementSection: some View {
        Section("Improve estimate") {
            TextEditor(text: $model.refinementComment)
                .frame(height: 70)
                .focused($commentFocused)
                .accessibilityLabel("Comment to improve the meal estimate")
                .accessibilityIdentifier("mealRefinementComment")
                .overlay(alignment: .topLeading) {
                    if model.refinementComment.isEmpty {
                        Text("Larger slice, two portions, brand or ripeness…")
                            .foregroundColor(.secondary)
                            .padding(.top, 8).padding(.leading, 4)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .disabled(model.refining)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        if commentFocused {
                            Spacer()
                            Button("Done") { commentFocused = false }
                        }
                    }
                }
            if model.refining {
                ProgressView("Updating estimate…")
                Button("Cancel update", role: .cancel) { model.cancelRefinement() }
            } else {
                Button("Refine estimate") {
                    commentFocused = false
                    transferError = nil
                    model.refine()
                }
                .disabled(!model.canRefine)
                .accessibilityIdentifier("refineMealEstimate")
            }
            if let question = model.refinementQuestion {
                Text(question).foregroundColor(.orange)
                Text("Answer in the comment field to update the previous estimate.")
                    .font(.footnote).foregroundColor(.secondary)
            }
            if let error = model.refinementError {
                Text("The update did not complete. Your previous estimate and edits are unchanged.")
                    .foregroundColor(.orange)
                Text(model.errorMessage(error)).font(.footnote)
            }
            if !model.refinementComments.isEmpty {
                DisclosureGroup("Comments for this meal") {
                    ForEach(Array(model.refinementComments.enumerated()), id: \.offset) { _, comment in
                        Text(comment).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Text("AI uses this photo and your comments to revise the result. Each update uses one AI request.")
                .font(.footnote).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func labeledField(_ label: String, unit: String, binding: Binding<String>) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption).foregroundColor(.secondary)
                numericField(label, unit: unit, binding: binding)
            }
        } else {
            HStack(spacing: 12) {
                Text(label)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                numericField(label, unit: unit, binding: binding)
                    .frame(width: 110)
            }
        }
    }

    private func numericField(_ label: String, unit: String, binding: Binding<String>) -> some View {
        HStack(spacing: 4) {
            TextField(label, text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel("\(label), \(unit)")
            Text(unit).foregroundColor(.secondary).accessibilityHidden(true)
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
            cameraError = "This device has no available camera. Choose a photo from your gallery instead."
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
        guard startsWithCamera || startsWithPhotoLibrary, !startedCamera, model.canUseAI else { return }
        startedCamera = true
        if startsWithPhotoLibrary { openPhotoLibrary() }
        else { openCamera() }
    }

    private func openPhotoLibrary() {
        guard model.mode == .demo || model.canUseAI else {
            cameraError = "Connect to the AI service before choosing a meal photo."
            return
        }
        loadingLibraryPhoto = false
        showPhotoLibrary = true
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
            Text("OpenAI requests consume API credits. The prototype backend allows up to 1,000 photos per UTC day and 60 per minute. Failed provider requests also count; there are no automatic retries.")
                .font(.footnote).foregroundColor(.secondary)
            Text("Captured meal photos are analyzed automatically by OpenAI.")
                .font(.footnote).foregroundColor(.secondary)
            Link("OpenAI photo data policy", destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!)
                .font(.footnote)
        }
    }
}
#endif
