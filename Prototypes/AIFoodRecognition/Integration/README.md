# Experimental Loop meal-photo migration

This branch ports the existing photo review to the dependency set from LoopWorkspace next-dev `53253aaa774a95ea6e299cc1a2fabc4af861328c`, Loop `b55744981c2e589799754d19f73b8912c8809e12` (workspace version 3.15.2). The production feature branch remains unchanged.

**Validation passed:** [run 39397041333](https://github.com/jhardorp/LoopWorkspace/actions/runs/39397041333) tested code commit `3ac9aed295a2fcacb34e8f71f7946fc55552d65f`: 58 Swift package tests, 26 backend tests, six native adapter tests, and the complete unsigned Simulator build. Xcode 26.3 (17C529).

See [MIGRATION_LOOP4.md](../../../MIGRATION_LOOP4.md) for source pins, behavior comparison, test results and independent-validation requirements. See [SHARING.md](SHARING.md) for the reusable package/adapter boundary and instructions for other developers.

Camera/gallery review, comments, editable grams/minutes/notes, confidence warnings and explicit Use in Loop confirmation use the existing shared Swift package. The native overlay fills editable values only. It preserves entry time and upstream saving, bolus calculation, delivery, CGM and therapy behavior. A unique presentation token rejects duplicate and cancelled callbacks. Textual descriptions wrap in the carbohydrate editor and bolus summary.

`apply.py` refuses a different Loop source commit. `verify_migration.py` checks source pins and protects production signing/backend/upload configuration. `configure_project.rb` links both package products; `configure_scheme.py` completes plugins before the app copies them.

Use only `.github/workflows/loop_ai_migration_validate.yml` on this branch. Its validation job runs tests and a fresh unsigned Simulator build, without Apple/AI credentials or paid AI calls. A follow-up probe ad-hoc signs a disposable copy for Simulator startup; it uses no Apple signing identity and produces no installable device build. Native tests still use a minimal generated Simulator host after the normal app build. Run these adapter tests through that workflow, which prepares the required host fixture. Both jobs pin Xcode 26.3. Existing production release workflows remain restricted to their original branch.

See [CONTROLLED_VALIDATION.md](CONTROLLED_VALIDATION.md) for draft review PR #2, the source-review findings, installation choices that preserve the working app, and the pending independent/manual acceptance record. The startup probe is an additional check; no result is claimed until its run finishes. A manual `prepare_signed_candidate` option defaults to false; when requested, a separate job archives the normal app using existing read-only provisioning **for a spare test device**, and retains provenance alongside the IPA. No TestFlight upload, physical-device installation or deployment is performed by this workflow.

No clinical use or insulin delivery from this experimental migration until independently validated. Signing, TestFlight upload, device installation, deployment and merging to production require separate explicit approval.
