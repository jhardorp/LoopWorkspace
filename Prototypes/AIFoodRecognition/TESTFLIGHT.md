# Test the separate prototype without a Mac

The owner has an Apple Developer account and has explicitly authorized a separate prototype TestFlight upload. This is **Food Review Demo**, with bundle ID **`com.jhardorp.foodrecognitionprototype`**. It does not replace or update the existing Loop app. Recognition remains mock-only.

## What runs on GitHub

The `Separate food prototype TestFlight` workflow runs on a GitHub-hosted Mac from **`feature/ai-food-recognition`**, without merging to `main`. It uses a separate Fastfile and the standalone project. It never checks out the Loop submodules or calls Loop's build/release/certificate-renewal lanes.

Only an explicit change to `Distribution/request.json` triggers the workflow through a branch push. Ordinary source commits and pull requests do not upload. The initial authorized upload request registered the separate bundle and stopped before upload because the App Store Connect app record is missing. The current request runs read-only configuration and unsigned verification while that app record is created. Allowed operations are:

| Operation | Effect |
| --- | --- |
| `check_configuration` | Check required signing credentials and whether the separate app record exists; no registration, signing, or upload |
| `prepare_signed_build` | Register the separate bundle if missing, prepare its provisioning profile, and build a signed IPA without upload |
| `upload_testflight` | Register the bundle if missing, require its App Store Connect app record, sign/build, and upload only the prototype |

The workflow validates the core and configuration guards before signing. It selects an installed Xcode 26 or newer for current Apple uploads. Signing reuses the account's existing encrypted `jhardorp/Match-Secrets` storage and available distribution certificate; it may add the prototype's provisioning profile. It never invokes certificate revocation or renewal. The repository's `main`, Loop submodule pins, existing Loop signing configuration, and installed app are unchanged. A missing certificate, authorization, secret, or unsupported runner causes a failure rather than changing Loop's setup.

## Existing secrets required

In [GitHub → repository Settings → Secrets and variables → Actions](https://github.com/jhardorp/LoopWorkspace/settings/secrets/actions), the usual Loop signing secrets must be available:

`TEAMID`, `GH_PAT`, `MATCH_PASSWORD`, `FASTLANE_KEY_ID`, `FASTLANE_ISSUER_ID`, `FASTLANE_KEY`.

Do not paste their values into chat or commit them. The workflow checks their presence without printing values. `GH_PAT` needs access to the private Match-Secrets repository. The App Store Connect key must have access to the new prototype app and permission to register its bundle and manage provisioning. Signing changes occur only in the temporary runner checkout and encrypted signing repository. No key is put in the iPhone app.

## One browser-only App Store Connect step

GitHub can register the bundle identifier using the existing API key, but this setup does not create App Store Connect app records automatically. If the workflow reports **`APP_RECORD_REQUIRED`**, the identifier is already registered and no upload has occurred.

On your iPhone or any computer:

1. Open [App Store Connect](https://appstoreconnect.apple.com/), choose **My Apps**, then **+ → New App**.
2. Select **iOS** and **English**, and enter:
   - Name: **Food Review Demo (jhardorp)**. If Apple requires another unique name, choose a different prototype name; leave the bundle unchanged.
   - Bundle ID: **`com.jhardorp.foodrecognitionprototype`**.
   - SKU: **`food-recognition-prototype`**.
3. Create the app record. Keep this separate from the Loop app record.
4. Tell the assistant once the record is created so the authorized upload can continue. To request it yourself, open [Distribution/request.json](https://github.com/jhardorp/LoopWorkspace/blob/feature/ai-food-recognition/Prototypes/AIFoodRecognition/Distribution/request.json) on the feature branch, choose **Edit**, set `operation` to `upload_testflight`, increase `revision` by one, and commit **to the feature branch**. That explicit request starts another upload attempt. Never merge to `main` for this step.

The optional **Run workflow** button may not be available while this new workflow exists only on the feature branch: GitHub normally requires manual-dispatch workflows on the default branch. Editing the request file is the supported route here and preserves `main`.

## Install after a successful upload

Apple must process the uploaded build before it can be tested; timing is outside this workflow's control. Open the prototype's **TestFlight** tab in App Store Connect, create/select an **internal testing** group, add your own tester account, and select the processed prototype build. Resolve any Apple account or export-compliance prompts. External testing is not automatically enabled or submitted for Beta App Review.

Then open TestFlight on your iPhone and install **Food Review Demo**, alongside Loop. This is a separate installation; do not replace Loop. Test camera permission/capture/cancel, editable carb grams and absorption minutes, uncertainty acknowledgment, and the simulated failures. Every photo uses the selected fictional fixture. Nothing is saved to Loop or used for insulin therapy.

The workflow does not invite testers or install anything automatically. A completed GitHub build is not proof that the app is already visible in TestFlight; upload, Apple processing, and internal tester access are separate states.
