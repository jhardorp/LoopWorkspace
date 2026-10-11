# Loop+ food recognition prototype

Loop+ is a **separate iPhone meal-review app**, not a modified Loop installation. Version 0.1.0 (1) was installed by the owner. Apple accepted the separate **0.2.0 (2)** upload on 2026-10-11 in [run 38175789487](https://github.com/jhardorp/LoopWorkspace/actions/runs/38175789487); processing/device update are not verified by the upload lane. Version 0.2.0 adds opt-in OpenAI photo analysis through an authenticated, owner-controlled backend and retains the explicitly labeled mock demo. Live AI requires configured backend credentials and API credits; compiling the app alone cannot enable it.

The preview mirrors amount, time, food type and absorption duration from Loop's carbohydrate-entry screen. It does **not** yet add a camera button to Loop's actual screen. See [repository inspection and fork decision](../../docs/ai-food-recognition.md).

## Scope and isolation

- No Loop, LoopKit, HealthKit, CGM, historical meal, insulin, pump or therapy-store dependency. No dosing-algorithm or insulin-delivery changes.
- AI values stay in an editable, transient review. “Finish review” only marks that review complete in memory; it never creates a carb entry, populates the manual preview, calculates insulin or sends values to Loop.
- Separate project/scheme/app identifier. Unsigned builds use `org.loopprototype.FoodRecognitionSandbox`; the authorized TestFlight workflow signs only `com.jhardorp.foodrecognitionprototype`. Loop's installation, workspace, version, submodule pins, signing configuration and `main` remain unchanged.
- Each real photo requires upload confirmation. Only the current JPEG is sent, with no previous meal or therapy data. It is redrawn to at most 1280 pixels, omits original EXIF/location metadata and is capped at 1 MiB for remote requests.
- Photos/reviews are not persisted, logged, sent to analytics or saved in Photos. Discard, a new request and backgrounding clear the current review/photo. Camera/consent cancellation clears pending captures; dismissing consent without approval does not upload. Backgrounding cancels an in-flight request, but cannot retract a photo already received by a service.
- Only the URL and a 30-minute app session token are stored in this app's device-only Keychain, accessible while unlocked. The tester code is cleared after submission. Disconnect removes the token; the OpenAI API key never enters the app.
- The backend does not persist images/estimates and sends OpenAI `store: false`. This **does not** promise zero provider retention: OpenAI's data policy, including abuse-monitoring retention, applies and is linked before upload. Cloudflare also processes network traffic and operational/account metadata under its terms.

## Estimates and uncertainty

The real provider uses an image-capable OpenAI model with strict structured output. It reports foods, portions/ranges, item/total carbohydrate grams, fat/protein/fiber, carbohydrate type, glycemic characteristics, assumptions and rationale. Nutrition is **AI inferred, not nutrition-database verified**. Total carbohydrate includes fiber; verify ingredients, portions and labels rather than assuming every food source uses the same convention.

All real estimates have low confidence. Absorption duration is an **experimental composition-based estimate**, not an individualized digestion prediction or a validated Loop absorption-time parameter. The 30–480 minute and 0–250 g limits are prototype validation bounds, not treatment recommendations. Passing code tests does not establish nutritional or physiological accuracy.

Unclear photos request clarification with no numbers. Authentication, quota, timeout, offline, provider and invalid-response failures also produce no fallback estimate. There are no automatic retries. Mock mode remains offline: every photo returns the selected fictional fixture, unrelated to the image; its 180/300-minute durations are not production defaults.

## Setup and files

See [TestFlight](TESTFLIGHT.md) for the separate iPhone trial without a Mac and [browser-only backend setup](Backend/SETUP.md) for real AI. This implementation requires no additional monthly subscription: OpenAI API credits are billed separately and Cloudflare's free tier has usage limits.

| Location | Purpose |
| --- | --- |
| `Sources/FoodRecognitionCore` | Injectable providers, bounded HTTPS transport, validation and transient review |
| `PrototypeApp` | Connection, camera, per-photo consent and editable review; separate Xcode project |
| `Backend` | OpenAI adapter, strict output contract, short-lived app auth and persistent counters |
| `Tests/FoodRecognitionCoreTests` | Validation, locale edits, HTTP errors, cancellation and stale replies |
| `Distribution` | Separate signing/upload lane and configuration guard tests |

## Verification

Run without signing, devices, submodules or real API requests:

```sh
cd Prototypes/AIFoodRecognition
swift test
cd Backend
npm ci
npm run check
npm test
npx --no-install wrangler deploy --dry-run
```

From the repository root, compile the standalone UI without signing/installation:

```sh
xcodebuild \
  -project Prototypes/AIFoodRecognition/PrototypeApp/FoodRecognitionPrototype.xcodeproj \
  -scheme FoodRecognitionPrototype \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/FoodRecognitionPrototypeDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

On 2026-10-11, 28 Swift core tests passed locally with Swift 6.0.3 on Linux and container networking disabled. Seventeen Node backend tests, syntax checks and Wrangler dry-run bundling passed. Provider calls are stubbed: these results do **not** verify live credentials, food accuracy or absorption validity. Feature-only CI checks macOS core tests, four existing Ruby guards and an unsigned simulator build, plus backend tests/dry run. The macOS tests, unsigned UI build and separate signed 0.2.0 upload subsequently passed in the runs linked below; live provider/device checks remain pending.

Manual checks for the separately authorized owner trial:

1. In OpenAI mode, connect with the deployed HTTPS URL and separate tester code. Check wrong/expired credentials and Disconnect. Provider keys entered as tester codes are rejected before network access.
2. Capture a photo and Cancel/swipe away the upload preview: no estimate request should occur. Backgrounding during capture/consent clears the pending image. Approval sends one photo only.
3. With a configured backend and credits, photograph an actual meal with a useful portion reference. Verify foods reflect the image, uncertainty/experimental labels appear and both estimates are editable. Low confidence requires acknowledgment.
4. Try an unreadable photo, offline connection, revoked token and exhausted quota. Expect explanations/clarification without mock numbers. A paid request may still consume credits after local cancellation.
5. Cancel/discard/background an in-flight request; a late response must not restore review. Finishing/editing/discarding must remain entirely within this app.
6. In Mock demo, exercise every fixture, locale/malformed edits, acknowledgment and simulated failures with no network traffic.
7. Check camera permissions/capture/cancel/orientation, large images, VoiceOver and large text on-device. Neither mode should save a photo or affect Loop.

## Provider boundary

`FoodEstimating.estimate(photo:)` is injectable. `BackendFoodEstimator` rejects demo input, expired auth and invalid photos before upload. Its ephemeral bounded `URLSession` refuses redirects and disables cookies/disk cache. The backend validates strict model JSON; the iPhone validates the versioned response and every estimate again before creating a `ReviewDraft`. Cancellation/request identifiers prevent old replies restoring an abandoned review. The only finish outcome is an in-memory flag.

Backend checks also passed on GitHub in [validate-only run 38174675553](https://github.com/jhardorp/LoopWorkspace/actions/runs/38174675553), without server credentials, deployment or paid provider requests.

The updated macOS core tests, four Ruby guards, unsigned iPhone simulator build and backend checks passed in [PR run 38175329086](https://github.com/jhardorp/LoopWorkspace/actions/runs/38175329086). The separately authorized 0.2.0 (2) signed build/upload also passed in [run 38175789487](https://github.com/jhardorp/LoopWorkspace/actions/runs/38175789487). The log confirms App Store Connect accepted the package; it does not verify Apple processing, internal tester availability or a device update.
