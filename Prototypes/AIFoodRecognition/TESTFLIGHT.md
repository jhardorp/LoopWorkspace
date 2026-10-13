# Test the separate prototype without a Mac

## Personal 0.4.0 builds and integrated Loop

Apple accepted **Loop+ 0.4.0 (4)** in [run 38278695013](https://github.com/jhardorp/LoopWorkspace/actions/runs/38278695013) and **Loop 3.14.9 (22)** with integrated meal review in [run 38361188721](https://github.com/jhardorp/LoopWorkspace/actions/runs/38361188721). After Apple processing, update the relevant app in TestFlight. In Loop, open **Add Carb Entry → Photograph meal** and accept the camera capture: analysis starts automatically without the separate **Photo upload** screen. The result uses compact numeric rows and smaller gaps between sections. Review the values, turn on **Reviewed estimate** when shown, and choose **Use in Loop**. The normal Continue flow remains next. No server address or tester password entry is required by these personal builds.

The 0.4.0 Loop+ build preconfigures the server/tester login and displays the editable result above its explanations. The build-time tester-login step uses the existing `FOOD_TESTER_ACCESS_CODE` Actions secret; the tester login is present in the signed bundle but is never committed to source. OpenAI/Cloudflare provider keys remain server-side.

The separate [Loop integration workflow](Integration/README.md) builds the existing feature branch's Loop 3.14.9 source with the camera/review UI. Its `Integration/request.json` controls validation/upload to the existing Loop app's internal TestFlight. Source changes do not install either app on a device. Apple processing still follows a successful upload.

## Earlier standalone distribution

The owner has an Apple Developer account and has explicitly authorized a separate prototype TestFlight upload. This is **Loop+**, with bundle ID **`com.jhardorp.foodrecognitionprototype`**. It does not replace or update the existing Loop app. The installed 0.1.0 build is mock-only. The 0.2.0 source adds opt-in OpenAI analysis, which requires [backend setup](Backend/SETUP.md) before real photos can be analyzed.

**Earlier confirmed upload: Loop+ 0.3.0 (3)** was accepted by App Store Connect on 2026-10-12 in [run 38271487237](https://github.com/jhardorp/LoopWorkspace/actions/runs/38271487237). All 41 Swift tests, 18 backend tests, four Ruby guards, unsigned iPhone compilation and signed export/upload passed. Apple processing and availability to the existing internal group are not verified by that lane. Once processed, select build 3 under **Jantest → Builds** if it is not assigned automatically, then update Loop+ in TestFlight. Enter the tester password once; the server address is prefilled and future authorization renews automatically.

**Earlier AI upload: Loop+ 0.2.0 (2)** was accepted on 2026-10-11 in [run 38175789487](https://github.com/jhardorp/LoopWorkspace/actions/runs/38175789487). That version stored only the server address and 30-minute token, so it required another login after expiry. Version 0.3.0 adds saved-password renewal while retaining per-photo consent.

**Backend published on 2026-10-12:** [run 38209167402](https://github.com/jhardorp/LoopWorkspace/actions/runs/38209167402) passed its backend checks, published the separate Worker and verified `/health`. In Loop+ 0.2.0, choose **OpenAI photo analysis**, enter **`https://loop-plus-meal-review.jan-1af.workers.dev`** as the **HTTPS server address**, enter the private **Tester access code**, and tap **Connect to AI service**. Then photograph a meal and explicitly approve **Analyze this photo**. The first consented photo verifies provider access; deployment did not send a photo or make a paid model request. See [setup and billing](Backend/SETUP.md).

**Earlier confirmed upload on 2026-10-11:** [workflow run 38158512784](https://github.com/jhardorp/LoopWorkspace/actions/runs/38158512784) passed and App Store Connect accepted the prototype binary. The project version is **0.1.0**, build **1**. Apple processing and internal tester access were not verified by that upload lane; follow the installation steps below once the build is available.

**Owner device check:** the owner subsequently supplied App Store Connect screenshots showing completed processing and an internal group with one tester and one build, then confirmed installation. A device screenshot shows a captured photo in the mock review. This confirms the standalone installation and capture/review path; the food estimates remain fictional and unrelated to the photo. It does not validate real recognition, numerical accuracy, or all camera/accessibility cases.

**0.3.0 remembered-login update:** uploaded in the successful run linked above. The server address is prefilled; after entering the tester password once, it is stored in device-only Keychain storage and app authorization renews automatically. Updating 0.2.0 preserves its address but requires the password once because that version did not save it. **Forget saved login** removes the saved connection. All 41 Swift tests passed locally and on macOS, including 13 renewal/storage/cancellation/migration tests. Apple processing, tester assignment and the device update remain separate owner checks.

## What runs on GitHub

The `Separate food prototype TestFlight` workflow runs on a GitHub-hosted Mac from **`feature/ai-food-recognition`**, without merging to `main`. It uses a separate Fastfile and the standalone project. It never checks out the Loop submodules or calls Loop's build/release/certificate-renewal lanes.

Only an explicit change to `Distribution/request.json` triggers the workflow through a branch push. Ordinary source commits and pull requests do not upload. The separate bundle and App Store Connect app record now exist. The current request records the authorized `upload_testflight` operation that succeeded in the run linked above. Another request revision triggers another build/upload. Allowed operations are:

| Operation | Effect |
| --- | --- |
| `check_configuration` | Check required signing credentials and whether the separate app record exists; no registration, signing, or upload |
| `prepare_signed_build` | Register the separate bundle if missing, prepare its provisioning profile, and build a signed IPA without upload |
| `upload_testflight` | Register the bundle if missing, require its App Store Connect app record, sign/build, and upload only the prototype |

The workflow validates the Swift core, backend contract/dry run and configuration guards before signing. It never deploys the backend or passes OpenAI/Cloudflare keys to the app build. It selects an installed Xcode 26 or newer for current Apple uploads. Signing reuses the account's existing encrypted `jhardorp/Match-Secrets` storage and available distribution certificate; it may add the prototype's provisioning profile. It never invokes certificate revocation or renewal. The repository's `main`, Loop submodule pins, existing Loop signing configuration, and installed app are unchanged. A missing certificate, authorization, secret, or unsupported runner causes a failure rather than changing Loop's setup.

## Existing secrets required

In [GitHub → repository Settings → Secrets and variables → Actions](https://github.com/jhardorp/LoopWorkspace/settings/secrets/actions), the usual Loop signing secrets must be available:

`TEAMID`, `GH_PAT`, `MATCH_PASSWORD`, `FASTLANE_KEY_ID`, `FASTLANE_ISSUER_ID`, `FASTLANE_KEY`.

Do not paste their values into chat or commit them. The workflow checks their presence without printing values. `GH_PAT` needs access to the private Match-Secrets repository. The App Store Connect key must have access to the new prototype app and permission to register its bundle and manage provisioning. Signing changes occur only in the temporary runner checkout and encrypted signing repository. No key is put in the iPhone app.

## One browser-only App Store Connect step

GitHub can register the bundle identifier using the existing API key, but this setup does not create App Store Connect app records automatically. If the workflow reports **`APP_RECORD_REQUIRED`**, the identifier is already registered and no upload has occurred.

On your iPhone or any computer:

1. Open [App Store Connect](https://appstoreconnect.apple.com/), choose **My Apps**, then **+ → New App**.
2. Select **iOS** and **English**, and enter:
   - Name: **Loop+**. If Apple requires another unique name, choose a different prototype name; leave the bundle unchanged.
   - Bundle ID: **`com.jhardorp.foodrecognitionprototype`**.
   - SKU: **`food-recognition-prototype`**.
3. Create the app record. Keep this separate from the Loop app record.
4. Tell the assistant once the record is created so the authorized upload can continue. To request it yourself, open [Distribution/request.json](https://github.com/jhardorp/LoopWorkspace/blob/feature/ai-food-recognition/Prototypes/AIFoodRecognition/Distribution/request.json) on the feature branch, choose **Edit**, set `operation` to `upload_testflight`, increase `revision` by one, and commit **to the feature branch**. That explicit request starts another upload attempt. Never merge to `main` for this step.

The optional **Run workflow** button may not be available while this new workflow exists only on the feature branch: GitHub normally requires manual-dispatch workflows on the default branch. Editing the request file is the supported route here and preserves `main`.

If a request-file push starts no run, check whether the [separate prototype workflow](https://github.com/jhardorp/LoopWorkspace/actions/workflows/food_recognition_testflight.yml) is disabled. Enable that workflow, then commit a new request revision on the feature branch. This does not require enabling or running Loop's release workflows.

## Install after a successful upload

Apple must process the uploaded build before it can be tested; timing is outside this workflow's control. Open the prototype's **TestFlight** tab in App Store Connect, create/select an **internal testing** group, add your own tester account, and select the processed prototype build. Resolve any Apple account or export-compliance prompts. External testing is not automatically enabled or submitted for Beta App Review.

Then open TestFlight on your iPhone and install **Loop+**, alongside Loop. This is a separate installation; do not replace Loop. Test camera permission/capture/cancel, editable carb grams and absorption minutes, uncertainty acknowledgment, and the simulated failures. In Mock demo, every photo uses the selected fictional fixture. In 0.2.0 OpenAI mode, connect to the configured backend and confirm each upload. Nothing is saved to Loop or used for insulin therapy.

The workflow does not invite testers or install anything automatically. A completed GitHub build is not proof that the app is already visible in TestFlight; upload, Apple processing, and internal tester access are separate states.

## 0.2.0 AI connection update

The updated Swift/backend/Ruby tests and unsigned iPhone build passed in [run 38175329086](https://github.com/jhardorp/LoopWorkspace/actions/runs/38175329086). Distribution request revision 6 succeeded in [run 38175789487](https://github.com/jhardorp/LoopWorkspace/actions/runs/38175789487): Apple accepted **0.2.0 (2)**. This proves upload, not processed Apple status, tester-group assignment or installation. Real photo analysis also needs the owner-configured backend and API credits described in the setup guide.
