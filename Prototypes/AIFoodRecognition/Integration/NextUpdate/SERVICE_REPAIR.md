# Loop AI service credential incident — November 10, 2026

The live photo endpoint returned HTTP 503 `providerUnavailable`. Direct OpenAI model/Responses checks using the configured GitHub credential returned HTTP 401. The guarded credential check reported `token_invalidated` and `provider_authentication_rejected`.

Evidence:
- November 8 description check: [42524072057](https://github.com/jhardorp/LoopWorkspace/actions/runs/42524072057), login/model access/validated text estimate succeeded.
- November 10 photo check: [42907751543](https://github.com/jhardorp/LoopWorkspace/actions/runs/42907751543), login succeeded, photo request returned 503 and the direct provider probe returned 401.
- November 10 credential guards/check: [42912377165](https://github.com/jhardorp/LoopWorkspace/actions/runs/42912377165), all seven guard/privacy tests passed; the live credential check returned 401 / token_invalidated. No server secret was changed. Sanitized artifact: 13806758859.

## Required account action

An owner must replace the GitHub Actions repository secret **FOOD_OPENAI_API_KEY** with a valid OpenAI project API key that can use the Responses API and the existing configured model. Use [OpenAI API keys](https://platform.openai.com/api-keys) and [this repository's Actions secrets](https://github.com/jhardorp/LoopWorkspace/settings/secrets/actions). Never put the key in chat, source files, issues, artifacts or workflow inputs.

The rejection is authentication-related; this check does not establish a billing or credit shortage. A deleted/invalidated credential cannot be reconstructed from app source.

## Prepared repair

`loop_ai_key_repair.yml` defaults to **check**, makes no secret changes in check mode, and tests the supplied provider credential with a fixed minimal Responses request. It does not depend on expired build-28 IPA artifacts.

After the owner saves the replacement specifically for this repair, update `credential-repair-request.json` to the next revision and commit on the migration branch with **[apply-ai-key-repair]**. This selects the guarded repair operation. A manual **repair** dispatch selects the same operation.

The operation:
1. Checks the owner repository/ref, fixed existing Cloudflare account and explicit repair authorization.
2. Reads the existing Worker binding metadata and verifies the same model, quota namespace and tester-secret binding.
3. Requires a successful provider Responses request before issuing any secret write.
4. Updates only **OPENAI_API_KEY** on the existing **loop-plus-meal-review** Worker.
5. Verifies other model/limit/quota/secret-name metadata is unchanged.
6. Tests description and photo analysis with fixed synthetic inputs and retains sanitized outcomes.

The tester access code and iPhone login are not rotated. No Loop app build, reinstall, dosing/therapy edit or production-branch merge is part of this repair. No real patient photo or meal description is used by these checks.

Guard tests cover rejected credentials preventing writes, read-only checks, exact single-secret update scope and ordering, owner authorization, fixed account scope, binding drift and error-message privacy.

## Phone version

The user reported version 3.15.8. A read-only Apple status check in [42906819593](https://github.com/jhardorp/LoopWorkspace/actions/runs/42906819593) still showed the known AI release 3.15.2 (28), VALID / IN_BETA_TESTING, in app 6737123014. The installed version/source remains to be confirmed if a phone-side issue persists after server repair. No downgrade or device installation was performed.

Current status: **replacement provider credential required; repair prepared and guard-tested, not applied**.
