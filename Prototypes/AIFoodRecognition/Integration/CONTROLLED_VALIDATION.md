# Controlled validation of the experimental migration

Review: [draft PR #2](https://github.com/jhardorp/LoopWorkspace/pull/2), targeting the preserved `feature/ai-food-recognition` branch. Do not merge as part of validation. The complete source lock and comparison are in [MIGRATION_LOOP4.md](../../../MIGRATION_LOOP4.md).

## Evidence and its limits

Latest separate-app source: **`8af1328f54fa72807c3fe314d82f67cf488603a1`**.
The complete [run 39597325857](https://github.com/jhardorp/LoopWorkspace/actions/runs/39597325857)
**passed** on Xcode **26.3 (17C529)** on 2026-10-21:

- **Five isolation tests, four memory-ledger tests and two native UI tests passed**.
  The cases cover forbidden entitlements/identities/plugins, invalid or duplicate
  test saves, editor cancellation, one explicit test save and an empty relaunch.
- The separate unsigned build passed at **12:18:34 UTC**, Xcode ad-hoc packaging
  at **12:20:09**, and actual UI execution at **12:28:10**.
- The signed App Store IPA exported at **12:38:55**, then passed the effective
  identity/entitlement/bundle isolation check at **12:39:09**. It is
  **Loop AI Test 0.1.0 (4)**, `com.jhardorp.loopaiphototest`.
- Signed entitlements contain only application/team identification, beta reports
  and get-task-allow. No HealthKit, app-group or shared-keychain grant is present;
  no device plugin, watch companion or extension is included.
- [Candidate artifact 12346108397](https://github.com/jhardorp/LoopWorkspace/actions/runs/39597325857/artifacts/12346108397)
  contains the IPA and source/version/isolation/hash/app-record records, retained
  until **2026-10-28 12:39:11 UTC**. Validation artifact `12345008663` retains the
  logs and xcresult for 14 days.
- IPA SHA-256: `888f37757cd83537228018437d1bfa2a78e6da5660cddd8d17f99959cd8d3a55`.

The complete normal migration also passed **58 package + 26 backend + six native
adapter tests**, the full unsigned build, normal Xcode packaging and a real
15-second startup measurement on **iOS 18.5** in
[run 39584372756](https://github.com/jhardorp/LoopWorkspace/actions/runs/39584372756),
source `7018ca0f8766db40594a327111d386644730ffaf`. Only the separate Fastlane wrapper
changed between that source and the final candidate; runtime sources and all
upstream pins are identical. Combined coverage is **90 existing + 11 new checks**.

The separate identifier/profile uses the existing certificate. The owner explicitly
authorized the isolated app upload. The newly created empty Apple app record was
corrected from a widget-extension ID to `com.jhardorp.loopaiphototest`; a fresh
read and a repeat check confirmed the correction without changing developer
identifiers, signing or the production app record.

**Apple accepted the existing Loop AI Test 0.1.0 (4) IPA at 2026-10-21 15:42:17 UTC**
in [successful run 39627647246](https://github.com/jhardorp/LoopWorkspace/actions/runs/39627647246),
wrapper `9e1de9e42cddcc37b2d19b649e410131f0c739b5`. Hash/signature/isolation were
reverified before upload; the binary was not rebuilt. At **16:02:26 UTC**, after
20 minutes, status was still `AWAITING_APPLE_RECORD`, with `upload_accepted: true`.
**Apple processing and internal-test readiness remain unconfirmed.**
[Evidence artifact 12358982603](https://github.com/jhardorp/LoopWorkspace/actions/runs/39627647246/artifacts/12358982603)
contains effective-product and upload status JSON. External distribution was
disabled and tester groups were unchanged. No physical install, production
deployment or merge occurred. See the [full upload result](SideBySide/README.md#approved-upload-result--2026-10-21).

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
