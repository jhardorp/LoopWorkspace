# Loop AI service credential incident and repair — November 10–11, 2026

The live photo endpoint returned HTTP 503 `providerUnavailable`. Direct OpenAI model/Responses checks using the configured GitHub credential returned HTTP 401. The guarded credential check reported `token_invalidated` and `provider_authentication_rejected`.

Evidence:
- November 8 description check: [42524072057](https://github.com/jhardorp/LoopWorkspace/actions/runs/42524072057), login/model access/validated text estimate succeeded.
- November 10 photo check: [42907751543](https://github.com/jhardorp/LoopWorkspace/actions/runs/42907751543), login succeeded, photo request returned 503 and the direct provider probe returned 401.
- November 10 credential guards/check: [42912377165](https://github.com/jhardorp/LoopWorkspace/actions/runs/42912377165), all seven guard/privacy tests passed; the live credential check returned 401 / token_invalidated. No server secret was changed. Sanitized artifact: 13806758859.

## Credential replacement

The owner replaced the GitHub Actions repository secret **FOOD_OPENAI_API_KEY** with a valid OpenAI project API key for this repair on November 11. The successful minimal Responses request verified access to the existing configured model. Use [OpenAI API keys](https://platform.openai.com/api-keys) and [this repository's Actions secrets](https://github.com/jhardorp/LoopWorkspace/settings/secrets/actions). Never put the key in chat, source files, issues, artifacts or workflow inputs.

The rejection is authentication-related; this check does not establish a billing or credit shortage. A deleted/invalidated credential cannot be reconstructed from app source.

## Guarded repair procedure

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

The user corrected the initially reported 3.15.8 to **3.15.2**. The read-only Apple status check in [42906819593](https://github.com/jhardorp/LoopWorkspace/actions/runs/42906819593) showed the known AI release 3.15.2 (28), VALID / IN_BETA_TESTING, in app 6737123014. No downgrade or device installation was performed.

## Verified repair — November 11

The owner confirmed saving the replacement GitHub secret. Request revision 2 in commit **8a1c55760584209dfd0d6184051b2bf5c69086e4** applied the authorized secret-only repair in [run 42987376862](https://github.com/jhardorp/LoopWorkspace/actions/runs/42987376862).

- All seven credential guard/privacy tests passed, as did the migration configuration checks.
- OpenAI accepted the replacement credential (HTTP 200) before the Cloudflare update.
- Only the existing Worker's **OPENAI_API_KEY** secret was updated (Cloudflare HTTP 200). The checked model/quota/limit/secret-name configuration was unchanged.
- Authenticated description analysis returned HTTP 200 with a schema-valid estimate.
- Authenticated photo analysis returned HTTP 200 with a schema-valid `needsMoreInformation` response for a synthetic blank JPEG. This verifies the image request path and graceful handling of a non-food image; it does not measure real-food recognition accuracy.
- Both live checks succeeded between 08:29:17 and 08:29:27 UTC. No direct provider fallback was needed.

Sanitized results are retained in [SERVICE_REPAIR_RESULT.json](SERVICE_REPAIR_RESULT.json) and workflow artifact **13840575467** (expires November 18). The app, tester access code, production branches and therapy configuration were not changed by the repair. A failed request on the phone is not retried automatically; the user needs to start a fresh meal analysis.

Current status: **server credential repaired; live text and photo request checks passed. Phone-side confirmation remains with the user.**
