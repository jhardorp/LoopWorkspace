# Text meal input and October 28 upstream update

Status: implemented and engineering validation passed on `migration/loop4-ai-photo`; **not released**. Signed-package preparation and publication remain separate. This document does not authorize a deployment or replace independent clinical validation.

The carbohydrate editor now offers **Photograph meal**, **Choose photo** and **Describe meal**. For example, a user can submit “one tablespoon of honey” without supplying an image. The same AI review permits editing carbohydrate grams, absorption minutes and meal notes, displays uncertainty, supports follow-up corrections, and requires explicit reviewed confirmation before returning values to the native editor. The handoff never saves an entry, navigates to a bolus, or delivers insulin.

`POST /v1/describe` accepts only a bounded current description and optional validated refinement context. It uses the existing short-lived authentication, shared transactional request quota, bounded provider response, strict low-confidence response schema, and no-retry policy. No synthetic image, treatment history or device settings are sent. The existing JPEG and refinement endpoints remain compatible with installed clients. The updated backend must be published before the new description button is usable against the personal service. A backend dry run is not a deployment.

New regression coverage checks description validation and UTF-8 limits, text-only HTTP payloads and authentication, editable/manual values, confirmation, once-only delivery, cancellation, stale text results superseded by a photo, corrections and clarification without fallback numbers, shared photo/text quota, and the native text-to-editor handoff. Synthetic numerical fixtures are test data, not validated nutrition values.

Upstream is pinned to LoopWorkspace `97b2cfc197caddc6b9e10d50e01e81ef4171fbfe` (October 28, 2026), Loop `6441cb4e454fb9defadfd643df4dbb86fa6af54b`, LoopKit `b6db6e18bc75b782d5dc20f3a434d59e25e383f9`, and the workspace's full matching set of 24 gitlinks. SwiftPM resolution and the one-line JSON gem security update come from that workspace. The Loop standalone `next-dev` head `3c4f8b0e3cbd1bb37f4b4fde0d0795051b78f7e6` contains a later test-timing change; the workspace's coherent pinned set is used rather than independently moving its dependencies. The marketed version remains **3.15.2**, on the Loop 4 development line.

Compared with the installed October 19 baseline (workspace `53253aaa774a95ea6e299cc1a2fabc4af861328c`, build 27), this brings upstream Current Setup/results, display options, daily insulin statistics, alarm sound improvements, device reliability changes and opt-in algorithm experiments. These are upstream changes; the custom overlay remains restricted to the native carbohydrate-input UI/model, food-description formatting on the bolus screen, and guarded tests. No custom dosing, pump, CGM or therapy-setting edits are included. New upstream experiments must retain their upstream defaults; no existing therapy configuration is reset or copied from the isolated test app.

The normal bundle ID, App Group, production signing configuration, installed app and production branch are preserved while validation runs. The historical build-27 uploader is source-specific and is not reused for changed code. The separate test app remains separate. A new candidate needs its own signed-package identity and source checks before any authorized TestFlight publication.

## Verification on October 29

[Validation run 40886501697](https://github.com/jhardorp/LoopWorkspace/actions/runs/40886501697) passed for source `23c4cc427d09bc1f489b81b533e1bdf9c93634e0` on macOS with Xcode 26.3. All required checks completed: 66 Swift review tests, 32 backend tests including the Cloudflare runtime, four settings/history migration tests, seven native adapter tests, the full unsigned iOS Simulator build, ad-hoc Simulator packaging, normal application startup and cleanup. No paid OpenAI request is needed for these tests.

The preceding run passed the same 109 regression cases and build but stopped before launch because the startup helper still hard-coded the October 19 Loop pin. The helper now verifies the committed gitlink and initialized checkout against `upstream-lock.json`; the successful fresh run includes that correction.

Protected signing, production workflows, deployment configuration and production branch remain unchanged. The backend's new `/v1/describe` endpoint is not yet published. Existing build 27's earlier success is historical evidence and is not substituted for this validation.

## Signed candidate, not uploaded

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
| Upload / device install / backend deployment | **None** |

The first archive request never acquired a hosted arm64 runner and was cancelled by GitHub after capacity retries. The successful Intel request used the same Xcode build and unchanged application source. This was a runner allocation failure, not a compiler or signing failure.

The new endpoint must be released to the existing Worker before the new input can work in the phone app. Public health currently confirms the old photo/refinement service is ready with the existing 1,000/day and 60/minute limits. The release remains experimental; engineering tests and packaging checks do not establish clinical safety, actual-device data migration or real text-analysis accuracy. The owner's migration requirement 9 requires explicit approval before a TestFlight upload or backend deployment. [NextUpdate](NextUpdate/README.md) documents the exact candidate preparation and read-only backend comparison.

[Backend preflight 40962608601](https://github.com/jhardorp/LoopWorkspace/actions/runs/40962608601) passed all 32 backend tests, the Wrangler bundle dry run and read-only checks of the existing Cloudflare account, Worker, quota namespace, model, limits, secret names and public health. Artifact **12936348558** records the exact previous deployment and bundle hash. The prepared publication operation is manual only and requires owner confirmation; it publishes the compatible backend first and uploads only the original signed build 28 after service readiness. It has not been dispatched.

## Publication readiness on October 30

[Final read-only preflight 41079998020](https://github.com/jhardorp/LoopWorkspace/actions/runs/41079998020) passed for release-control source `861072107b0acd1778b3ac217a3c87fcdb76e3a9`. It reran the 32 backend tests and dry run, passed all eight validation/artifact guard regressions, checked the archive/upload Ruby syntax, and verified the successful original validation/archive/backend runs and exact retained artifact metadata. The current bundle hash and existing Worker deployment/configuration still match the saved backend baseline. Application/test sources and protected production refs remain unchanged. Publication jobs were **skipped**, as required without owner authorization. No new license, signing grant or credential is required by the completed checks.

Ready for the owner's explicit publication approval: the exact **3.15.2 (28)** IPA and compatible text endpoint on the existing Worker. Phone installation remains a separate manual action. Independent safety validation remains unresolved; the candidate remains experimental.
