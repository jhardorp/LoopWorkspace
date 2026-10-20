# Experimental upstream migration — validation only

No clinical use or insulin delivery from this migration until independently validated. Engineering preparation includes an opt-in, validation-gated archive using existing read-only signing. TestFlight upload, device installation, backend deployment and merge into production remain outside this work.

## Reproducible source selection

- Production source: `feature/ai-food-recognition` at `cb4f6b1821489a27b06a36e378b0a7e5267bcbf1` (Loop 3.14.9, last accepted build 26).
- Initial migration documentation: `852b186a857a530db4eacea021b0d9b6c22120ad`; all new commits remain on `migration/loop4-ai-photo`.
- Upstream **LoopWorkspace next-dev**: `53253aaa774a95ea6e299cc1a2fabc4af861328c`, 2026-10-19.
- Compatible upstream **Loop** pin: `b55744981c2e589799754d19f73b8912c8809e12`.
- Workspace marketing version: **3.15.2 (58)**, minimum iOS **17.6**. “loop4” is the migration branch name, not an upstream version claim.
- The newer Loop-only head `bbede6cbe22967069703fc18a1508a5193e02c14` removes support-report UI. It is not yet pinned by this workspace. This migration uses the latest published workspace dependency combination rather than mixing independent branch tips.

`Integration/upstream-lock.json` records every gitlink. Workspace `Package.resolved` pins remote Swift dependencies; local algorithm/device packages use those gitlinks. Xcode is restricted to remote package versions in the resolved file. Gemfile/lock, signing files, deployment workflows, personal plist configurator, backend, and production upload request are preserved from production. Workspace references, scheme, Swift resolution lock and version file come from the selected upstream workspace. `apply.py` rejects any other Loop source pin.

| Dependency | Production pin | Migration pin |
|---|---|---|
| AmplitudeService | `f786858870fde95ea558f766e94be790ef4c903b` | `5451d96d7fd9d9c34f0277b4bd0b51afa04408b7` |
| CGMBLEKit | `ea224e771fb3329a957a753296232c62a003a9fe` | `7fb23093b459880eebd7cd657be7d97a7e188bd4` |
| EversenseKit | `e1bb6faf01bb4bd79872ae6d12787aea8bfe2ad5` | `fb23eef40ebe2bf5e59bfe27416567446b9b6d2c` |
| G7SensorKit | `dd91f465b8b7392354b74463b9b9cc7aae32db9f` | `e17129d05fb9d8c05626f63f1bebf59d39c67711` |
| LibreLoop | `not present` | `8c40f53d70ea686cce9374e083c7550328b7f48b` |
| LibreTransmitter | `41105123c3c4fb5c55ce89a38630cea2f8f7a17a` | `dde20cd6b4f3c3537fc1fbeeacde45dc8411a778` |
| LogglyService | `d5f93ff356e8df247107bdd7456adab44ec343e9` | `02ec0cc310d3c229cc4372edee5e8112dc0f33e9` |
| Loop | `c30b5c89b1dc4151628f33f1384dd4796eaeeec2` | `b55744981c2e589799754d19f73b8912c8809e12` |
| LoopAlgorithm | `not present` | `7ef67243adb0445f5138083c30908a4745eafc83` |
| LoopKit | `d9f1437353482690426bd981536f58c1e95ff535` | `031c16f574efaf73255b398d48479b19cd8d45b0` |
| LoopOnboarding | `1ac6b2fe4fb6413febab3327b0cb2c7a05403759` | `c7a0b9270e733ddb8d085ad41f2ce0683d113195` |
| LoopSupport | `21957dfec01d401edf8c7f9574a2975b60e7592b` | `63fa9f8de0974ca241c43dc4ae9870424a6b181b` |
| MedtrumKit | `ef866fa68db22932271af9bce86372ced8604203` | `f01a84de5a55d2a65cb0a59611aff1c56c7ee647` |
| MinimedKit | `a7b26858e3073ac8881e7303b675c6b0f8c51ee9` | `6f8207e14baeb930d1c1a842558fc5d03c832d9a` |
| Minizip | `66483b42479a86d095ec642b2f6819e1abbe30d3` | `66483b42479a86d095ec642b2f6819e1abbe30d3` |
| MixpanelService | `b33debdac37d6ef3be955eebb0c42495a1f19232` | `8e9efe277a79eee022dfd3d7af80982266b8b919` |
| NightscoutRemoteCGM | `45b4efd3ffee943832dbeb608b4cb4baeb53fb12` | `4cb3e6d2897908c51bc8ab89160ce8efe9a7b045` |
| NightscoutService | `2cef4896f0704fb112575ab34b596ee7de78e48d` | `25115e9490eec5c2b774ebf40115256d6d6ec68e` |
| OmnipodKit | `043b91dbf1958d26c55d927a6a8d651bc91f208d` | `c21a0774fb59f54d2adc0db6f58b37ab9f339b32` |
| RileyLinkKit | `049f0d51b2fb90fa5180f3f62555d8c661b55968` | `777e7efc0b0b16a59bf5cec7ba49d02ea7e9120a` |
| RoundWhiteDiscKit | `not present` | `e66da6cc34680fecbbb87812279163dcc1a842b4` |
| TidepoolService | `99ac3544f8462973f6ea886d1a46c2954ad0cc0f` | `46171f37bfdcafc4600fb2af19e0f2a1bfa6ce1e` |
| TrueTime.swift | `5dc1285f3ea85fed3d132fb226c969d6a06b1208` | `5dc1285f3ea85fed3d132fb226c969d6a06b1208` |
| dexcom-share-client-swift | `ff0d71433447af3c93dac450d95c14b63f58f417` | `506df57f2c1107c85ca841e6fdba6f27da54c25f` |

## Customization boundary

Only the native carbohydrate editor, its reviewed-value adapter, the carbohydrate description layout in the bolus summary, and mock-based adapter tests receive an overlay. There are **no custom changes** to insulin dosing algorithms, bolus recommendations, pump commands, CGM communication, therapy settings, or storage/delivery methods.

Upgrading upstream necessarily incorporates upstream changes to those components and introduces the upstream LoopAlgorithm package. This migration does **not** establish that the new upstream behavior is equivalent to 3.14.9. Independent validation must cover the entire new upstream baseline, in addition to this photo adapter. It must not be used for clinical decisions based on passing software tests.

## Comparison with production

| Behavior | Existing implementation | Experimental migration |
|---|---|---|
| Entry quantities | HealthKit-era types | Upstream LoopQuantity / gram conversion |
| Camera and gallery | Item-driven choice; fixed first-tap gallery routing | Preserved, with a unique presentation ID |
| AI analysis / backend | JPEG analysis and comment refinement | Same protocol, provider settings and backend source |
| Review | Editable grams, absorption minutes, notes; confidence warnings and explicit Use in Loop | Same shared UI and confirmation; native limits also checked |
| Handoff | Review session prevents repeated completion | Session protection plus host presentation token prevents duplicate, cancelled and stale callbacks |
| Native entry | Fills editable fields; preserves entry time; does not save or advance | Preserved; native favorites observer is cancelled before transfer so queued selection cannot overwrite it; upstream favorite chips/clear actions remain available |
| Long food names | Full-width multiline editor and separate summary lines | Ported to the new editor and CarbEntryChange-based summary |
| Submission | Normal Loop Continue / save flow | Entirely upstream; no automatic entry storage or bolus navigation |
| Credentials | Personal release injects tester code into signed plist | No injection during unsigned validation; the opt-in archive reuses the unchanged personal configurator. Production setup remains unchanged |

A cancelled photo review never modifies the existing carb fields. Successful later reviews replace editable values rather than adding a carbohydrate entry. Upstream owns the stable new-entry sync identifier and all subsequent saving; this overlay does not modify it.

## Automated validation

`loop_ai_migration_validate.yml` is restricted to the migration branch and has read-only repository permissions. Its validation job has no secret bindings and always performs a fresh unsigned Simulator build. The separate, opt-in archive job described below uses existing signing only after validation passes. Neither job uploads to TestFlight, installs on a device or deploys. Validation runs:

1. Exact source/dependency pin and protected production-configuration verification.
2. Swift package regression tests: duplicate/reentrant handoff, cancellation, superseded presentations, native limits, locale values, refinement, confidence acknowledgement, failed/rejected transfer and retries.
3. Unchanged backend syntax and contract tests without real provider requests.
4. Full integrated iOS Simulator build with signing disabled.
5. A normal-app startup probe using an ad-hoc signed disposable copy on a fresh Simulator, measuring installation, launch and 15 seconds of process survival. This is separate from the unsigned build and does not use an Apple signing identity.
6. Mock-only native adapter tests in a minimal unsigned Simulator host covering no save/no bolus side effects, edits, duplicate callbacks, cancellation, stale callbacks, queued favorites, unit conversion atomic native-limit rejection, and one stable new-entry sync identifier across repeated reviews/Continue.

The full real application is built **before** test-host preparation. Only in the ephemeral migration CI checkout, `prepare_test_host.rb` then replaces main.swift and removes the scene manifest to prevent starting LoopAppManager/Siri/device services without entitlements. It does not change the committed application overlay, production startup, signing configuration, or algorithms. The test fixture lives in the host and the test bundle does not separately link the package, avoiding duplicate class definitions. A second incremental host build and native tests follow. These adapter tests do not validate full application startup or camera/gallery UI end to end.

### Recorded results — 2026-10-20

Validated code commit: **`3ac9aed295a2fcacb34e8f71f7946fc55552d65f`**.
[Successful validation run 39397041333](https://github.com/jhardorp/LoopWorkspace/actions/runs/39397041333), job `118542215216`.
Toolchain: **Xcode 26.3 (17C529)** on macos-15. Local package tests also passed in Swift 6.0.3 on Linux.

| Check | Result |
|---|---|
| Exact workspace/dependency pins and protected production configuration | PASS |
| Swift package tests | **58 passed**, 0 failures (54 existing + 4 new handoff regressions) |
| Unchanged backend syntax/contract tests | **26 passed**, 0 failures; no deployment or paid model calls |
| Full normal LoopWorkspace iOS Simulator build, signing disabled | **BUILD SUCCEEDED** at 09:15:10 UTC |
| Isolated native adapter tests | **6 passed**, 0 failures; **TEST SUCCEEDED** at 09:25:13 UTC |
| Duplicate Core package class definitions in final native run | None reported |
| Artifact retention | Build/host/test logs and xcresult retained in the linked run for 14 days |
| Production feature branch | Still `cb4f6b1821489a27b06a36e378b0a7e5267bcbf1` |
| Main branch | Still `548b33245198eaae165c094c9c68fe333cb69c05` |

The native cases verify cancellation/stale presentation, duplicate callback rejection, atomic native-limit rejection/retry, queued-favorite protection, repeated review/Continue preserving one new-entry identifier, and edited values without storage or delivery side effects. The original tests remain in place.

Earlier attempts exposed an async XCTest fixture assertion error and unsigned full-app startup's Siri entitlement requirement. The assertions were corrected, and the final native run uses the minimal host described above, without linking a second Core package copy into the test bundle. The final run passed without changing normal application startup or signing.

The original passing run predates the following test-fixture guards and startup/archive tooling; their results are recorded separately. Passing CI is engineering evidence, not independent safety validation.

### Follow-up validation and controlled archive preparation

Draft review: [PR #2](https://github.com/jhardorp/LoopWorkspace/pull/2). The independent/manual acceptance record and installation routes are in [CONTROLLED_VALIDATION.md](Prototypes/AIFoodRecognition/Integration/CONTROLLED_VALIDATION.md).

Follow-up code `212c3a2284431010b9316f9bff8c8c991f9b9e61` passed **58 Swift tests, 26 backend tests, all six native adapter cases and the complete unsigned Simulator build** in [run 39452304422](https://github.com/jhardorp/LoopWorkspace/actions/runs/39452304422). The overall run **failed**: the new normal-startup probe timed out installing its disposable Simulator app after 120 seconds, before launch. The final gate correctly prevented the signed archive. An intermediate successful-looking step was masked by `continue-on-error`; it was not a successful startup measurement.

The probe/workflow fixes give installation up to ten minutes, record the failing phase and installer diagnostics, and display probe failures explicitly while still running the adapter tests. Host-dependent tests now compile only when the generated fixture is enabled in ephemeral CI; ordinary LoopTests builds do not reference that fixture. CI also requires six actual passing adapter cases, preventing an empty test run from succeeding.

The macOS 15 retry `2bfc39e1062057680faf8ab62b692c300854a504` and macOS 26 Arm64 retry [39468430927](https://github.com/jhardorp/LoopWorkspace/actions/runs/39468430927) were cancelled before receiving runners. The supported Intel-host retry [39472150713](https://github.com/jhardorp/LoopWorkspace/actions/runs/39472150713), source `06d3503f7c8f7b749128913fffef88c09c3c4e9a`, completed with the **same Xcode 26.3 (17C529)**, app/module code and dependency pins:

| Intel follow-up check | Result |
|---|---|
| Swift package tests | **58 passed**, 0 failures |
| Unchanged backend contract tests | **26 passed**, 0 failures |
| Full normal unsigned Simulator build | **BUILD SUCCEEDED**, 18:47:42 UTC |
| Native adapter cases, including duplicate/cancellation and stable entry identity | **6 passed**, 0 failures; **TEST SUCCEEDED**, 19:24:24 UTC |
| Normal-startup probe | **FAILED before app installation**: `simctl bootstatus` exceeded 180 seconds during Apple's first-boot data migration/system-app startup |
| Overall workflow / signed archive | **FAILED / SKIPPED**; no app launch was measured and no signed IPA was produced |

The next CI-only fix starts the disposable Simulator before compilation, using the native test destination's runtime/device type, and allows a bounded ten-minute boot-readiness wait. This gives Apple's first-boot migration time to finish while the app builds. Source/owned-device checks guard preparation and cleanup. Installation, launch, 15-second process survival and the strict archive gate remain required; no app, algorithm or dependency code changes. Syntax and mock ownership/runtime-selection checks passed locally; an actual macOS retry is still required before claiming startup success.

An opt-in archive job is now prepared. It uses a fresh checkout of the validated source, the unchanged existing app identity, read-only provisioning and locked remote package versions. It retains an IPA and source/version/bundle/hash provenance for review, and has no TestFlight upload, installation or deployment step. This route is for a spare test device; side-by-side installation on the working phone requires distinct app/extension IDs, app group, URL scheme and profiles. A different bundle ID alone does not isolate HealthKit data. No signed migration IPA has been produced as of this record.

## Unresolved limitations and independent validation still required

The recorded Arm64 and Intel runs have no unresolved compiler errors or failing regression tests. The added normal-startup probe remains unresolved: the earlier Arm64 attempt timed out during installation, and the Intel attempt timed out booting a new Simulator. Neither measured an app launch. Live camera/gallery interactions, real provider responses and clinical behavior have **not** been validated by the mock adapter tests. The native test class requires the workflow's generated host fixture; run it through the migration validation workflow, rather than the normal unprepared LoopTests scheme. Production signing/backend configuration was preserved, and no physical app, TestFlight release or deployment was changed.

The following checks remain:

- Human review of upstream changes and the adapter, especially carbohydrate quantities, units, absorption timing, notes, entry identity and normal Continue/save behavior.
- Upgrade of existing production data has not been tested. A fresh Simulator launch does not validate migration of an existing installation's stores or settings.
- Camera/gallery first presentation, cancellation while loading/analyzing, backgrounding, retries and network failures on the intended iOS version.
- Small screens, large accessibility text, German decimal input, long/multiline food descriptions and favorites interaction.
- Confidence warnings, clarification, unsent refinement comments and confirmation must continue to prevent unintended transfer.
- Confirm no duplicate stored entries after ordinary user-driven saving. Automated adapter tests assert that transfer itself never calls storage or delivery; clinical end-to-end behavior requires independent review.

## Sharing the module

The review is an existing local Swift package (`FoodRecognitionCore` + `FoodRecognitionUI`); Loop-specific changes remain in the small pinned overlay. See [SHARING.md](Prototypes/AIFoodRecognition/Integration/SHARING.md). This prepares an integration path for other users; it does not publish a package, app, credentials or backend service.
