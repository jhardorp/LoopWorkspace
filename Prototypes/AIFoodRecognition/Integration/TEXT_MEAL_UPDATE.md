# Text meal input and October 28 upstream update

Status: **published** after explicit owner approval. [Release 41140797382](https://github.com/jhardorp/LoopWorkspace/actions/runs/41140797382) succeeded: the text-analysis backend is live and the original signed **Loop 3.15.2 (28)** is **VALID / IN_BETA_TESTING** in the existing Apple app. Phone installation is manual. Independent safety validation remains pending; the release remains experimental.

The carbohydrate editor now offers **Photograph meal**, **Choose photo** and **Describe meal**. For example, a user can submit “one tablespoon of honey” without supplying an image. The same AI review permits editing carbohydrate grams, absorption minutes and meal notes, displays uncertainty, supports follow-up corrections, and requires explicit reviewed confirmation before returning values to the native editor. The handoff never saves an entry, navigates to a bolus, or delivers insulin.

`POST /v1/describe` accepts only a bounded current description and optional validated refinement context. It uses the existing short-lived authentication, shared transactional request quota, bounded provider response, strict low-confidence response schema, and no-retry policy. No synthetic image, treatment history or device settings are sent. The existing JPEG and refinement endpoints remain compatible with installed clients. The text endpoint is now published on the personal service; using it in Loop requires updating to build 28.

New regression coverage checks description validation and UTF-8 limits, text-only HTTP payloads and authentication, editable/manual values, confirmation, once-only delivery, cancellation, stale text results superseded by a photo, corrections and clarification without fallback numbers, shared photo/text quota, and the native text-to-editor handoff. Synthetic numerical fixtures are test data, not validated nutrition values.

Upstream is pinned to LoopWorkspace `97b2cfc197caddc6b9e10d50e01e81ef4171fbfe` (October 28, 2026), Loop `6441cb4e454fb9defadfd643df4dbb86fa6af54b`, LoopKit `b6db6e18bc75b782d5dc20f3a434d59e25e383f9`, and the workspace's full matching set of 24 gitlinks. SwiftPM resolution and the one-line JSON gem security update come from that workspace. The Loop standalone `next-dev` head `3c4f8b0e3cbd1bb37f4b4fde0d0795051b78f7e6` contains a later test-timing change; the workspace's coherent pinned set is used rather than independently moving its dependencies. The marketed version remains **3.15.2**, on the Loop 4 development line.

Compared with the installed October 19 baseline (workspace `53253aaa774a95ea6e299cc1a2fabc4af861328c`, build 27), this brings upstream Current Setup/results, display options, daily insulin statistics, alarm sound improvements, device reliability changes and opt-in algorithm experiments. These are upstream changes; the custom overlay remains restricted to the native carbohydrate-input UI/model, food-description formatting on the bolus screen, and guarded tests. No custom dosing, pump, CGM or therapy-setting edits are included. New upstream experiments must retain their upstream defaults; no existing therapy configuration is reset or copied from the isolated test app.

The normal bundle ID, App Group, production signing configuration, installed app and production branch are preserved while validation runs. The historical build-27 uploader is source-specific and is not reused for changed code. The separate test app remains separate. A new candidate needs its own signed-package identity and source checks before any authorized TestFlight publication.

## Verification on October 29

[Validation run 40886501697](https://github.com/jhardorp/LoopWorkspace/actions/runs/40886501697) passed for source `23c4cc427d09bc1f489b81b533e1bdf9c93634e0` on macOS with Xcode 26.3. All required checks completed: 66 Swift review tests, 32 backend tests including the Cloudflare runtime, four settings/history migration tests, seven native adapter tests, the full unsigned iOS Simulator build, ad-hoc Simulator packaging, normal application startup and cleanup. No paid OpenAI request is needed for these tests.

The preceding run passed the same 109 regression cases and build but stopped before launch because the startup helper still hard-coded the October 19 Loop pin. The helper now verifies the committed gitlink and initialized checkout against `upstream-lock.json`; the successful fresh run includes that correction.

Protected signing, production workflows, deployment configuration and production branch remain unchanged. Existing build 27's earlier success is historical evidence and is not substituted for this validation.

## Signed build 28

[Archive run 40937665799](https://github.com/jhardorp/LoopWorkspace/actions/runs/40937665799) succeeded on the standard Intel macOS 15 image using exactly **Xcode 26.3 (17C529)** and existing read-only signing. Source `562919d74ff3b2ab1222e8c8ebc9e61c720ff01a` differs from the validated application only in guarded release automation and documentation. The package verifier checked the normal app identity, App Group, signed entitlements, provisioning identity, HealthKit entitlement, normal startup metadata, personal AI login and the three companion identities. No certificate, profile or identifier was created or renewed.

| Candidate | Verified value |
|---|---|
| Version / build | **3.15.2 (28)** |
| Application | `com.279LYMG57A.loopkit.Loop` |
| App Group | `group.com.279LYMG57A.loopkit.LoopGroup` |
| Minimum iOS | 17.6 |
| Companions | Original intent extension, widget extension and watch app; version/build match |
| IPA SHA-256 | `43465f88c4758bc36fc37982fa5ed79520ccb9071fd71fae98d24a3f19009986` |
| Artifact | [12928092541](https://github.com/jhardorp/LoopWorkspace/actions/runs/40937665799/artifacts/12928092541); retained until November 5, 2026 |
| Publication / device installation | Backend published; build 28 VALID / IN_BETA_TESTING; no automated phone installation |

The first archive request never acquired a hosted arm64 runner and was cancelled by GitHub after capacity retries. The successful Intel request used the same Xcode build and unchanged application source. This was a runner allocation failure, not a compiler or signing failure.

The existing Worker now advertises the text-description feature and retains photo/refinement compatibility with the same 1,000/day and 60/minute limits. The release remains experimental; engineering tests and packaging checks do not establish clinical safety, actual-device data migration or real text-analysis accuracy. The owner's explicit approval satisfied migration requirement 9 before publication began. [NextUpdate](NextUpdate/README.md) documents the exact candidate preparation and backend comparison.

[Backend preflight 40962608601](https://github.com/jhardorp/LoopWorkspace/actions/runs/40962608601) passed all 32 backend tests, the Wrangler bundle dry run and read-only checks of the existing Cloudflare account, Worker, quota namespace, model, limits, secret names and public health. Artifact **12936348558** records the exact previous deployment and bundle hash. The manual publication operation was subsequently dispatched after explicit owner confirmation; it published the compatible backend first and verified service readiness before starting the original signed build 28 upload.

## Publication readiness on October 30

[Final read-only preflight 41079998020](https://github.com/jhardorp/LoopWorkspace/actions/runs/41079998020) passed for release-control source `861072107b0acd1778b3ac217a3c87fcdb76e3a9`. It reran the 32 backend tests and dry run, passed all eight validation/artifact guard regressions, checked the archive/upload Ruby syntax, and verified the successful original validation/archive/backend runs and exact retained artifact metadata. The current bundle hash and existing Worker deployment/configuration still match the saved backend baseline. Application/test sources and protected production refs remain unchanged. Publication jobs were **skipped**, as required without owner authorization. No new license, signing grant or credential is required by the completed checks.

The owner then explicitly approved publishing the exact **3.15.2 (28)** IPA and compatible text endpoint on the existing Worker. Phone installation remains a separate manual action. Independent safety validation remains unresolved; the release remains experimental.

## Approved publication on October 30

[Release run 41140797382](https://github.com/jhardorp/LoopWorkspace/actions/runs/41140797382) uses release-control source `08965763d0db7bb5471e64ab46698b5619192dce` and the original signed IPA above. Backend job **124354282837** passed all 32 backend cases, verified the saved deployment/bundle evidence, published Worker version **`5f8b2121-082c-4d89-9d0a-0245e37d8d25`**, and verified description-service health with the original secrets, model, limits and shared quota namespace retained. Publication evidence is artifact **13018633225**. No paid provider request was made by these checks.

The normal app's signature, identity, hash and unchanged application/test sources passed verification before upload job **124354440476** began Apple publication. Apple accepted the binary at **2026-10-30 22:57:45 UTC**, completed processing, and returned **VALID / READY_FOR_BETA_TESTING** with export compliance satisfied at **23:06:56 UTC**. The complete upload job and release run succeeded. Apple build ID: **`9b8c548a-17b7-40d0-875e-a49c2ca93df8`**. Upload evidence is artifact **13019616320**, retained until November 13.

The read-only existing-app status job **124476956761**, rerun in [metadata run 39746718005](https://github.com/jhardorp/LoopWorkspace/actions/runs/39746718005), confirmed **3.15.2 (28), VALID / IN_BETA_TESTING** at **2026-10-31 07:27:06 UTC** in Apple app **6737123014**. The metadata job reads current Apple records; it is not substituted for the new application's validation. No tester groups/memberships or external distribution were changed. Production/main were not merged, no identifier/profile was created, and no automated device installation occurred.

## Installation and remaining validation

In the existing **Loop** TestFlight entry, select **Update** for **3.15.2 (28)**. In Loop, open **Add Carbs → Describe meal**, enter a food and quantity, and choose **Analyze description**. Edit the returned values/notes, review the confidence warning and confirm **Use in Loop** to fill the native editor. The normal Loop confirmation/save flow still follows.

All 109 application/backend/migration regressions, the unsigned Simulator build and normal startup passed before publication; all eight publication-control cases and the final preflight passed as well. The exact previously signed IPA was uploaded without rebuilding or re-signing. Remaining issues are independent safety validation, actual-device upgrade verification and live estimate accuracy; automated engineering checks do not establish these. The installed phone app and data have not been inspected or changed remotely.
