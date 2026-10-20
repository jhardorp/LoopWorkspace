# Experimental upstream migration — validation only

No clinical use or insulin delivery from this migration until independently validated. No signing, TestFlight upload, device installation, backend deployment, or merge into production is authorized by this work.

## Reproducible source selection

- Production source: `feature/ai-food-recognition` at `cb4f6b1821489a27b06a36e378b0a7e5267bcbf1` (Loop 3.14.9, last accepted build 26).
- Initial migration documentation: `852b186a857a530db4eacea021b0d9b6c22120ad`; all new commits remain on `migration/loop4-ai-photo`.
- Upstream **LoopWorkspace next-dev**: `53253aaa774a95ea6e299cc1a2fabc4af861328c`, 2026-10-19.
- Compatible upstream **Loop** pin: `b55744981c2e589799754d19f73b8912c8809e12`.
- Workspace marketing version: **3.15.2 (58)**, minimum iOS **17.6**. “loop4” is the migration branch name, not an upstream version claim.
- The newer Loop-only head `bbede6cbe22967069703fc18a1508a5193e02c14` removes support-report UI. It is not yet pinned by this workspace. This migration uses the latest published workspace dependency combination rather than mixing independent branch tips.

`Integration/upstream-lock.json` records every gitlink. Workspace `Package.resolved` pins remote Swift dependencies; local algorithm/device packages use those gitlinks. Gemfile/lock, signing files, deployment workflows, personal plist configurator, backend, and production upload request are preserved from production. Workspace references, scheme, Swift resolution lock and version file come from the selected upstream workspace. `apply.py` rejects any other Loop source pin.

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
| Native entry | Fills editable fields; preserves entry time; does not save or advance | Preserved; native favorites observer is cancelled before transfer so queued selection cannot overwrite it |
| Long food names | Full-width multiline editor and separate summary lines | Ported to the new editor and CarbEntryChange-based summary |
| Submission | Normal Loop Continue / save flow | Entirely upstream; no automatic entry storage or bolus navigation |
| Credentials | Personal release injects tester code into signed plist | No injection or signing during validation; production setup remains unchanged |

A cancelled photo review never modifies the existing carb fields. Successful later reviews replace editable values rather than adding a carbohydrate entry. Upstream owns the stable new-entry sync identifier and all subsequent saving; this overlay does not modify it.

## Automated validation

`loop_ai_migration_validate.yml` is restricted to the migration branch, has read-only repository permissions, no secret bindings, no upload operation and no signing/archive/deploy steps. It always performs a fresh unsigned Simulator build. It runs:

1. Exact source/dependency pin and protected production-configuration verification.
2. Swift package regression tests: duplicate/reentrant handoff, cancellation, superseded presentations, native limits, locale values, refinement, confidence acknowledgement, failed/rejected transfer and retries.
3. Unchanged backend syntax and contract tests without real provider requests.
4. Full integrated iOS Simulator build with signing disabled.
5. Mock-only native adapter tests covering no save/no bolus side effects, edits, duplicate callbacks, cancellation, stale callbacks, queued favorites, unit conversion and atomic native-limit rejection.

CI build/test results are recorded below after execution. Passing CI is engineering evidence, not independent safety validation.

## Independent validation still required

- Human review of upstream changes and the adapter, especially carbohydrate quantities, units, absorption timing, notes, entry identity and normal Continue/save behavior.
- Camera/gallery first presentation, cancellation while loading/analyzing, backgrounding, retries and network failures on the intended iOS version.
- Small screens, large accessibility text, German decimal input, long/multiline food descriptions and favorites interaction.
- Confidence warnings, clarification, unsent refinement comments and confirmation must continue to prevent unintended transfer.
- Confirm no duplicate stored entries after ordinary user-driven saving. Automated adapter tests assert that transfer itself never calls storage or delivery; clinical end-to-end behavior requires independent review.

## Sharing the module

The review is an existing local Swift package (`FoodRecognitionCore` + `FoodRecognitionUI`); Loop-specific changes remain in the small pinned overlay. See [SHARING.md](Prototypes/AIFoodRecognition/Integration/SHARING.md). This prepares an integration path for other users; it does not publish a package, app, credentials or backend service.
