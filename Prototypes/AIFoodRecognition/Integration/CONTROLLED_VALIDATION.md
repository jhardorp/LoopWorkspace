# Controlled validation of the experimental migration

Review: [draft PR #2](https://github.com/jhardorp/LoopWorkspace/pull/2), targeting the preserved `feature/ai-food-recognition` branch. Do not merge as part of validation. The complete source lock and comparison are in [MIGRATION_LOOP4.md](../../../MIGRATION_LOOP4.md).

## Evidence and its limits

Latest validated source: **`e768ff50dc335671f479543ccd5f3a525c733c20`**. The validation job in [run 39565198453](https://github.com/jhardorp/LoopWorkspace/actions/runs/39565198453) **passed** on macos-15 with **Xcode 26.3 (17C529)** on 2026-10-21:

- **58 Swift package tests, 26 unchanged backend tests and six native adapter tests passed**: 90 total, zero failures.
- The complete integrated normal app built with signing disabled at **08:16:05 UTC**. Separate Xcode ad-hoc Simulator packaging passed at **08:19:21 UTC**.
- The normal app installed, launched and stayed running for **15 seconds on iOS 18.5**, with a screenshot retained, at **08:22:59 UTC**. This used the real application entry point before generating the isolated native test host.
- The six native tests passed at **08:35:34 UTC**. The explicit six-case check, strict normal-startup gate and owned-Simulator cleanup also passed.
- Build/test logs, startup screenshot and xcresult are in artifact `12332041068`, retained for 14 days.
- The separate signed archive job **passed**, exporting the signed App Store IPA at **08:59:17 UTC** using existing read-only signing. The whole workflow succeeded. [Candidate artifact 12332699181](https://github.com/jhardorp/LoopWorkspace/actions/runs/39565198453/artifacts/12332699181) contains `Loop.ipa` and its `MigrationCandidate.json` provenance; it expires **2026-10-28 08:59:21 UTC**. CI set the build counter to **27** in the temporary archive checkout. Consult the provenance for the actual IPA metadata and SHA-256.

The probe uses a fixed CI-only bundle ID and Xcode ad-hoc Simulator signing with no Apple account, certificate or provisioning profile. Generic Simulator SDK builds run before creating the disposable Simulator. The app's original entry point and scene configuration remain intact. The temporary app copy and owned Simulator are deleted. The archive uses a fresh checkout of the validated source and the existing production signing identity; it does not inherit the Simulator identity or generated test host.

This establishes normal process survival at startup. It does **not** establish completed onboarding, live camera/gallery or provider behavior, actual persisted-entry counts, migration of existing stores, physical-device behavior or clinical safety. The mock adapter tests separately cover editable values, atomic native bounds, cancelled/stale/duplicate callbacks, queued favorites and stable new-entry identity without storage or delivery side effects.

Earlier validation runs, their failures and fixes are recorded in [MIGRATION_LOOP4.md](../../../MIGRATION_LOOP4.md). They include successful builds/regressions on Arm64 and Intel hosts and unsuccessful Simulator boot, installation, launch, packaging and preflight attempts. The latest complete validation supersedes those startup failures; it does not prove a unique cause for each earlier infrastructure failure.

**No independent clinical or safety validation has been performed.** The authoring assistant's source review and automated tests cannot provide that independence. The manual acceptance record below remains PENDING.

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
