# Loop AI Test — separate installation candidate

This prepares an experimental AI interface test app alongside the working Loop.
It does not upgrade or replace the working Loop. No upload or device installation
is performed by the preparation workflow. A separate, explicitly authorized upload
job can send the exact validated candidate to TestFlight, as described below.

## Identity and isolation

- Display name: **Loop AI Test**, with a new orange TEST icon.
- Bundle ID: **`com.jhardorp.loopaiphototest`**.
- URL scheme: `loop-ai-test`.
- Empty source entitlements: no HealthKit, app groups, shared keychain, Siri,
  Bluetooth/NFC capabilities or background device services.
- The final signed artifact is checked for unexpected entitlements, production
  identity/keychain access, extensions, watch apps and dynamic device plugins.
- Its declared group name is distinct, but no app-group access is granted.
  Preferences and the remembered AI login belong to this app's own container and
  default keychain group. It cannot read the working Loop's group or keychain.
- Test meal entries exist only in memory and disappear when the process exits.
  Favorites/preferences and AI connection settings may persist in the test app's
  own storage. AI photos still use the unchanged personal backend and API credits.

## What this tests

The generator starts from the same pinned upstream Loop source and applies the
same reviewed photo adapter. It preserves the real native carbohydrate editor,
quantity limits, entry time, camera/gallery presentation, comment refinement,
confidence review, explicit Use in Loop handoff, and stable new-entry identity.
The generated application starts a new SwiftUI home, without instantiating the
production AppDelegate, SceneDelegate, LoopAppManager or device/store managers.

Continue opens a **test entry preview** instead of the insulin/bolus screen.
Save test entry records one copy in the memory ledger. No test entry is written to
HealthKit or the working Loop. The delegate rejects storage, glucose and delivery
requests; there is no pump or CGM setup screen. This tests the photo-to-native-editor
integration; it does not validate the real bolus screen, therapy, upgrade of existing
stores, or rollback. Production algorithms and communication source remain unchanged.

The personal tester login is injected only into the signed test candidate by the
unchanged production configurator. No OpenAI key is added to the app. The candidate
is personal and must not be publicly redistributed.

## Validation and archive

The migration-only `Separate Loop AI test app` workflow pins Xcode 26.3 and verifies
protected production configuration. It runs five isolation regression tests and
four memory-ledger tests, builds the app unsigned, packages it for Simulator with
Xcode ad-hoc signing, checks effective isolation, and runs two actual UI cases:
native editor cancellation and one explicit test save followed by an empty relaunch.
It refuses an empty UI test run.

Source **`8af1328f54fa72807c3fe314d82f67cf488603a1`** passed all 11 new checks in
[run 39597325857](https://github.com/jhardorp/LoopWorkspace/actions/runs/39597325857).
The unsigned build passed at **2026-10-21 12:18:34 UTC**, ad-hoc packaging at
12:20:09 and both UI tests at **12:28:10**. Effective Simulator entitlements were
empty; the product used the separate test ID, version **0.1.0 (4)**. Evidence
artifact `12345008663` was retained successfully. On the same unchanged runtime
code, the normal migration's 90 regressions, unsigned build and normal startup
also passed at `7018ca0f8766db40594a327111d386644730ffaf`. Only the separate signing
wrapper changed afterwards. The separate signed candidate has also **passed**
on the current source, as recorded below. No physical-device installation has occurred.

The signing wrapper imports the existing certificate read-only, retrieves Sigh's
actual downloaded file through `SIGH_PROFILE_PATH`, and resets Fastlane's profile
mapping to this app alone before export. It disables automatic profile detection,
so unrelated production profiles or nil import mappings cannot enter its export.

An explicit `[sandbox-candidate]` migration commit marker or the manual
`prepare_signed_sandbox` input requests an archive after the checks pass. The signing
lane reads the existing certificate/key with read-only match, then creates/downloads
only the new test app's identifier/profile using that existing certificate. It does
not create or renew certificates, change production profiles or write the signing
repository. Root signing/distribution configuration remains unchanged.

The archive contains `LoopAIPhotoTest.ipa`, `SandboxCandidate.json` with effective
identity, isolation, source and IPA hash, and `AppRecordStatus.json`. A separate App
Store Connect app record is required for future TestFlight distribution. The lane
checks whether it exists and attempts to create only this new app's private record.
If the API connection cannot create records, it records that remaining setup without
publishing or discarding the signed archive. It does not upload. The App Store
IPA is not directly installable. Upload or installation requires the user's explicit
approval under the migration instructions.

## Prepared candidate — 2026-10-21

The final source **`8af1328f54fa72807c3fe314d82f67cf488603a1`** passed all 11
separate-app checks and the signed archive in
[run 39597325857](https://github.com/jhardorp/LoopWorkspace/actions/runs/39597325857).
The unsigned build passed at **12:18:34 UTC**, ad-hoc packaging at **12:20:09**,
and both UI tests at **12:28:10**. The signed App Store IPA exported at **12:38:55**,
then passed the exported-product identity/isolation check at **12:39:09**.

- App: **Loop AI Test 0.1.0 (4)**, `com.jhardorp.loopaiphototest`.
- Signed entitlement keys: application identifier, team identifier, beta reports
  and get-task-allow. No HealthKit, shared app group or shared-keychain entitlement.
- [Candidate artifact 12346108397](https://github.com/jhardorp/LoopWorkspace/actions/runs/39597325857/artifacts/12346108397)
  includes the IPA, `SandboxCandidate.json` and `AppRecordStatus.json`; it expires
  **2026-10-28 12:39:11 UTC**.
- IPA SHA-256: `888f37757cd83537228018437d1bfa2a78e6da5660cddd8d17f99959cd8d3a55`.
- [Validation artifact 12345008663](https://github.com/jhardorp/LoopWorkspace/actions/runs/39597325857/artifacts/12345008663)
  retains logs and xcresult for 14 days.
- The new developer identifier/profile exists. App Store Connect app-record
  creation did not succeed through the API connection; the run found no record.
  No TestFlight upload, physical-device installation, deployment or production
  branch/configuration change occurred.

## Remaining Apple app-record setup

Open [App Store Connect → Apps](https://appstoreconnect.apple.com/apps). If the
separate record is not already listed, select **+ → New App** and use:

| Field | Value |
|---|---|
| Platform | iOS |
| Name | Loop AI Test jhardorp |
| Primary language | English (U.S.) |
| Bundle ID | `com.jhardorp.loopaiphototest` (already registered) |
| SKU | `loop-ai-photo-test` |

Creating this empty record does not publish the app. The signed App Store IPA
cannot be installed directly; it still needs an explicitly approved TestFlight
upload and Apple processing before on-phone testing. This setup does not replace
or change the existing Loop app record.

## Apple record correction — 2026-10-21

The first approved upload attempt reverified the exact IPA but stopped before
uploading because Apple could not find the new bundle ID. A read-only check in
[run 39623975150](https://github.com/jhardorp/LoopWorkspace/actions/runs/39623975150)
identified the owner's newly created **Loop AI Test jhardorp** app record bound to
Loop's widget-extension ID instead of the isolated app ID. The expected separate
developer identifier was already registered and visible to the API connection.

Apple rejected API record creation with `apps does not allow CREATE`. The correction
therefore targeted only that exact named test record after confirming **zero
uploaded builds**. PATCH changed only its App Store Connect bundle-ID field to
`com.jhardorp.loopaiphototest`. A fresh read at **15:26:04 UTC** confirmed the right
name and bundle ID; a repeat check in
[run 39625154770](https://github.com/jhardorp/LoopWorkspace/actions/runs/39625154770)
passed at **15:37:32 UTC**. The initial immediate collection lookup was stale;
the correction helper now reads the known record ID with bounded retries.
Registered production/widget identifiers, signing profiles, app records for the
working Loop and the installed app were not changed.

The authorized upload of the same **0.1.0 (4)** signed IPA subsequently succeeded, as recorded below.
The upload-only job uses the documented **macos-15-intel** runner and the same
**Xcode 26.3 (17C529)** after the default macOS runner queue stalled. No binary is
rebuilt. The upload job's `UploadStatus.json` records the actual final outcome.

## Approved upload result — 2026-10-21

**Apple accepted Loop AI Test 0.1.0 (4)** at **15:42:17 UTC** in
[successful run 39627647246](https://github.com/jhardorp/LoopWorkspace/actions/runs/39627647246),
wrapper source `9e1de9e42cddcc37b2d19b649e410131f0c739b5`. It uploaded the existing
signed IPA from `8af1328f54fa72807c3fe314d82f67cf488603a1`, without rebuilding.
The exact IPA hash, signature, source, identity and isolation were reverified at
**15:39:49 UTC** before upload. Its SHA-256 remains
`888f37757cd83537228018437d1bfa2a78e6da5660cddd8d17f99959cd8d3a55`.

Apple app ID: **6825358390**; bundle: `com.jhardorp.loopaiphototest`.
The corrected **Loop AI Test jhardorp** record now uses the expected bundle ID.
After 20 minutes of polling, the final check at **16:02:26 UTC** still returned
`upload_accepted: true`, `processing_state: AWAITING_APPLE_RECORD`. No processed
build ID or internal-testing readiness was returned. Workflow success establishes
upload acceptance, **not** completed Apple processing or installation readiness.
Do not reupload the same build solely because it has not appeared yet.

[Evidence artifact 12358982603](https://github.com/jhardorp/LoopWorkspace/actions/runs/39627647246/artifacts/12358982603)
contains `VerifiedUpload.json` and `UploadStatus.json`, retained until
**2026-11-04 16:02:28 UTC**. The next Apple status is visible at
[the separate app's TestFlight page](https://appstoreconnect.apple.com/apps/6825358390/testflight/ios).
External distribution was disabled; tester groups were not changed. No physical
installation, production deployment, merge, certificate/profile renewal or backend
change occurred. The working Loop remains untouched. Independent/manual safety
validation remains pending; this is an isolated AI interface test app.

## On-phone acceptance after approved distribution

On 2026-10-21 the owner confirmed creation of the separate Apple record and
explicitly authorized: **"Created, upload the test app"**. The migration-only
`[sandbox-upload-approved]` job is restricted to the existing **0.1.0 (4)** IPA
and its recorded SHA-256 above. It requires the successful source validation run,
downloads that exact retained artifact, rechecks the signature/identity/isolation,
and uploads only `com.jhardorp.loopaiphototest`. It reuses an existing Apple build
instead of uploading a duplicate, records processing status, and does not change
signing, production, external tester groups or install anything on a device.
`UploadStatus.json` is the evidence for the actual upload/processing outcome;
this authorization alone does not establish a successful upload.

Keep the working Loop installed. Open **Loop AI Test** and verify its TEST label.
Use Test a meal entry to check first-tap camera/gallery routing, cancellation,
photo analysis, comments such as two portions/product corrections, low confidence,
decimal editing, original entry time and wrapped descriptions. Explicitly transfer
the result into this app's editor, then Continue and Save test entry. One save must
show one test entry; cancelling must show none. Restarting this app clears test entries.
The production Loop must remain unchanged throughout. Independent validation remains
required before this migration is considered for therapy.
