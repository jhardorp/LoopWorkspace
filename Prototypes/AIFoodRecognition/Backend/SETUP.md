# Enable real photo analysis without a Mac

**Personal builds now require no credential entry:** Apple accepted Loop+ **0.4.0 (4)** and integrated Loop **3.14.9 (18)** with the server/tester login preconfigured during signing. Their connections are saved on-device and renewed automatically. Use TestFlight to update after Apple processing; the setup instructions below describe server/account configuration and earlier app versions. See [the native integration](../Integration/README.md).

The owner selected OpenAI, accepted small per-photo API charges and requested no additional monthly subscription. This setup uses **OpenAI prepaid API credits** and **Cloudflare Workers Free**, with a SQLite Durable Object for request counters. It does not buy a subscription or upgrade a hosting plan. ChatGPT subscription billing does not cover API use.

The separate **Loop+ 0.2.0 (2)** upload was accepted by Apple in [run 38175789487](https://github.com/jhardorp/LoopWorkspace/actions/runs/38175789487). On 2026-10-12, [configuration run 38208571429](https://github.com/jhardorp/LoopWorkspace/actions/runs/38208571429) confirmed all four owner-managed secrets are present and have valid basic formats. [Deployment run 38209167402](https://github.com/jhardorp/LoopWorkspace/actions/runs/38209167402) published the separate Worker, stored its secrets and verified its public health endpoint. Backend tests and dry-run checks passed before publication.

**Deployed server address for Loop+:**

```text
https://loop-plus-meal-review.jan-1af.workers.dev
```

An additional HTTPS check with app-style request headers returned `200` and `status: ready`. No paid OpenAI request was made. Provider access, API credit, the updated device installation and real photo analysis still require the owner's consented device trial. The owner creates provider credentials in their own browser; never share provider keys or commit credentials. Only the separate tester code is entered into the app, not the OpenAI/Cloudflare keys.

Apple accepted **Loop+ 0.3.0 (3)** in [run 38271487237](https://github.com/jhardorp/LoopWorkspace/actions/runs/38271487237) after 41 Swift tests, 18 backend tests, four Ruby guards and iPhone compilation passed. This update prefills the address and remembers the tester password after one successful login. A retry of [backend run 38252740671](https://github.com/jhardorp/LoopWorkspace/actions/runs/38252740671) also completed publication/secret storage and verified `/health` after a transient Cloudflare timeout. The runtime redirect fix and owner-enabled operational observability were preserved.

## 1. OpenAI credits and key

1. Open [OpenAI API billing](https://platform.openai.com/settings/organization/billing/overview) in Safari and log in.
2. Add a small prepaid balance using the amount/minimum offered by OpenAI. **Leave automatic recharge off**. Project budget alerts are not necessarily hard spending caps, and prepaid metering can be delayed; do not assume an instant cutoff at the displayed balance.
3. Open [project API keys](https://platform.openai.com/api-keys), select your project and create a secret key with permission to create Responses for the configured model. Keep its one-time value private.
4. Open [GitHub Actions secrets](https://github.com/jhardorp/LoopWorkspace/settings/secrets/actions), tap **New repository secret**, name it **`FOOD_OPENAI_API_KEY`**, paste the API key as its value and save. The separate deployment job transfers it to server secret storage.

## 2. Free Cloudflare account and credentials

1. Open [Cloudflare's dashboard](https://dash.cloudflare.com/) and create/log into your account. Use **Workers Free**; no custom domain or monthly hosting subscription is needed. Do not purchase an upgrade for this setup if prompted.
2. In **Workers & Pages**, complete the free `workers.dev` subdomain setup if prompted. The app will use this HTTPS address.
3. In the dashboard search, enter **Copy account ID** and select the result. Save the selected account's copied ID (32 characters) in GitHub Actions secrets as **`CLOUDFLARE_ACCOUNT_ID`**.
4. Open **Manage account → [Account API tokens](https://dash.cloudflare.com/?to=/:account/api-tokens) → Create Token**. Under **Permission policies**, choose **Edit Cloudflare Workers** from the **Custom** dropdown and restrict account resources to this account. Keep the template's Worker deployment permissions, including scripts, account/subdomain settings and Durable Objects where applicable. No custom DNS zone is needed. Store the private token as **`CLOUDFLARE_API_TOKEN`** in GitHub Actions secrets.

These credentials are used only by the separate backend workflow. Existing Apple/Loop signing secrets stay unchanged. Fix a deployment permission error on this restricted token rather than placing a Cloudflare global API key in the app.

## 3. Separate tester code

Use your password manager to generate a new random password of at least **32 characters**, without spaces. It must differ from your OpenAI key/Apple password. Save it privately for iPhone login and add it to GitHub Actions secrets as **`FOOD_TESTER_ACCESS_CODE`**.

The backend exchanges this code for a **30-minute token**. In **0.3.0**, enter the code once: Loop+ stores the tester code, URL and token in its own device-only Keychain, accessible while unlocked and without iCloud synchronization. It renews authorization automatically using the saved code. The code is never compiled into the app; the OpenAI API key stays on the server. **Forget saved login** cancels pending authorization and removes the saved connection. Rotating the server code revokes existing sessions and requires entering the new code once. Its holder can spend the prototype's limited credits, so keep it private. The older 0.2.0 app stored only the token/URL and could not renew without re-entry.

## 4. Publish the prepared backend

After these four secrets exist, tell the assistant **“The four AI secrets are saved.”** Include no values. The assistant can set `Backend/request.json` to `deploy`, increase the revision and push only **`feature/ai-food-recognition`**. This starts [the separate backend workflow](https://github.com/jhardorp/LoopWorkspace/actions/workflows/food_recognition_backend.yml) without merging to `main`. The owner's first publication is complete in the run linked above; it does not need to be repeated to connect the app.

Checks run first. The job publishes only **`loop-plus-meal-review`**, passes its two secrets to Wrangler through stdin, then verifies `/health`. The summary reports the HTTPS server address:

```text
https://loop-plus-meal-review.YOUR-SUBDOMAIN.workers.dev
```

A health check verifies configuration, not paid OpenAI access or accuracy. Deployment never analyzes a photo or buys credits. The initial request is `validate_only`; ordinary source commits do not publish. If disabled, enable only this separate workflow and push a new request revision.

The separate `check_configuration` operation reports which of the four Actions secrets are present and checks their basic formats. It prints names/status only, makes no provider/Cloudflare request and does not publish. This can locate a missing secret without granting the assistant access to secret values. A successful status check does not prove the credentials have access to the provider accounts.

## 5. Update Loop+ and try one photo

When the separate **0.3.0** upload is confirmed and Apple processing finishes, update **Loop+** in TestFlight. Keep the original Loop app separate. This update adds remembered login and uses the already deployed backend; it needs no server re-deployment.

1. Select **OpenAI photo analysis**, enter your tester password once and tap **Connect to AI service**. The deployed address is prefilled under **Service settings**. A 0.2.0 upgrade keeps its saved address but needs the password once because the old version did not save it. Routine use/relaunch renews authorization automatically; only forgetting the login, changing/revoking the password or losing the device's saved credentials requires new setup.
2. Tap **Photograph meal**, photograph the actual meal with a portion reference and inspect the preview. Tap **Analyze this photo** only when you want this image uploaded to the backend/OpenAI.
3. Review foods/portions, carbs and the **experimental** absorption duration. Edit both values and acknowledge uncertainty. Finishing/discarding stays entirely in this standalone review; nothing goes to Loop or calculates/delivers insulin.

The first consented photo verifies live provider access. Tests use simulated replies and do not establish recognition accuracy. Nutrition is inferred rather than grounded in a verified database; weighing portions and checking recipes/labels remain necessary.

## Cost, limits and privacy

- **1,000 photos per UTC day** by default, shared across sessions, and **60 per minute**. Persistent SQLite counters serialize concurrent requests. `DAILY_PHOTO_LIMIT` and `MINUTE_PHOTO_LIMIT` are configurable; accepted ranges are 1–100,000 per day and 1–1,000 per minute. The health endpoint reports the effective limits. Raising them applies to existing counters without waiting for a day/minute reset.
- One provider request per accepted image, no automatic retry. JPEGs are capped at 1 MiB, replies at 256 KiB and output at 4,000 tokens. Charges follow [OpenAI API pricing](https://openai.com/api/pricing/) for the image-capable `gpt-4.1-2025-04-14` snapshot. Billing is based on tokens, not a fixed picture fee.
- Accepted images consume quota even if the provider fails, times out, refuses or returns invalid JSON; some may still be billed. Cancellation cannot retract a received photo or guarantee a refund.
- Workers Free and **SQLite** Durable Objects have free-tier limits; this configuration never upgrades the account automatically. If limits are reached the app reports failure. Counters store time windows/counts and salted login-IP digests, never photos, estimates, raw IPs or meal history.
- The app/backend do not persist photos/reviews. Worker observability, enabled by the owner for troubleshooting, records operational request metadata; application code logs no photo content, reviews or credentials. Network/provider services can also retain operational metadata under their policies.
- OpenAI receives only the current normalized photo and fixed prompt, with no CGM, prior meals, insulin, profile or dosing data. `store: false` does not eliminate default abuse-monitoring retention (normally up to 30 days) or other policy-governed retention. Read [OpenAI's data controls](https://developers.openai.com/api/docs/guides/your-data) before consent.
- Disable requests by revoking the OpenAI key/removing its Worker secret, rotating the tester code or deleting this separate Worker. No Loop/signing/dosing change is required.

## Developer checks

```sh
npm ci
npm run check
npm test
npx --no-install wrangler deploy --dry-run
```

Wrangler is pinned in `package-lock.json`. Tests stub paid calls and cover auth, expiry/revocation, bounds, validation, timeouts/errors and quota concurrency/reset. Credentials are unnecessary for these checks.

The runtime regression test also runs the actual handler in Cloudflare's local `workerd` runtime with simulated outbound responses. It covers a successful provider response and rejection of 302/307 redirects without following them or retrying. The provider fetch uses `redirect: "manual"`: `redirect: "error"` is unsupported by this runtime and otherwise causes an immediate 503 before any OpenAI request. Runtime tests require local loopback sockets; the separate GitHub Actions workflow runs them before deployment. They make no paid requests.

References: [image input](https://developers.openai.com/api/docs/guides/images-vision), [structured output](https://developers.openai.com/api/docs/guides/structured-outputs), [separate API billing](https://help.openai.com/en/articles/9039756-managing-billing-for-chatgpt-and-the-api-platform), [Worker secrets](https://developers.cloudflare.com/workers/configuration/secrets/), [Durable Objects pricing/SQLite Free](https://developers.cloudflare.com/durable-objects/platform/pricing/).
