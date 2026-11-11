// Entry point for the separately identified UI test app only.
// The production AppDelegate, SceneDelegate and LoopAppManager are never started.
import UIKit
import SwiftUI
import LoopCore
import LoopKit
import LoopKitUI
import LoopAlgorithm
import MealPhotoSandboxSupport

@MainActor
final class AIPhotoSandboxAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        precondition(Bundle.main.bundleIdentifier == "com.jhardorp.loopaiphototest")
        precondition(Bundle.main.object(forInfoDictionaryKey: "MealPhotoSandbox") as? Bool == true)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: AIPhotoSandboxHome())
        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}

@MainActor
final class AIPhotoSandboxState: ObservableObject {
    @Published private(set) var ledger = MemoryMealLedger()
    let delegate = AIPhotoSandboxDelegate()

    func save(_ change: CarbEntryChange) -> Bool {
        guard case .add(let entry) = change, let seconds = entry.absorptionTime else { return false }
        return ledger.save(SandboxMeal(id: entry.syncIdentifier,
                                      grams: entry.quantity.doubleValue(for: .gram),
                                      absorptionSeconds: seconds, date: entry.startDate,
                                      notes: entry.foodType ?? ""))
    }

    func clear() { ledger.clear() }
}

@MainActor
struct AIPhotoSandboxHome: View {
    private struct Editor: Identifiable {
        let id = UUID()
        let viewModel: CarbEntryViewModel
    }
    @StateObject private var state = AIPhotoSandboxState()
    @StateObject private var glucosePreference = DisplayGlucosePreference(displayGlucoseUnit: .milligramsPerDeciliter)
    @State private var editor: Editor?

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Test the AI meal-photo flow here. Your working Loop remains separate.")
                    Text("No pump or CGM connection. No HealthKit access. Test entries disappear when this app closes.")
                        .font(.footnote).foregroundColor(.secondary)
                    Button("Test a meal entry") {
                        editor = Editor(viewModel: CarbEntryViewModel(delegate: state.delegate))
                    }
                    .accessibilityIdentifier("sandbox_new_entry")
                }
                Section {
                    ForEach(state.ledger.meals) { meal in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(meal.grams, specifier: "%.1f") g · \(meal.absorptionSeconds / 60, specifier: "%.0f") min")
                            Text(meal.notes).fixedSize(horizontal: false, vertical: true)
                            Text(meal.date, style: .time).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    if !state.ledger.meals.isEmpty {
                        Button("Clear test entries", role: .destructive, action: state.clear)
                    }
                } header: {
                    Text("Saved test entries: \(state.ledger.meals.count)")
                        .accessibilityIdentifier("sandbox_count")
                }
            }
            .navigationTitle("Loop AI Test")
        }
        .navigationViewStyle(.stack)
        .sheet(item: $editor) { item in
            CarbEntryView(viewModel: item.viewModel)
                .environmentObject(glucosePreference)
                .environmentObject(state)
                .environment(\.dismissAction, { editor = nil })
                .safeAreaInset(edge: .top) {
                    Text("TEST APP · Nothing is sent to your working Loop")
                        .font(.caption).padding(8).frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.2))
                }
        }
    }
}

/// Replaces the destination view only in this app. The real native editor,
/// its quantity checks, reviewed-value adapter and stable entry ID remain intact.
@MainActor
struct AIPhotoSandboxSummary: View {
    let viewModel: BolusEntryViewModel
    @EnvironmentObject private var state: AIPhotoSandboxState
    @Environment(\.dismissAction) private var dismiss
    @State private var saved = false

    var body: some View {
        List {
            if let entry = viewModel.carbEntryChange {
                Section("Reviewed test entry") {
                    Text("\(entry.quantity.doubleValue(for: .gram), specifier: "%.1f") g")
                    Text("\((entry.absorptionTime ?? 0) / 60, specifier: "%.0f") minutes absorption")
                    Text(entry.startDate, style: .time)
                    Text(entry.foodType ?? "").fixedSize(horizontal: false, vertical: true)
                }
                Section {
                    Text("This saves only a test entry in memory. It does not log food in HealthKit or your working Loop.")
                        .font(.footnote)
                    Button(saved ? "Test entry saved" : "Save test entry") {
                        saved = state.save(entry) || state.ledger.meals.contains { meal in
                            if case .add(let value) = entry { return meal.id == value.syncIdentifier }
                            return false
                        }
                    }
                    .disabled(saved)
                    .accessibilityIdentifier("sandbox_save_entry")
                    Button("Done", action: dismiss)
                }
            }
        }
        .navigationTitle("Test entry preview")
    }
}

/// No production manager, store or delivery delegate is supplied to the editor.
@MainActor
final class AIPhotoSandboxDelegate: CarbEntryViewModelDelegate {
    enum Unavailable: Error { case isolatedTestApp }
    let settings = StoredSettings(dosingEnabled: false, maximumBasalRatePerHour: 0, maximumBolus: 0)
    var defaultAbsorptionTimes: DefaultAbsorptionTimes { LoopCoreConstants.defaultCarbAbsorptionTimes }
    var scheduleOverride: TemporaryScheduleOverride? { nil }
    var preMealOverride: TemporaryScheduleOverride? { nil }
    var mostRecentGlucoseDataDate: Date? { nil }
    var mostRecentPumpDataDate: Date? { nil }
    var activeInsulin: InsulinValue? { nil }
    var activeCarbs: CarbValue? { nil }
    func isScheduleOverrideActive(at date: Date) -> Bool { false }
    func getGlucoseSamples(start: Date?, end: Date?) async throws -> [StoredGlucoseSample] { [] }
    func selectedFavoriteFoodLastEaten(_ food: StoredFavoriteFood) async throws -> Date? { nil }
    func getFavoriteFoodCarbEntries(_ food: StoredFavoriteFood) async throws -> [StoredCarbEntry] { [] }
    func getHistoricalChartsData(start: Date, end: Date) async throws -> HistoricalChartsData { throw Unavailable.isolatedTestApp }
    func effectiveGlucoseTargetRangeSchedule(presumingMealEntry: Bool) -> GlucoseRangeSchedule? { nil }
    func insulinModel(for type: InsulinType?) -> InsulinModel { ExponentialInsulinModelPreset.rapidActingAdult }
    func fetchData(for baseTime: Date?, presumePresetEndingNow: Bool, ensureDosingCoverageStart: Date?, projectOngoingDoses: Bool) async throws -> StoredDataAlgorithmInput { throw Unavailable.isolatedTestApp }
    func addCarbEntry(_ entry: NewCarbEntry) async throws -> StoredCarbEntry { throw Unavailable.isolatedTestApp }
    func replaceCarbEntry(_ entry: StoredCarbEntry, with update: CarbEntryUpdate) async throws -> StoredCarbEntry { throw Unavailable.isolatedTestApp }
    func saveGlucose(sample: NewGlucoseSample) async throws -> StoredGlucoseSample { throw Unavailable.isolatedTestApp }
    func storeManualBolusDosingDecision(_ decision: BolusDosingDecision, withDate date: Date) async {}
    func enactBolus(units: Double, decisionId: UUID?, activationType: BolusActivationType) async throws { throw Unavailable.isolatedTestApp }
    func recommendManualBolus(manualGlucoseSample: NewGlucoseSample?, carbEntryChange: CarbEntryChange?, truncatingActiveOverride: Bool) async throws -> ManualBolusRecommendation? { throw Unavailable.isolatedTestApp }
    func generatePrediction(carbEntryChange: CarbEntryChange?, potentialDose: SimpleInsulinDose?, manualGlucose: NewGlucoseSample?) async throws -> (historicGlucose: [StoredGlucoseSample], predictedGlucose: [PredictedGlucoseValue]) { throw Unavailable.isolatedTestApp }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv,
                  NSStringFromClass(UIApplication.self),
                  NSStringFromClass(AIPhotoSandboxAppDelegate.self))
