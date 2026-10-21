# Loop AI Test — separate installation candidate

This prepares an experimental AI interface test app alongside the working Loop.
It does not upgrade or replace the working Loop. No upload or device installation
is performed by this workflow.

## Identity and isolation

- Display name: **Loop AI Test**, with a new orange TEST icon.
- Bundle ID: **`com.jhardorp.loopaiphototest`**.
- URL scheme: `loop-ai-test`.
- Empty source entitlements: no HealthKit, app groups, shared keychain, Siri,
  Bluetooth/NFC capabilities or background device services.
- The final signed artifact is checked for unexpected entitlements, production
  identity/keychain access, extensions, watch apps and dynamic device plugins.
- Its declared group name is distinct, but no app-group access is granted.
  Preferences and the remembered AI login belong to this app's own container and
  default keychain group. It cannot read the working Loop's group or keychain.
- Test meal entries exist only in memory and disappear when the process exits.
  Favorites/preferences and AI connection settings may persist in the test app's
  own storage. AI photos still use the unchanged personal backend and API credits.

## What this tests

The generator starts from the same pinned upstream Loop source and applies the
same reviewed photo adapter. It preserves the real native carbohydrate editor,
quantity limits, entry time, camera/gallery presentation, comment refinement,
confidence review, explicit Use in Loop handoff, and stable new-entry identity.
The generated application starts a new SwiftUI home, without instantiating the
production AppDelegate, SceneDelegate, LoopAppManager or device/store managers.

Continue opens a **test entry preview** instead of the insulin/bolus screen.
Save test entry records one copy in the memory ledger. No test entry is written to
HealthKit or the working Loop. The delegate rejects storage, glucose and delivery
requests; there is no pump or CGM setup screen. This tests the photo-to-native-editor
integration; it does not validate the real bolus screen, therapy, upgrade of existing
stores, or rollback. Production algorithms and communication source remain unchanged.

The personal tester login is injected only into the signed test candidate by the
unchanged production configurator. No OpenAI key is added to the app. The candidate
is personal and must not be publicly redistributed.

## Validation and archive

The migration-only `Separate Loop AI test app` workflow pins Xcode 26.3 and verifies
protected production configuration. It runs five isolation regression tests and
four memory-ledger tests, builds the app unsigned, packages it for Simulator with
Xcode ad-hoc signing, checks effective isolation, and runs two actual UI cases:
native editor cancellation and one explicit test save followed by an empty relaunch.
It refuses an empty UI test run. Initial macOS results are **pending**.

An explicit `[sandbox-candidate]` migration commit marker or the manual
`prepare_signed_sandbox` input requests an archive after the checks pass. The signing
lane reads the existing certificate/key with read-only match, then creates/downloads
only the new test app's identifier/profile using that existing certificate. It does
not create or renew certificates, change production profiles or write the signing
repository. Root signing/distribution configuration remains unchanged.

The archive contains `LoopAIPhotoTest.ipa`, `SandboxCandidate.json` with effective
identity, isolation, source and IPA hash, and `AppRecordStatus.json`. A separate App
Store Connect app record is required for future TestFlight distribution. The lane
checks whether it exists and reports that status; it does not upload. The App Store
IPA is not directly installable. Upload or installation requires the user's explicit
approval under the migration instructions.

## On-phone acceptance after approved distribution

Keep the working Loop installed. Open **Loop AI Test** and verify its TEST label.
Use Test a meal entry to check first-tap camera/gallery routing, cancellation,
photo analysis, comments such as two portions/product corrections, low confidence,
decimal editing, original entry time and wrapped descriptions. Explicitly transfer
the result into this app's editor, then Continue and Save test entry. One save must
show one test entry; cancelling must show none. Restarting this app clears test entries.
The production Loop must remain unchanged throughout. Independent validation remains
required before this migration is considered for therapy.
