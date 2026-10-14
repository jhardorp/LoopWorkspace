import { spawnSync } from "node:child_process";
import { appendFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { deploymentSettings } from "./deployment-settings.mjs";

// Run only after the owner places credentials in GitHub Actions secret storage.
// Keys travel to Wrangler's stdin/server storage, never to files or the iPhone build.
function stop(message) { process.stderr.write(`${message}\n`); process.exit(1); }
let settings;
try { settings = deploymentSettings(process.env); } catch (error) { stop(error.message); }
const { account, openAIKey, testerCode } = settings;
const cli = fileURLToPath(new URL("../node_modules/wrangler/bin/wrangler.js", import.meta.url));
const cliEnvironment = { ...process.env };
delete cliEnvironment.FOOD_OPENAI_API_KEY;
delete cliEnvironment.FOOD_TESTER_ACCESS_CODE;
function wrangler(args, input) {
  const result = spawnSync(process.execPath, [cli, ...args], {
    env: cliEnvironment, input, stdio: [input ? "pipe" : "ignore", "inherit", "inherit"],
  });
  if (result.error || result.status !== 0) stop("The separate backend operation failed; inspect the Wrangler status above.");
}
wrangler(["deploy"]);
wrangler(["secret", "bulk"], JSON.stringify({
  OPENAI_API_KEY: openAIKey,
  TESTER_ACCESS_CODE: testerCode,
}));

try {
  const response = await fetch(`https://api.cloudflare.com/client/v4/accounts/${account}/workers/subdomain`, {
    headers: { Authorization: `Bearer ${process.env.CLOUDFLARE_API_TOKEN}` },
    signal: AbortSignal.timeout(10000), redirect: "error",
  });
  if (!response.ok) throw new Error();
  const result = await response.json();
  const subdomain = result.result?.subdomain;
  if (!result.success || typeof subdomain !== "string" || !/^[a-z0-9-]+$/.test(subdomain)) throw new Error();
  const address = `https://loop-plus-meal-review.${subdomain}.workers.dev`;
  const health = await fetch(`${address}/health`, { signal: AbortSignal.timeout(10000), redirect: "error" });
  const healthBody = await health.json();
  const limits = healthBody.photoLimits;
  if (!health.ok || healthBody.status !== "ready" || healthBody.features?.mealRefinement !== true
      || !Number.isSafeInteger(limits?.perDay) || limits.perDay < 1
      || !Number.isSafeInteger(limits?.perMinute) || limits.perMinute < 1) throw new Error();
  process.stdout.write(`Backend configuration verified: ${address}\n`);
  process.stdout.write(`Verified photo limits: ${limits.perDay} per UTC day, ${limits.perMinute} per minute\n`);
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY,
    `### Loop+ backend published\n\nServer address: **${address}**\n\nPhoto limits verified: **${limits.perDay} per UTC day and ${limits.perMinute} per minute**. Personal builds connect automatically. No OpenAI request was made by this health check; analysis starts after a camera capture.\n`);
} catch { stop("Publication commands completed, but the public health check was not verified. Check the Worker URL/status in Cloudflare before connecting the app."); }
