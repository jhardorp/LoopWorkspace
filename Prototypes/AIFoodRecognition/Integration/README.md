# Experimental Loop meal-photo migration

This branch ports the existing photo review to the dependency set from LoopWorkspace next-dev `53253aaa774a95ea6e299cc1a2fabc4af861328c`, Loop `b55744981c2e589799754d19f73b8912c8809e12` (workspace version 3.15.2). The production feature branch remains unchanged.

See [MIGRATION_LOOP4.md](../../../MIGRATION_LOOP4.md) for source pins, behavior comparison, test results and independent-validation requirements. See [SHARING.md](SHARING.md) for the reusable package/adapter boundary and instructions for other developers.

Camera/gallery review, comments, editable grams/minutes/notes, confidence warnings and explicit Use in Loop confirmation use the existing shared Swift package. The native overlay fills editable values only. It preserves entry time and upstream saving, bolus calculation, delivery, CGM and therapy behavior. A unique presentation token rejects duplicate and cancelled callbacks. Textual descriptions wrap in the carbohydrate editor and bolus summary.

`apply.py` refuses a different Loop source commit. `verify_migration.py` checks source pins and protects production signing/backend/upload configuration. `configure_project.rb` links both package products; `configure_scheme.py` completes plugins before the app copies them.

Use only `.github/workflows/loop_ai_migration_validate.yml` on this branch. It runs tests and a fresh unsigned Simulator build, without real credentials or paid AI calls. It cannot sign, upload, install or deploy. Existing production release workflows remain restricted to their original branch.

No clinical use or insulin delivery from this experimental migration until independently validated. Signing, TestFlight upload, device installation, deployment and merging to production require separate explicit approval.
