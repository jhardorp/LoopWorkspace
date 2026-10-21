# Loop Next AI — full main-app experimental candidate

The owner selected a separate installation on the current iPhone after reporting
the isolated AI test app works. This variant preserves the normal AppDelegate,
native carbohydrate editor, bolus interface and upstream main-app code. It does
not use the AI sandbox entry point or memory-ledger destination. The main app
includes the reviewed AI module; optional watch/widget/intent companions are
omitted from the first experimental package, leaving the working app's companions
untouched.

- Test-only bundle/app record: `com.jhardorp.loopaiphototest`, reusing the installed
  AI test slot, never the production Loop identity.
- Display name planned: **Loop Next AI**, with the separate orange TEST icon.
- Own group: `group.com.jhardorp.loopaiphototest`.
- Own URL: `loop-next-ai`.
- Exact upstream source stays pinned; it reports **3.15.2 next-dev**, not a
  released 4.0. No dosing, pump/CGM or therapy-setting source is modified.

Fresh native onboarding and this new group must not import working Loop settings
or device credentials. **HealthKit is an OS-wide store, not a private app group.**
The first current-phone checks must leave Health permissions and real pump/CGM
connections off. This remains an experimental candidate and requires independent
full-app/device/data validation before therapy.

The `prepare_identifier` lane reads the production capability reference, enables
only the required capabilities on the existing test ID, and never copies a
production app-group association. It inspects public app-group API availability
without private portal endpoints. It does not sign, upload, issue/revoke any
certificate or alter a production identifier/profile. Website setup is recorded
if the API does not expose app groups. An unsigned full-package build and startup
check must precede the separately identified signed archive.

On 2026-10-21, setup run [39649825892](https://github.com/jhardorp/LoopWorkspace/actions/runs/39649825892)
enabled the test ID's App Groups, HealthKit, push, Siri and NFC capabilities.
Production was read only. Apple's public `/v1/appGroups` endpoint returned 404
(`NOT_FOUND`, undefined resource type), so the owner must register
`group.com.jhardorp.loopaiphototest` in Developer Portal and associate only the
test ID before signing. No archive or upload occurred in that setup run.

The full-package validation generates a `LoopNextAI` workspace scheme in the
disposable CI checkout, preserving normal device/service plugins and all normal
main-app Swift files. Six package regression cases reject production identity,
shared groups/keychains, wrong source, a sandbox substitution, missing onboarding
and companion installation. The signed Simulator product is checked before a
15-second normal-startup probe. Acceptance also requires the pinned normal-app
90-check regression run to pass; no backend is deployed.

The fresh normal run [39648420016](https://github.com/jhardorp/LoopWorkspace/actions/runs/39648420016)
passed all **90 checks** (58 Swift, 26 unchanged-backend, 6 native adapter), both
Simulator builds and 15-second normal startup on iOS 18.5. The first separate
full-product run compiled successfully but its verifier read an empty Simulator
code-signature entitlement dictionary. Xcode's retained build log proves that
its separate `Loop.app-Simulated.xcent` contains the expected private group.
The corrected verifier reads the actual executable's `__TEXT,__entitlements`
section for explicitly selected Simulator products. Real iOS IPA verification
still requires Apple-signed entitlements and never falls back to that section.
Six parser regression cases cover XML/binary plists, universal architecture
agreement, truncated/missing sections, conflicting signatures and device-mode
separation, in addition to the six package cases.

The distinct `archive_candidate` lane imports the existing certificate/key with
read-only Match and skips production profile downloads. It can create/renew only
the test ID's `Loop Next AI AppStore` profile. Before compiling, it requires that
profile to contain exactly the private group and the full native HealthKit
capability. It archives the native `LoopNextAI` scheme without an upload action.
`record_candidate.py` verifies the exported identity, native plugins, effective
entitlements and source; it records the IPA SHA-256 and successful validation run.
The archive job depends directly on successful full-product validation and
packaging preflight for the same CI source. The owner's request to launch the full integration as a separate
current-phone installation authorizes the following private-test upload. The
workflow waits for its own exact full-package validation to succeed before signing,
then verifies the exported IPA and binds its SHA-256, current source/build,
private group and validation provenance before uploading only to app record
`6825358390`. It checks existing Build/BuildUpload records before transfer,
reports ingestion errors immediately and retains Apple processing status. No
tester group is modified, no external distribution occurs and no device is
installed or connected by automation.

Developer Portal setup required before this signing step can pass:

1. Under **Identifiers → App Groups**, register **Loop Next AI** with identifier
   `group.com.jhardorp.loopaiphototest`.
2. Open the test App ID **`com.jhardorp.loopaiphototest`**, edit **App Groups**,
   select that group and save. Leave working Loop's identifier untouched.

After successful upload/processing, select the new **3.15.2** build on the same
test app's [TestFlight page](https://appstoreconnect.apple.com/apps/6825358390/testflight/ios).
It replaces the AI-only test app, never working Loop. Keep Health access and real
pump/CGM connections off for initial testing; this full app has normal native
capabilities and has not been independently validated for therapy.
