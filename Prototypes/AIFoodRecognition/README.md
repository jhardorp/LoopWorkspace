# Food recognition prototype

This is a standalone, mock-only iPhone app and a dependency-free Swift package. It previews a camera button beside the same input concepts as Loop's carbohydrate-entry screen, then displays editable carbohydrates and absorption duration. It does **not** add that button to the installed Loop app or wire the prototype into Loop's existing screen. That is a subsequent integration step.

The photo is not analyzed. Every photo returns the selected fictional fixture. The examples demonstrate portions, nutritional composition, uncertainty ranges, and absorption rationale; their values and durations are not clinically validated.

## Scope and isolation

- No Loop, LoopKit, HealthKit, CGM, meal-history, pump, or therapy-store dependency.
- No network requests, API credentials, analytics, file writes, photo-library saves, or persisted reviews.
- “Finish demo review” only marks the current in-memory review complete. Editing a value clears that marker. It never creates a carb entry, calculates a bolus, or administers insulin.
- Separate project, scheme, display name, and bundle identifier (`org.loopprototype.FoodRecognitionSandbox`). No change to the Loop workspace, signing configuration, version, submodule pins, or deployment workflows.
- A photo is redrawn to a maximum 1280-pixel dimension and encoded as JPEG without original EXIF metadata. Discard, a new request, and entering the background clear the current review/photo. Camera capture cancellation discards the capture.

## Files

| Location | Purpose |
| --- | --- |
| `Sources/FoodRecognitionCore` | Provider interface, typed responses, validation, mock fixtures, transient review session |
| `PrototypeApp` | SwiftUI entry preview/review, UIKit camera bridge, independent Xcode project |
| `Tests/FoodRecognitionCoreTests` | Core validation, locale input, failure/retry, cancellation, and concurrency tests |
| `../../docs/ai-food-recognition.md` | Repository inspection, fork decision, and real AI integration plan |

## Review and verification

On a Mac with Xcode 15 or newer, open `PrototypeApp/FoodRecognitionPrototype.xcodeproj` independently of `LoopWorkspace.xcworkspace`. The shared scheme is `FoodRecognitionPrototype`. This work was not deployed, installed, merged, or submitted to TestFlight.

Run core tests without signing, devices, or submodules:

```sh
cd Prototypes/AIFoodRecognition
swift test
```

Compile the iPhone UI without installation or signing, from the repository root:

```sh
xcodebuild \
  -project Prototypes/AIFoodRecognition/PrototypeApp/FoodRecognitionPrototype.xcodeproj \
  -scheme FoodRecognitionPrototype \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/FoodRecognitionPrototypeDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

The prototype-only PR workflow runs `swift test` and an unsigned simulator **build**, with no simulator launch, installation, archive, deployment, or secrets. It does not invoke Loop's build/release workflows.

Local validation on 2026-10-11: 16 XCTest tests passed using Swift 6.0.3 on Linux with container networking disabled. Xcode/UIKit/SwiftUI compilation and visual/device checks were unavailable locally. Check the PR's macOS build result before treating the app target as verified.

Manual UI checks for a later, explicitly authorized simulator/device review:

1. Select each demo result and use “Use demo meal without camera.” The mixed and high-fat fixtures show foods, portions, composition, total carbs, duration, ranges, and rationale.
2. For the uncertain/high-fat examples, finishing requires explicit acknowledgment. Blank, negative, malformed, and out-of-bounds edits disable finishing. Locale decimal input is accepted.
3. Edit carbs and duration, finish the demo review, then edit again. The completion message disappears. Discard removes the review; nothing is transferred to the manual entry preview.
4. Offline and timeout examples show an error without numeric fallback. The unrecognizable example asks for more information. Retry with a successful example.
5. Cancel an in-flight estimate, discard, or background the app. A late result must not restore the review.
6. In a simulator, the camera button explains camera unavailability. On a later authorized device check, verify permission grant/denial/restriction, capture, cancel, rotation/orientation, large photos, VoiceOver, and large text. No photo should appear in Photos.

## Provider boundary

`FoodEstimating.estimate(photo:)` is an asynchronous, injectable interface. `MealEstimateSession` validates **every** returned estimate before creating an editable `ReviewDraft`. Unknown provider errors become invalid-response failures. Cancellation and request identifiers prevent old responses replacing a new or discarded review. Unrecognizable meals carry no numeric estimate. A real provider must reject `MealPhoto.Kind.demo`.

No absorption algorithm is implemented here: durations are explicit fixtures. A real model's food/portion interpretation and any composition-based duration method need independent evaluation before therapy-related use. See the integration plan for backend security, nutrition grounding, and the proposed Loop UI boundary.
