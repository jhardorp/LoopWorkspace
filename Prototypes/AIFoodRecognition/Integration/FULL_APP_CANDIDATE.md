# Full Loop plus AI — experimental candidate

The owner reports that the separately installed **Loop AI Test 0.1.0 (12)** works
perfectly after the requested photo/comment/review/save/restart exercise, and now
requests the AI integration in the full migrated Loop interface. This is owner
acceptance of the isolated AI flow; it does not validate full Loop startup,
existing-store migration, hardware communication or clinical safety.

The normal Loop adapter is already present on `migration/loop4-ai-photo`. It fills
editable carbohydrate/absorption/note fields only after explicit confirmation,
preserves entry time, and rejects cancelled/stale/duplicate callbacks. It does
not save an entry, calculate a dose, deliver insulin or change therapy settings.

## Source and release boundary

Keep the tested upstream pins: LoopWorkspace
`53253aaa774a95ea6e299cc1a2fabc4af861328c`, Loop
`b55744981c2e589799754d19f73b8912c8809e12`. This next-dev workspace reports
**3.15.2**, not a released Loop 4.0. Do not silently move these pins during rollout.

A fresh normal-app validation must run the package/backend/native regressions,
unsigned Simulator build and normal startup before any full candidate is prepared
for distribution. The existing isolated-app binary is not the full Loop app and
must not be presented as such. The existing production signing/release workflows,
backend, feature/main branches and installed working Loop remain protected.

The owner selected the **current iPhone with a separate installation**. Reuse the
existing test-only app slot `com.jhardorp.loopaiphototest`, never the working Loop
identity. Give the full experimental app its own registered storage group and
companion identities before distribution. Same-phone separate
installation requires distinct full-app/companion identities, storage groups and
URL schemes. HealthKit data is shared by the operating system and is not isolated
merely by changing the app bundle ID. A production-identity TestFlight upload could
also reach existing testers/automatic updates, so do not use that route to preserve
the working app without a deliberate installation plan.

No full-app upload, device installation, production merge or hardware/therapy
validation has been performed for this request. The migration remains experimental;
independent validation is still required. See CONTROLLED_VALIDATION.md for the full
manual acceptance record and MIGRATION_LOOP4.md for source pins and comparison.

The first current-phone full-app acceptance must keep Apple Health permissions
and real pump/CGM connections disabled. Separate app storage does not isolate
HealthKit samples. This preparation imports no production device credentials or
therapy settings and makes no clinical safety claim.
