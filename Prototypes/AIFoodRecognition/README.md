# Loop+ and Loop meal photo review

**0.4.0 / Loop integration:** the shared review UI puts editable carbohydrate grams, absorption minutes and meal notes first, with ranges and explanations below. Personal signed builds preconfigure the tester login from GitHub secret storage and renew it automatically, so no server address or password needs to be typed. The new [Loop integration](Integration/README.md) adds **Photograph meal** to the feature branch's Loop 3.14.9 carb-entry screen; **Use in Loop** fills its editable fields before the existing Continue flow. The standalone Loop+ app uses the same result layout.

Loop+ is a **separate iPhone meal-review app**, not a modified Loop installation. Version 0.1.0 (1) was installed by the owner. Apple accepted the separate **0.2.0 (2)** upload on 2026-10-11 in [run 38175789487](https://github.com/jhardorp/LoopWorkspace/actions/runs/38175789487); processing/device update are not verified by the upload lane. Version 0.2.0 adds opt-in OpenAI photo analysis through an authenticated, owner-controlled backend and retains the explicitly labeled mock demo. On 2026-10-12, [deployment run 38209167402](https://github.com/jhardorp/LoopWorkspace/actions/runs/38209167402) published the backend and verified its public health endpoint. Use **`https://loop-plus-meal-review.jan-1af.workers.dev`** and the owner's private tester code in Loop+ 0.2.0. A consented photo with API credit is still needed to verify live OpenAI access and recognition; no paid model call has been made by this work.

The standalone preview mirrors amount, time, food type and absorption duration from Loop's carbohydrate-entry screen. The separately built Loop integration adds the camera button to the actual screen using a reviewed, source-pinned build overlay. See [integration and build details](Integration/README.md).

**0.3.0 (3) remembered login:** Apple accepted the separate update on 2026-10-12 in [run 38271487237](https://github.com/jhardorp/LoopWorkspace/actions/runs/38271487237). The public Loop+ server address is prefilled. Enter the separate tester password once; the app stores it in device-only Keychain storage and renews its 30-minute authorization automatically on foreground/use. An upgrade from 0.2.0 preserves the saved address but needs the password once because that older version did not retain it. Apple processing, internal tester assignment and the device update are not verified by the upload lane.

## Standalone app scope

- No Loop, LoopKit, HealthKit, CGM, historical meal, insulin, pump or therapy-store dependency. No dosing-algorithm or insulin-delivery changes.
- AI values stay in an editable, transient review. “Finish review” only marks that review complete in memory; it never creates a carb entry, populates the manual preview, calculates insulin or sends values to Loop.
- Separate project/scheme/app identifier. Unsigned builds use `org.loopprototype.FoodRecognitionSandbox`; the authorized TestFlight workflow signs only `com.jhardorp.foodrecognitionprototype`. Loop's installation, workspace, version, submodule pins, signing configuration and `main` remain unchanged.
- Each real photo requires upload confirmation. Only the current JPEG is sent, with no previous meal or therapy data. It is redrawn to at most 1280 pixels, omits original EXIF/location metadata and is capped at 1 MiB for remote requests.
- Photos/reviews are not persisted, logged, sent to analytics or saved in Photos. Discard, a new request and backgrounding clear the current review/photo. Camera/consent cancellation clears pending captures; dismissing consent without approval does not upload. Backgrounding cancels an in-flight request, but cannot retract a photo already received by a service.
- In 0.3.0, the URL, separate tester password and 30-minute app token are stored in this app's device-only Keychain, accessible while unlocked and without iCloud synchronization. The password field is cleared after submission. The app renews authorization with the saved password; it never automatically retries a photo. **Forget saved login** cancels pending renewal and deletes the saved connection. A changed/revoked password requires new one-time setup. The OpenAI API key never enters the app.
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

1. In OpenAI mode, confirm the server address is prefilled under **Service settings**. Enter the separate tester password once. Quit/reopen and background/foreground after more than 30 minutes: authorization renews without re-entering either value. Check offline/revoked credentials and **Forget saved login**. Provider keys entered as tester codes are rejected before network access. Upgrade from 0.2.0 keeps its saved address and needs the password once.
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

For 0.3.0, all **41 Swift tests** passed locally with Swift 6.0.3 and container networking disabled. The 13 new saved-login tests cover one-time setup/relaunch, expired/near-expiry renewal, legacy migration, shared concurrent renewal, offline retention without retry loops, revocation, logout/background cancellation, server/code binding, provider-key rejection, storage failure and invalidated-token renewal. [Run 38271487237](https://github.com/jhardorp/LoopWorkspace/actions/runs/38271487237) then passed all 41 tests on macOS, 18 backend tests (including the workerd regression), four Ruby guards and unsigned iPhone compilation before signing/export/upload. App Store Connect accepted **0.3.0 (3)**. iPhone Keychain/relaunch behavior and real food recognition still need a device trial.

Concurrent backend changes were preserved, including the workerd-compatible manual redirect mode and the owner's observability setting. A retry of [backend run 38252740671](https://github.com/jhardorp/LoopWorkspace/actions/runs/38252740671) recovered a Cloudflare secret-upload timeout and verified the public health endpoint. No paid provider request was made by these checks.
