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
