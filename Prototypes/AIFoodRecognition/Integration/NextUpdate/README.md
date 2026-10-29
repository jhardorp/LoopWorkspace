# Prepare the next normal-identity candidate

The `prepare_candidate` operation in `loop_ai_live_update.yml` archives a candidate using the existing normal Loop bundle, App Group, Apple app and read-only signing. It never uploads to TestFlight, installs an app, deploys the Worker or changes the production branch.

The operation requires the exact source SHA and run ID of a successful migration validation. Its guard checks the Swift, backend, settings/history, unsigned Simulator build, normal startup and native adapter steps. Only this packaging directory, its workflow and Markdown may differ from that validated source. Application, dependencies, tests and validation automation must match.

The existing Apple history must still end at build 27. The archive is verified as 3.15.2 (28), with the original application and companion identities, signed entitlements, provisioning App Group and normal entry point. Changed Apple history or missing existing signing fails the job; it does not renew or create certificates or profiles.

The retained artifact contains `Loop.ipa`, `NextCandidate.json` and the validation proof. It contains the personal tester login and must remain private. A separately authorized publication must use that exact IPA and verify its hash and provenance. The artifact is retained for seven days. Engineering checks do not establish clinical safety or replace independent validation.

Guard unit tests: `python3 Prototypes/AIFoodRecognition/Integration/NextUpdate/verify_validation_test.py`.
