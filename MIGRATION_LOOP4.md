# Loop 4 migration - validation only

This branch is isolated from the working feature/ai-food-recognition branch.

Current integration is pinned to Loop c30b5c89b1dc4151628f33f1384dd4796eaeeec2 (3.14.9).
Do not bypass the pin in Integration/apply.py. The overlay must be ported and reviewed for a new upstream source commit.

Migration checklist:
1. Record the exact current workspace commit and all submodule SHAs.
2. Choose and pin a specific upstream LoopWorkspace next-dev commit and its matching submodules in a separate test checkout.
3. Review LoopMealReview.patch against the new Loop carbohydrate-entry screen; port only camera/review UI and carb-field transfer.
4. Keep insulin dosing, pump commands, therapy settings, and CGM communication unchanged.
5. Run Swift/backend tests, patch checks, full unsigned simulator build, and targeted UI regression tests.
6. Independently review duplicate carbohydrate transfer, cancel/retry behavior, unit conversion, absorption time, and bolus summary.
7. Do not sign, upload, install, or enable experimental dosing features as part of this migration.

Existing .github/workflows/food_recognition_loop.yml is deliberately restricted to feature/ai-food-recognition. Do not relax its guard to permit migration branch uploads. Build a separate validate-only workflow after selecting an upstream pin.

No clinical use or insulin delivery from the experimental migration build until independently validated.
