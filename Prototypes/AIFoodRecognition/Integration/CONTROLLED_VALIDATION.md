# Controlled validation of the experimental migration

Review: [draft PR #2](https://github.com/jhardorp/LoopWorkspace/pull/2), targeting the preserved `feature/ai-food-recognition` branch. Do not merge as part of validation. The complete source lock and comparison are in [MIGRATION_LOOP4.md](../../../MIGRATION_LOOP4.md).

## Evidence and its limits

Code commit `3ac9aed295a2fcacb34e8f71f7946fc55552d65f` passed 58 package tests, 26 backend contract tests, six native mock adapter tests and a complete unsigned Simulator build in [run 39397041333](https://github.com/jhardorp/LoopWorkspace/actions/runs/39397041333).

The Intel follow-up at `06d3503f7c8f7b749128913fffef88c09c3c4e9a` also passed all **58 + 26 + 6 tests** and the full unsigned build in [run 39472150713](https://github.com/jhardorp/LoopWorkspace/actions/runs/39472150713). Its overall result was **failure**: the new Simulator exceeded the 180-second boot limit while completing Apple's first-boot migration, before app installation. The signed archive was skipped. The preceding Arm64 startup attempt timed out during installation after 120 seconds. Neither result establishes normal app startup.

Prewarming revision `a3506e1137caf902ab110186d8a61e88d9950a1e` passed all **58 + 26 + 6 tests** and the full unsigned build in [run 39487381494](https://github.com/jhardorp/LoopWorkspace/actions/runs/39487381494). The iOS 26.4.1 Simulator booted and installed the normal app successfully, but launch was denied by `SBMainWorkspace` (`FBSOpenApplicationServiceErrorDomain` code 1). Its bundle ID was `com..loopkit.Loop`, with an empty team component. The exact launch-denial cause is not established. The archive was skipped; normal process survival remains unvalidated.

Packaging retry `b568928b09f8581e3a8f49612ddc9b8e6c421f98` passed **58 Swift tests, 26 backend tests and the complete unsigned build** in [run 39509636623](https://github.com/jhardorp/LoopWorkspace/actions/runs/39509636623). The unsigned build succeeded at **2026-10-21 00:25:25 UTC**. Xcode's subsequent ad-hoc Simulator packaging was cancelled at 00:40:08, just after the configured two-hour job budget. The log says only “The operation was canceled”; its unique cause is not established. Startup and native tests were skipped in this retry, the strict gate failed, and no archive was produced. Cleanup also timed out shutting down the owned Simulator after 30 seconds. The app/module code, native adapter tests and dependency pins are unchanged from `a3506e1`, which passed all 90 tests.

The latest CI correction gives each job 180 minutes, initializes the disposable Simulator and shuts it down before compilation, then uses that explicit destination and fixed CI-only bundle ID. Matching unsigned/ad-hoc settings reduce unnecessary differences between builds. The normal probe boots the same initialized Simulator again. Progress is printed every 45 seconds while complete build logs are retained. Cleanup attempts deletion even when shutdown times out. This limits competing Simulator work during compilation; it does not prove the earlier cancellation's cause. The revised CI tooling has not yet completed macOS validation.

After the separate required unsigned build, Xcode packages the normal app with ad-hoc Simulator signing and its own entitlement processing. No Apple signing identity, account or provisioning profile is used. The probe copies that sealed product, verifies its ad-hoc signature, and attempts installation and launch. A passing measurement requires a screenshot and 15 seconds of process survival. The app's original entry point, scene configuration and source remain intact. The copy and Simulator are deleted afterwards; cleanup checks that the device belongs to this CI source. This checks process survival at startup; it does not establish completed onboarding or photo-to-entry behavior. The unsigned build and isolated adapter tests remain separate checks, and a failed startup probe fails the workflow after preserving the adapter results. The CI-only identity/settings do not apply to the production archive job. No startup success or signed archive is claimed.

No independent clinical or safety validation has been performed. The authoring assistant's source review and automated tests cannot provide that independence.

The follow-up workflow uses the supported `macos-26-intel` runner and explicitly selects Xcode 26.3 (17C529), which is listed in the [official runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md). The macOS 15 and macOS 26 Arm64 retries were cancelled before receiving a runner; no app code or dependency pin changed for this host fallback. Both Arm64 and Intel builds/regressions have passed as recorded above. The device archive still targets iOS, independently of the Mac host architecture.

## Source review completed by the authoring assistant

- The native overlay changes only the carbohydrate view/model, display of the entry on the bolus screen, and mock tests. The protected-file verifier guards the production signing, upload, backend and distribution configuration. Exact upstream gitlinks and remote Swift package revisions remain pinned.
- The native callback consumes its presentation token before updating fields. Cancelled, superseded and repeated callbacks cannot transfer. A rejected native range leaves the token available for correction; the adapter does not clamp or silently change reviewed values.
- Grams convert through Loop's quantity type to the preferred input unit. Absorption minutes convert to seconds once. Entry time stays unchanged, and the upstream new-entry identifier survives repeated reviews and Continue/back navigation.
- The transfer clears the selected favorite without allowing a queued favorite update to replace the reviewed values. Native favorite controls and native entry warnings remain available.
- The shared review requires a user action to transfer. Low confidence also requires acknowledgement. Pending clarification, unsent comments and in-progress refinement block transfer. Analysis/refinement errors do not produce fallback estimates.
- No custom changes were made to dosing algorithms, pump/CGM communication or therapy settings. Updating the pinned upstream introduces upstream changes in those areas; independent review must include them.

## Installation route must preserve the working app

The existing `Loop meal photo review` upload workflow is restricted to the production feature branch and hardcodes its existing app identity. It must not be repurposed to ship this migration.

Choose the test setup before distributing or installing a candidate. The archive-only preparation below retains the existing identity for review and does not install anything:

| Setup | Required preparation |
|---|---|
| Spare/test iPhone | A migration-only manual workflow may reuse existing signing identities. Install only on the test phone. Keep production pump/CGM credentials and production HealthKit data out of the test setup. |
| Current iPhone alongside working Loop | Register a distinct main bundle ID, all extension IDs, app group, provisioning profiles, URL scheme and App Store Connect app record. Keep the production IDs/profiles and signing configuration unchanged. A distinct bundle ID alone does **not** isolate the shared HealthKit database. |

A candidate must build the normal app, never the generated adapter test host. Record its source SHA, all pins, Xcode version, resolved bundle IDs/app groups, version/build number and archive hash. Verify that no test-host entry point or test fixture is present. Use a separate manual, migration-only workflow; never synchronize upstream automatically or renew/revoke the production certificates as part of this test.

The validation workflow now offers a manual `prepare_signed_candidate` option (default **false**). An explicit `[archive-candidate]` marker in a migration push's head commit message requests the same archive when manual dispatch is unavailable. Ordinary pushes do not request signing. After validation passes in the same run, a separate job checks out the same source again, selects the same pinned Xcode 26.3, verifies protected configuration, applies the normal app overlay and invokes `experimental_archive/fastlane/Fastfile`. It uses existing signing with `MATCH_READONLY=true` and locked remote package versions. It does not create or renew certificates/profiles, upload to TestFlight, install on a device, merge, or deploy. The archive retains the personal tester login behavior from production. The IPA and a source/version/bundle/hash record are retained for seven days as review artifacts.

This archive option retains the production app identity and is intended for eventual testing on a **spare test device only**. It is unsuitable for side-by-side installation on the working phone. It uses the existing App Store export method; that IPA cannot be installed directly on a phone. TestFlight/device distribution is not implemented in this workflow. At preparation time there is no migration archive or TestFlight build; record the actual archive result before claiming one exists. A test build must stay experimental until independent validation is recorded.

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
