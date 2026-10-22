# Existing app update

The owner authorized an update of the working Loop after reporting successful
unconnected photo/review testing of the separate full app on 22 October 2026.
This authorizes publishing an existing-identity candidate; it does not establish
independent validation of the new Loop development line for therapy.

The retained normal-identity candidate is `3.15.2 (27)`, source
`e768ff50dc335671f479543ccd5f3a525c733c20`, from successful validation/archive
run `39565198453`, artifact `12332699181`.

* IPA SHA-256: `d078c42e33663dbefa601d33275b8b99162b82f9b35ba12fe53defe03ad48b34`.
* App: `com.279LYMG57A.loopkit.Loop`.
* Existing group: `group.com.279LYMG57A.loopkit.LoopGroup`.
* Native startup, Watch app, widgets, existing signing and personal AI login.
* No application, adapter, backend or dependency pin changes since that archive.

`LegacyStoredSettings.json` is the encoding fixture from upstream LoopKit's
`SettingsStoreTests.testStoredSettingsCodable`, pinned at the working app's
LoopKit revision `d9f1437353482690426bd981536f58c1e95ff535`. It is synthetic,
not copied from the owner's phone. The two additional Simulator cases insert
that old-format binary settings data, meal and glucose records into Modelv4,
then open it using the pinned new PersistenceController and SettingsStore.
They assert saved values, non-default insulin model preservation, and no
duplicate records across a second launch. The original two upstream migration
cases also run. These tests do not connect to a pump, CGM or HealthKit store.

The schema changes from Modelv4 to Modelv8. Reinstalling an older app is not a
guaranteed data-compatible rollback. Loop's new preset behavior and other
upstream algorithm changes require independent validation; these fixture tests
and the owner's AI workflow report do not provide that validation.

The status lane is read-only. The upload lane accepts only the exact retained,
verified IPA, requires explicit workflow authorization and successful migration
evidence, and refuses an unexpected production build history or duplicate
upload. It neither rebuilds nor re-signs the app and does not change the
production branch, production signing repository, tester groups, devices or
backend. Publishing does not prove installation or successful migration of the
owner's actual device data.

Migration run [39747429039](https://github.com/jhardorp/LoopWorkspace/actions/runs/39747429039)
passed all four cases and the retained IPA signature/identity check at
08:29 UTC on 22 October 2026, source `0ce05a235c26b0401535a3188eb7650293598f91`.
Evidence artifact `12412546154` has ZIP digest
`74695a48b0e5847a2d79da7df72003f268ddef7f3e9aaacb61578390eed67c66`.
The initial repeat-launch failure was a test-cleanup mistake: the upstream
test `tearDown()` destroys the store. The regression now detaches the
coordinator and preserves the database for the second launch. No runtime
persistence code was changed.

Read-only Apple check [39746718005](https://github.com/jhardorp/LoopWorkspace/actions/runs/39746718005)
confirmed the existing app is `6737123014` and its latest build is
`3.14.9 (26)`, VALID and IN_BETA_TESTING. The owner-authorized upload is for
that existing app, not the separate `Loop Next AI` installation.
