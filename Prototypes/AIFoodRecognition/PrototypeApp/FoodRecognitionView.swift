import AVFoundation
import FoodRecognitionCore
import SwiftUI
import UIKit

struct FoodRecognitionView: View {
    @StateObject private var model = PrototypeViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCamera = false
    @State private var cameraError: String?
    @State private var requestingCamera = false
    @State private var pendingImage: UIImage?
    @State private var manualCarbs = ""
    @State private var manualMinutes = "180"
    @State private var manualFood = ""
    @State private var mealTime = Date()

    var body: some View {
        NavigationView {
            Group {
                if case .reviewing(let estimate) = model.state {
                    review(estimate)
                } else {
                    entry
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Discard") { discard() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            if let image = pendingImage {
                pendingImage = nil
                model.analyze(image)
            }
        }) {
            MealCameraView(onCapture: { image in
                pendingImage = image
                showCamera = false
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
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                discard()
                showCamera = false
            }
        }
    }

    private var title: String {
        if case .reviewing = model.state { return "Review Meal · Demo" }
        return "Add Carb Entry · Demo"
    }

    private var entry: some View {
        Form {
            Section {
                Text("Standalone prototype. Values and photos stay in memory. Nothing is saved or used for insulin therapy.")
                    .foregroundColor(.secondary)
            }
            Section("Carbohydrate entry preview") {
                TextField("Amount consumed (g)", text: $manualCarbs).keyboardType(.decimalPad)
                DatePicker("Time", selection: $mealTime)
                TextField("Food type", text: $manualFood)
                TextField("Absorption duration (minutes)", text: $manualMinutes).keyboardType(.decimalPad)
                Button(action: openCamera) {
                    Label("Photograph meal", systemImage: "camera")
                }
                .accessibilityIdentifier("photographMeal")
                .disabled(model.state == .estimating || requestingCamera)
            }
            Section {
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
            }
            status
        }
    }

    @ViewBuilder
    private var status: some View {
        switch model.state {
        case .estimating:
            Section {
                ProgressView("Preparing mock estimate…")
                Button("Cancel estimate", role: .cancel) { model.clear() }
            }
        case .failed(let error):
            Section("Estimate unavailable") {
                Text(errorMessage(error))
                Text("Retake the photo or use the demo button to retry. Your manual preview remains editable.")
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
            Section {
                Text("MOCK ESTIMATE — unrelated to your photo")
                    .font(.headline).foregroundColor(.orange)
                Text("Review and edit the values. Finishing this review does not save an entry or calculate insulin.")
                if let photo = model.photo {
                    Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 180)
                        .accessibilityLabel("Current meal photograph")
                }
            }
            Section("Example foods and portions") {
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
            Section("Estimates and uncertainty") {
                Text("Total carbohydrates: \(quantity(estimate.carbohydrateGrams, unit: "g"))")
                Text("Absorption duration: \(quantity(estimate.absorptionMinutes, unit: "min"))")
                Text(estimate.confidence == .low ? "Low confidence — confirm ingredients and portion size." : "Moderate confidence — manual verification required.")
                    .foregroundColor(.orange)
                Text(estimate.absorptionRationale)
                ForEach(estimate.assumptions, id: \.self) { Text($0).font(.footnote) }
                Text(estimate.provenance).font(.caption).foregroundColor(.secondary)
            }
            Section("Your editable review") {
                labeledField("Carbohydrates (g)", binding: model.binding(for: \.carbohydrateText, default: ""))
                    .accessibilityIdentifier("reviewCarbohydrates")
                labeledField("Absorption duration (minutes)", binding: model.binding(for: \.absorptionMinutesText, default: ""))
                    .accessibilityIdentifier("reviewAbsorption")
                TextField("Meal notes", text: model.binding(for: \.mealNotes, default: ""))
                Text("Enter 0–250 g and 30–480 minutes. These are prototype bounds, not recommended treatment values.")
                    .font(.footnote).foregroundColor(.secondary)
                if estimate.confidence == .low {
                    Toggle("I reviewed the uncertain portions and ingredients", isOn: model.binding(for: \.acknowledgesUncertainty, default: false))
                }
                Button("Finish demo review") { model.finishReview() }
                    .disabled(!(model.draft?.canFinish(estimate: estimate) ?? false))
                    .accessibilityIdentifier("finishReview")
                if model.reviewFinished {
                    Text("Review complete for this demo only. Nothing was saved or sent to Loop.")
                        .foregroundColor(.green)
                }
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
        pendingImage = nil
        manualCarbs = ""
        manualMinutes = "180"
        manualFood = ""
        mealTime = Date()
    }

    private func openCamera() {
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
                guard scenePhase == .active else { return }
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

    private func errorMessage(_ error: EstimationError) -> String {
        switch error {
        case .networkUnavailable: return "Simulated network failure. No estimate was produced."
        case .timedOut: return "Simulated timeout. No estimate was produced."
        case .invalidPhoto: return "The photo could not be prepared or exceeds the size limit."
        case .invalidResponse: return "The estimate response was invalid and was discarded."
        }
    }
}
