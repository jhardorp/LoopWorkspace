# Reusing the experimental meal-photo module

The package is separated from Loop so it can be reviewed and eventually shared. It remains experimental and requires independent safety validation before clinical use. No public release, hosted service or device installation is part of this migration.

## Components

- `FoodRecognitionCore`: backend contract, editable draft, confidence/validation checks, comment refinement, cancellation and single-use review handoff. No Loop, pump, CGM or dosing dependencies.
- `FoodRecognitionUI`: camera, selected-photo gallery access, compact result review, editable grams/minutes/notes, confidence acknowledgement, refinement editor and explicit Use in Loop action.
- `LoopMealReview.patch`: the only Loop-specific adapter. It fills editable fields and displays wrapped notes; it never saves, calculates a dose or issues delivery commands.
- `Backend`: separately operated Cloudflare Worker. Its OpenAI key belongs in that operator's server secret storage.

## Reproducible integration for developers

1. Use the exact upstream workspace and submodule commits in `upstream-lock.json`, the workspace Swift `Package.resolved`, and the recorded Ruby build tools. A different Loop version requires a separately reviewed adapter.
2. Add `Prototypes/AIFoodRecognition` as a local Swift package. The validation workflow demonstrates checkout, pin verification, patch application and Xcode project linkage. `apply.py` checks the Loop pin; do not bypass its guard.
3. Link FoodRecognitionUI and FoodRecognitionCore to Loop. Connect a single item-driven camera/gallery presentation to FoodRecognitionView. The callback receives only ReviewedMeal values after the user's explicit confirmation.
4. Own a MealReviewHandoff in the entry view model, begin it for each presentation, cancel it on dismissal, and consume it once to replace editable entry fields. Preserve entry time and the upstream save/Continue flow.
5. Configure **your own** HTTPS backend and tester login. The prototype currently has the owner's URL as its default; change that default for a distributed integration or use the connection fields. Never distribute the owner's tester code or reuse a personal signed bundle. No OpenAI/Cloudflare keys belong in the app or repository.
6. Run all package tests, backend contract checks, native mock adapter tests and a complete unsigned Simulator build. Independently inspect the patch and validate UI behavior before considering any release.

This is an adapter and Swift package, not a drop-in Loop plugin. Loop currently requires source integration for the carbohydrate editor. The upstream Loop license is in `Loop/LICENSE.md`; distribution requires reviewing that license and all included third-party licenses and choosing/documenting a license for the custom module. This repository has not established a separately licensed public module release.

Potential later work: a dedicated package repository, versioned adapter releases tied to upstream commits, a neutral backend configuration screen, a sample app using mock results, and maintainer-reviewed contribution instructions. None requires sharing the owner's credentials or altering dosing code.
