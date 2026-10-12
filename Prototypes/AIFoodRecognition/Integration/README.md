# Meal photo review inside Loop

This feature branch adds **Photograph meal** to Loop's new carbohydrate-entry screen. The shared review screen shows editable carbohydrates, absorption minutes and meal notes at the top, followed by the estimated ranges, image, ingredients and explanations. **Use in Loop** copies only the reviewed input into the existing entry fields. The entry's time is preserved. Loop's existing Continue action, quantity validation, warnings, carb storage and bolus flow remain responsible for subsequent actions.

The Loop screen always uses the real AI provider; the standalone mock demo cannot feed this integration. Cancellation, clarification and failed/invalid responses leave the existing entry unchanged. Editing a favorite before photographing a meal does not let a queued favorite-selection update overwrite the accepted review.

## Source and build

The overlay is pinned to Loop **`c30b5c89b1dc4151628f33f1384dd4796eaeeec2`**, the existing feature branch's **3.14.9** source. `apply.py` refuses another pin before applying `LoopMealReview.patch`. `configure_project.rb` links the workspace's local `FoodRecognitionUI` package into the Loop target. Changes occur in the build checkout; the recorded Loop/LoopKit submodule pointers and `main` are unchanged.

The existing Loop source belongs to upstream LoopKit. A pinned build overlay is used here so the integration can be built and reviewed without unpublished submodule commits or a new upstream fork. A future source upgrade must rebase the overlay and pass a complete simulator build.

`.github/workflows/food_recognition_loop.yml` tests the core and compiles the full Loop workspace before signing. Only an explicit new `Integration/request.json` revision requests an upload. The `upload_testflight` operation reuses the existing Loop signing lane and uploads to internal TestFlight, without installing an app on the phone or enabling external testing.

## No credential entry

The server URL is preconfigured. For the requested personal builds, `configure_meal_review.py` writes the owner's **tester login** from the existing `FOOD_TESTER_ACCESS_CODE` Actions secret into the temporary app plist before signing. The first launch uses it automatically and stores the resulting connection in the device Keychain. Later sessions renew without typing. The tester login is therefore contained in these signed app bundles; it is not committed to source. OpenAI and Cloudflare provider credentials remain on the server/in Actions secret storage.

For builds that do not run this owner-configuration step, the standalone app retains one-time manual setup. The normal CI simulator checks use no real login and make no paid model calls.
