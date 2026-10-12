# Meal photo review inside Loop

**Uploaded: Loop 3.14.9 (18).** Apple accepted the integrated, preconfigured personal build in [run 38283878117](https://github.com/jhardorp/LoopWorkspace/actions/runs/38283878117). Its app/driver/Watch archive and signed export passed. The full simulator build passed in [run 38278695063](https://github.com/jhardorp/LoopWorkspace/actions/runs/38278695063); the upload retry verified that the app source was unchanged before reusing that result. Apple processing and the phone update are separate from upload.

This feature branch adds **Photograph meal** to Loop's new carbohydrate-entry screen. The shared review screen shows editable carbohydrates, absorption minutes and meal notes at the top, followed by the estimated ranges, image, ingredients and explanations. **Use in Loop** copies only the reviewed input into the existing entry fields. The entry's time is preserved. Loop's existing Continue action, quantity validation, warnings, carb storage and bolus flow remain responsible for subsequent actions.

The result screen starts at the top and displays the photo estimate directly above its editable fields. Draft values are populated before the screen changes to review. Low-confidence results explain the required **Reviewed estimate** checkbox. Completion requires Loop to accept the transfer: rejection keeps the numbers editable, displays a reason and leaves **Use in Loop** available for retry. Regression tests cover rejection/retry, edited locale values, duplicate delivery and invalid or unacknowledged input.

The Loop screen always uses the real AI provider; the standalone mock demo cannot feed this integration. Cancellation, clarification and failed/invalid responses leave the existing entry unchanged. Editing a favorite before photographing a meal does not let a queued favorite-selection update overwrite the accepted review.

## Source and build

The overlay is pinned to Loop **`c30b5c89b1dc4151628f33f1384dd4796eaeeec2`**, the existing feature branch's **3.14.9** source. `apply.py` refuses another pin before applying `LoopMealReview.patch`. `configure_project.rb` links the workspace's local `FoodRecognitionUI` package into the Loop target. Changes occur in the build checkout; the recorded Loop/LoopKit submodule pointers and `main` are unchanged.

The existing Loop source belongs to upstream LoopKit. A pinned build overlay is used here so the integration can be built and reviewed without unpublished submodule commits or a new upstream fork. A future source upgrade must rebase the overlay and pass a complete simulator build.

`.github/workflows/food_recognition_loop.yml` tests the core and compiles the full Loop workspace before signing. Only an explicit new `Integration/request.json` revision requests an upload. The `upload_testflight` operation reuses the existing Loop signing lane and uploads to internal TestFlight, without installing an app on the phone or enabling external testing.

For a signing-only retry, a request can name the previously validated source/run. `reuse_validation.py` checks the source SHA, successful full compile step and changed-file list before reusing compilation. App source, package, overlay, submodule and code-to-documentation rename changes require a fresh compile. Local tests cover these cases. Raw simulator output is kept in the temporary runner log and only its tail is printed so signing diagnostics remain readable.

## No credential entry

The server URL is preconfigured. For the requested personal builds, `configure_meal_review.py` writes the owner's **tester login** from the existing `FOOD_TESTER_ACCESS_CODE` Actions secret into the temporary app plist before signing. The first launch uses it automatically and stores the resulting connection in the device Keychain. Later sessions renew without typing. The tester login is therefore contained in these signed app bundles; it is not committed to source. OpenAI and Cloudflare provider credentials remain on the server/in Actions secret storage.

For builds that do not run this owner-configuration step, the standalone app retains one-time manual setup. The normal CI simulator checks use no real login and make no paid model calls.
