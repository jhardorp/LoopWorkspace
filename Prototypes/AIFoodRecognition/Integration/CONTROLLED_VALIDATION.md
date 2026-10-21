# Controlled validation of the experimental migration

Review: [draft PR #2](https://github.com/jhardorp/LoopWorkspace/pull/2), targeting the preserved `feature/ai-food-recognition` branch. Do not merge as part of validation. The complete source lock and comparison are in [MIGRATION_LOOP4.md](../../../MIGRATION_LOOP4.md).

## Evidence and its limits

Latest separate-app source: **`31b7bf86464c8033a3b5b6facf8df740600741dd`**.
[Run 39637426976](https://github.com/jhardorp/LoopWorkspace/actions/runs/39637426976)
**passed** on Xcode **26.3 (17C529)** on 2026-10-21:

- **Six metadata/isolation, four Swift memory-ledger and two native UI tests passed.**
  Coverage includes required privacy descriptions, forbidden permissions/identities/
  plugins, invalid or duplicate saves, cancellation, saving once and an empty relaunch.
- Full separate unsigned build: **16:52:11 UTC**; Xcode ad-hoc packaging:
  **16:53:16**; effective isolation: **16:53:21**; actual UI execution: **16:58:50**.
- Signed export: **17:09:00**; effective signed product verified: **17:09:02**.
  App **Loop AI Test 0.1.0 (12)**, `com.jhardorp.loopaiphototest`.
- Effective entitlement keys remain app/team IDs, beta reports and get-task-allow.
  No HealthKit/Siri/shared group/shared-keychain access, device plugin, watch app
  or extension. Four purpose descriptions required by the linked libraries are
  present; metadata does not enable these disabled features.
- [Candidate artifact 12364268218](https://github.com/jhardorp/LoopWorkspace/actions/runs/39637426976/artifacts/12364268218),
  expires **2026-10-28 17:09:03 UTC**. Validation artifact `12364246648` retains
  logs/xcresult. IPA SHA-256:
  `9935a6db0619b37d92cd6a591cfd321e0cceecef39dc36193bcfdf33ae9b4416`.

The unchanged application Swift/UI/support/dependency baseline passed **58 package
+ 26 backend + six native adapter tests**, unsigned build and normal 15-second
startup on iOS 18.5 in [run 39584372756](https://github.com/jhardorp/LoopWorkspace/actions/runs/39584372756),
source `7018ca0f8766db40594a327111d386644730ffaf`. Subsequent changes affect separate
packaging/metadata, verification/automation and documentation. Combined coverage:
**90 baseline + 12 current separate-app checks**.

**Apple processed the corrected build and marked it ready for internal testing**
at **17:16:19 UTC** in [successful upload run 39641532086](https://github.com/jhardorp/LoopWorkspace/actions/runs/39641532086),
wrapper `da69fc185d08687dfda82b822c8473847410e472`. The exact tested IPA was
reverified at **17:11:30**, then accepted at **17:13:16**. Final Build state:
`VALID`; `ready_for_internal_testing: true`; `missing_export_compliance: false`.
Build ID `a72128c7-aa71-4ea6-8839-478895349dff`; Apple app ID **6825358390**.
[Status artifact 12366255397](https://github.com/jhardorp/LoopWorkspace/actions/runs/39641532086/artifacts/12366255397)
contains verification/final-status records. The owner authorized this corrected
separate upload. No tester group/invitation, physical installation, production
deployment or merge was performed. The owner must add their own account/build to
an internal-testing group before installation through TestFlight.

Earlier build 4 was accepted by transport but **failed ingestion** for missing
privacy strings, as a fresh BuildUpload check confirmed. It is not installable.
The original widget-ID app-record error was corrected only on the exact named,
empty user-created test record, after confirming zero builds. Registered widget/
production IDs, their signing profiles, existing certificate, root signing,
backend and working Loop were preserved. See the [complete candidate/installation
guide](SideBySide/README.md#ready-for-internal-testing).

The isolated app starts the real migrated carbohydrate editor and the same AI
module. It uses a memory-only test destination instead of the real bolus screen,
without instantiating production startup, stores or device managers. This does
**not** validate live camera/gallery/provider behavior, actual production stored
entry counts, upgrades of existing stores, pump/CGM behavior or clinical safety.
The authoring assistant's review and tests are not independent validation.
The independent/manual record below remains PENDING. Earlier runs and packaging
failures/fixes are recorded in [MIGRATION_LOOP4.md](../../../MIGRATION_LOOP4.md).

## Source review completed by the authoring assistant

- The native overlay changes only the carbohydrate view/model, display of the entry on the bolus screen, and mock tests. The protected-file verifier guards the production signing, upload, backend and distribution configuration. Exact upstream gitlinks and remote Swift package revisions remain pinned.
- The native callback consumes its presentation token before updating fields. Cancelled, superseded and repeated callbacks cannot transfer. A rejected native range leaves the token available for correction; the adapter does not clamp or silently change reviewed values.
- Grams convert through Loop's quantity type to the preferred input unit. Absorption minutes convert to seconds once. Entry time stays unchanged, and the upstream new-entry identifier survives repeated reviews and Continue/back navigation.
- The transfer clears the selected favorite without allowing a queued favorite update to replace the reviewed values. Native favorite controls and native entry warnings remain available.
- The shared review requires a user action to transfer. Low confidence also requires acknowledgement. Pending clarification, unsent comments and in-progress refinement block transfer. Analysis/refinement errors do not produce fallback estimates.
- No custom changes were made to dosing algorithms, pump/CGM communication or therapy settings. Updating the pinned upstream introduces upstream changes in those areas; independent review must include them.

## Installation route must preserve the working app

The requested same-phone preparation now has a distinct **Loop AI Test** mode,
`com.jhardorp.loopaiphototest`, described in [SideBySide/README.md](SideBySide/README.md).
It keeps the actual migrated carbohydrate editor but replaces production startup
and the bolus destination with isolated test UI. It grants no HealthKit, app-group
or shared-keychain access and saves test entries only in memory. The working Loop
is not replaced. The normal app's 90 regressions/build/startup passed again on
`7018ca0f8766db40594a327111d386644730ffaf`; separate-app checks and UI tests also
passed. Artifact retention initially hit a connection reset; attempt 2 passed
again and retained its evidence. The final signed separate candidate then passed
all checks as recorded above. Its on-phone/live AI checks remain pending.

The following full-Loop routes retain the earlier same-identity candidate. The separate
AI test mode above is the current same-phone preparation.

The existing `Loop meal photo review` upload workflow is restricted to the production feature branch and hardcodes its existing app identity. It must not be repurposed to ship this migration.

Choose the test setup before distributing or installing a candidate. The archive-only preparation below retains the existing identity for review and does not install anything:

| Setup | Required preparation |
|---|---|
| Spare/test iPhone | A migration-only manual workflow may reuse existing signing identities. Install only on the test phone. Keep production pump/CGM credentials and production HealthKit data out of the test setup. |
| Current iPhone alongside working Loop | Register a distinct main bundle ID, all extension IDs, app group, provisioning profiles, URL scheme and App Store Connect app record. Keep the production IDs/profiles and signing configuration unchanged. A distinct bundle ID alone does **not** isolate the shared HealthKit database. |

A candidate must build the normal app, never the generated adapter test host. Record its source SHA, all pins, Xcode version, resolved bundle IDs/app groups, version/build number and archive hash. Verify that no test-host entry point or test fixture is present. Use a separate manual, migration-only workflow; never synchronize upstream automatically or renew/revoke the production certificates as part of this test.

The validation workflow now offers a manual `prepare_signed_candidate` option (default **false**). An explicit `[archive-candidate]` marker in a migration push's head commit message requests the same archive when manual dispatch is unavailable. Ordinary pushes do not request signing. After validation passes in the same run, a separate job checks out the same source again, selects the same pinned Xcode 26.3, verifies protected configuration, applies the normal app overlay and invokes `experimental_archive/fastlane/Fastfile`. It uses existing signing with `MATCH_READONLY=true` and locked remote package versions. It does not create or renew certificates/profiles, upload to TestFlight, install on a device, merge, or deploy. The archive retains the personal tester login behavior from production. The IPA and a source/version/bundle/hash record are retained for seven days as review artifacts.

This archive option retains the production app identity and is intended for eventual testing on a **spare test device only**. It is unsuitable for side-by-side installation on the working phone. It uses the existing App Store export method; that IPA cannot be installed directly on a phone. The signed archive now exists as recorded above, but no TestFlight build was uploaded. TestFlight/device distribution is not implemented in this workflow. No physical-device installation, deployment or merge occurred. A test build must stay experimental until independent validation is recorded.

## Independent review and manual acceptance record

The reviewer must record their name, date, exact source SHA, device/iOS version, evidence and failures. The table below is deliberately uncompleted; do not infer PASS from CI.

| Check | Required observable result | Result |
|---|---|---|
| Normal signed startup | Normal app entry point/scene loads; no Siri entitlement crash. | PENDING |
| First camera/gallery opening | First tap opens the chosen source; cancel changes no entry. | PENDING |
| Analysis | Chosen image yields a review with editable grams, minutes and notes. | PENDING |
| Manual edits | German decimal input, minutes-to-seconds conversion and long/multiline notes survive transfer; chosen entry time stays unchanged. | PENDING |
| Explicit confirmation | Receiving a result alone leaves Loop's entry unchanged. Low confidence requires acknowledgement and Use in Loop. | PENDING |
| Comment refinement | Larger slice, two portions, corrected product and ripeness comments reach refinement; only a confirmed revised result transfers. | PENDING |
| Refinement failures | Cancellation/failure keeps earlier edits; pending clarification/comment blocks transfer. | PENDING |
| Cancellation/backgrounding | Cancel/swipe/background during loading or analysis prevents late transfer; opening a fresh review works. | PENDING |
| Repeated use | Double tap, late callbacks and repeated review/back/Continue do not overwrite subsequent edits or create duplicate entries. | PENDING |
| Normal save | On an isolated test setup, one explicit ordinary save stores one entry with the reviewed values and original time. Check stored-entry identity and count, not just the visible fields. | PENDING |
| Display/favorites | Small screen, large text, wrapped notes, selected favorites, clearing favorites and manual input remain usable. | PENDING |
| Service failures | Authentication expiry, timeout, rate limit and malformed response leave manual entry usable and produce no invented estimate. | PENDING |
| Upstream changes | Independent assessment covers the pinned upstream's changes, including algorithm/device/therapy behavior outside the custom overlay. | PENDING |

Do not connect a production pump or use this candidate for therapy as part of these photo-review checks. Any later clinical/device validation requires an independently defined and supervised validation process. Passing this checklist alone is not a clinical safety claim.
