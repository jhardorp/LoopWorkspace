import { test } from "node:test";
import assert from "node:assert/strict";
import { deploymentSettings } from "../scripts/deployment-settings.mjs";
import { makeHandler, PrototypeQuota, MAX_PHOTO_BYTES } from "../src/worker.js";
import { issueSession, validSession } from "../src/auth.js";
import { validateAssessment } from "../src/contract.js";

const origin = "https://meal-review.example.workers.dev";
const code = "a-test-only-access-code-never-used-on-a-server";
const seconds = 1780000000;
const jpeg = new Uint8Array([255, 216, 255, 217]);
const quantity = (value, lower, upper) => ({ value, lower, upper });
const assessment = () => ({
  status: "estimate", reason: "", estimate: {
    foods: [{ name: "Test-only toast fixture", portionDescription: "One illustrative slice", portionGrams: quantity(40, 25, 60),
      carbohydrateGrams: quantity(20, 12, 30), fatGrams: 2, proteinGrams: 4, fiberGrams: 3,
      carbohydrateType: "Whole-grain starch", glycemicCharacteristics: "Preparation and ingredients are uncertain." }],
    carbohydrateGrams: quantity(20, 12, 30), absorptionMinutes: quantity(180, 90, 300),
    confidence: "low", assumptions: ["The test fixture is not model accuracy evidence."],
    absorptionRationale: "Experimental duration based on grain, fiber, fat, protein and uncertain preparation.",
  },
});
const providerResult = (value = assessment()) => new Response(JSON.stringify({
  status: "completed", output: [{ type: "message", content: [{ type: "output_text", text: JSON.stringify(value) }] }],
}), { headers: { "Content-Type": "application/json" } });

class MemoryStorage {
  values = new Map();
  queue = Promise.resolve();
  async get(key) { return structuredClone(this.values.get(key)); }
  async put(key, value) { this.values.set(key, structuredClone(value)); }
  transaction(callback) {
    const result = this.queue.then(() => callback(this));
    this.queue = result.catch(() => {});
    return result;
  }
}

function environment(limit = 10, clock = () => seconds) {
  const env = { OPENAI_API_KEY: "sk-test-only-not-a-real-key", TESTER_ACCESS_CODE: code, DAILY_PHOTO_LIMIT: String(limit) };
  const storage = new MemoryStorage();
  const quota = new PrototypeQuota({ storage }, env, clock);
  env.QUOTA = { idFromName: (name) => name, get: () => ({ fetch: (url, init) => quota.fetch(new Request(url, init)) }) };
  return { env, storage, quota };
}

async function photoRequest({ accessCode = code, audience = origin, expiresNow = seconds, bytes = jpeg, contentType = "image/jpeg" } = {}) {
  const { token } = await issueSession(accessCode, audience, expiresNow);
  return new Request(`${origin}/v1/estimate`, { method: "POST", headers: { "Authorization": `Bearer ${token}`, "Content-Type": contentType }, body: bytes });
}
const handler = (providerFetch, options = {}) => makeHandler({ providerFetch, now: () => seconds, ...options });

test("health indicates setup required until secrets and persistent quota are configured", async () => {
  const run = handler(() => assert.fail("No model call is allowed"));
  assert.equal((await run(new Request(`${origin}/health`), {})).status, 503);
  const { env } = environment();
  const response = await run(new Request(`${origin}/health`), env);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { schemaVersion: 1, status: "ready", photoLimits: { perDay: 10, perMinute: 60 } });
});

test("login issues a 30 minute, origin-bound token without returning the access code or provider key", async () => {
  const { env } = environment();
  const run = handler(() => assert.fail("Login cannot call the model"));
  const request = new Request(`${origin}/v1/session`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ accessCode: code }) });
  const response = await run(request, env);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  const session = await response.json();
  assert.equal(session.expiresAt, seconds + 1800);
  assert.ok(await validSession(`Bearer ${session.token}`, code, origin, seconds));
  assert.equal(await validSession(`Bearer ${session.token}`, code, "https://another.example", seconds), false);
  assert.equal(await validSession(`Bearer ${session.token}`, code + "rotated", origin, seconds), false);
  assert.equal(await validSession(`Bearer ${session.token}`, code, origin, seconds + 1800), false);
  assert.ok(!JSON.stringify(session).includes(code));
  assert.ok(!JSON.stringify(session).includes(env.OPENAI_API_KEY));
});

test("wrong access codes and extra login fields are rejected", async () => {
  const { env } = environment();
  const run = handler(() => assert.fail("No provider request"));
  for (const [body, status] of [[{ accessCode: "wrong" }, 401], [{ accessCode: code, glucose: 100 }, 400]]) {
    const response = await run(new Request(`${origin}/v1/session`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) }), env);
    assert.equal(response.status, status);
  }
});

test("missing, tampered, expired and other-origin sessions cannot call OpenAI", async () => {
  const { env } = environment();
  const run = handler(() => assert.fail("No paid request is allowed"));
  const { token } = await issueSession(code, origin, seconds);
  const requests = [
    new Request(`${origin}/v1/estimate`, { method: "POST", body: jpeg }),
    new Request(`${origin}/v1/estimate`, { method: "POST", headers: { Authorization: `Bearer ${token.slice(0, -1)}!` }, body: jpeg }),
    await photoRequest({ expiresNow: seconds - 1800 }), await photoRequest({ audience: "https://other.example" }),
  ];
  for (const request of requests) assert.equal((await run(request, env)).status, 401);
});

test("successful real transport uses current image only, structured output, bounded tokens and store false", async () => {
  const { env, storage } = environment();
  let calls = 0;
  const run = handler(async (url, init) => {
    calls++;
    assert.equal(url, "https://api.openai.com/v1/responses");
    assert.equal(init.headers.Authorization, `Bearer ${env.OPENAI_API_KEY}`);
    assert.equal(init.redirect, "manual");
    const body = JSON.parse(init.body);
    assert.equal(body.store, false);
    assert.equal(body.background, false);
    assert.equal(body.max_output_tokens, 4000);
    assert.equal(body.text.format.strict, true);
    assert.equal(body.input.length, 1);
    assert.equal(body.input[0].content[1].image_url, "data:image/jpeg;base64,/9j/2Q==");
    assert.equal(body.previous_response_id, undefined);
    assert.ok(!init.body.includes(code));
    return providerResult();
  });
  const response = await run(await photoRequest(), env);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.schemaVersion, 1);
  assert.equal(body.estimate.confidence, "low");
  assert.match(body.estimate.provenance, /not database verified/);
  assert.equal(calls, 1);
  const counters = JSON.stringify(await storage.get("counters"));
  assert.ok(!counters.includes("toast") && !counters.includes("/9j/2Q=="));
});

test("wrong media type, invalid JPEG and oversize streamed bodies never reach the model", async () => {
  const { env } = environment();
  const run = handler(() => assert.fail("Invalid input cannot cause a paid request"));
  assert.equal((await run(await photoRequest({ contentType: "application/json" }), env)).status, 415);
  assert.equal((await run(await photoRequest({ bytes: new Uint8Array([1, 2, 3, 4]) }), env)).status, 415);
  assert.equal((await run(await photoRequest({ bytes: new Uint8Array(MAX_PHOTO_BYTES + 1) }), env)).status, 413);
});

test("clarification and model refusal return no numerical fallback", async () => {
  const { env } = environment();
  const value = { status: "needsMoreInformation", reason: "Please show the portion and recipe.", estimate: null };
  const response = await handler(async () => providerResult(value))(await photoRequest(), env);
  assert.deepEqual(await response.json(), { schemaVersion: 1, ...value });
  const refusal = new Response(JSON.stringify({ status: "completed", output: [{ type: "message", content: [{ type: "refusal", refusal: "No" }] }] }));
  const response2 = await handler(async () => refusal)(await photoRequest(), env);
  assert.equal((await response2.json()).estimate, null);
});

test("malformed, inconsistent and truncated provider replies are discarded", async () => {
  for (const type of ["total", "negative", "empty", "range", "highConfidence", "extra", "incomplete", "nonJSON"]) {
    const { env } = environment();
    const value = assessment();
    if (type === "total") value.estimate.carbohydrateGrams.value = 1;
    if (type === "negative") value.estimate.foods[0].fatGrams = -1;
    if (type === "empty") value.estimate.foods = [];
    if (type === "range") value.estimate.absorptionMinutes.upper = 100;
    if (type === "highConfidence") value.estimate.confidence = "high";
    if (type === "extra") value.estimate.glucose = 100;
    let result = providerResult(value);
    if (type === "incomplete") result = new Response(JSON.stringify({ status: "incomplete", output: [] }));
    if (type === "nonJSON") result = new Response("not JSON");
    const response = await handler(async () => result)(await photoRequest(), env);
    assert.equal(response.status, type === "nonJSON" ? 503 : 502, type);
    assert.equal((await response.json()).estimate, undefined);
  }
});

test("provider errors are sanitized, not retried and never reveal a key", async () => {
  for (const status of [401, 429, 500]) {
    const { env } = environment();
    let calls = 0;
    const run = handler(async () => { calls++; return new Response(env.OPENAI_API_KEY, { status }); });
    const response = await run(await photoRequest(), env);
    assert.equal(response.status, status === 429 ? 429 : 503);
    assert.equal(calls, 1);
    assert.ok(!(await response.text()).includes(env.OPENAI_API_KEY));
  }
});

test("timeout aborts the model request without a retry", async () => {
  const { env } = environment();
  let calls = 0;
  const run = handler(async (_, init) => {
    calls++;
    return new Promise((_, reject) => init.signal.addEventListener("abort", () => reject(new Error("aborted")), { once: true }));
  }, { timeoutMilliseconds: 5 });
  assert.equal((await run(await photoRequest(), env)).status, 504);
  assert.equal(calls, 1);
});

test("global daily quota persists and caps calls across concurrent requests and new sessions", async () => {
  const { env } = environment(2);
  let calls = 0;
  const run = handler(async () => { calls++; return providerResult(); });
  const responses = await Promise.all(await Promise.all(Array.from({ length: 5 }, async () => run(await photoRequest(), env))));
  assert.equal(calls, 2);
  assert.equal(responses.filter((response) => response.status === 429).length, 3);
});

test("rate limits survive new minute windows; daily counters reset only on a new UTC day", async () => {
  let time = seconds;
  const { env, quota } = environment(2, () => time);
  env.MINUTE_PHOTO_LIMIT = "1";
  const request = () => new Request("https://quota/consume", { method: "POST", body: JSON.stringify({ kind: "estimate", identity: "" }) });
  assert.equal((await quota.fetch(request())).status, 200);
  assert.equal((await quota.fetch(request())).status, 429);
  time += 60;
  assert.equal((await quota.fetch(request())).status, 200);
  time += 60;
  assert.equal((await quota.fetch(request())).status, 429);
  time = (Math.floor(time / 86400) + 1) * 86400;
  assert.equal((await quota.fetch(request())).status, 200);
});

test("login brute-force attempts are limited without storing raw client IPs", async () => {
  const { env, storage } = environment();
  const run = handler(() => assert.fail("No model call"));
  for (let index = 0; index < 6; index++) {
    const response = await run(new Request(`${origin}/v1/session`, { method: "POST", headers: { "Content-Type": "application/json", "CF-Connecting-IP": "192.0.2.1" }, body: JSON.stringify({ accessCode: "wrong" }) }), env);
    assert.equal(response.status, index < 5 ? 401 : 429);
  }
  assert.ok(!JSON.stringify(await storage.get("counters")).includes("192.0.2.1"));
});

test("out-of-range quota configuration fails closed", async () => {
  for (const [setting, value] of [
    ["DAILY_PHOTO_LIMIT", "100001"], ["DAILY_PHOTO_LIMIT", "0"], ["DAILY_PHOTO_LIMIT", "1.5"],
    ["MINUTE_PHOTO_LIMIT", "1001"], ["MINUTE_PHOTO_LIMIT", "0"], ["MINUTE_PHOTO_LIMIT", "not-a-number"],
  ]) {
    const { env } = environment();
    env[setting] = value;
    const response = await handler(() => assert.fail("No model call"))(await photoRequest(), env);
    assert.equal(response.status, 503, `${setting}=${value}`);
  }
});

test("generous defaults allow 60 concurrent photos and report the daily budget", async () => {
  const { env, quota, storage } = environment();
  delete env.DAILY_PHOTO_LIMIT;
  const health = await handler(() => assert.fail("No model call"))(new Request(`${origin}/health`), env);
  assert.deepEqual(await health.json(), { schemaVersion: 1, status: "ready", photoLimits: { perDay: 1000, perMinute: 60 } });
  const request = () => new Request("https://quota/consume", { method: "POST", body: JSON.stringify({ kind: "estimate", identity: "" }) });
  const responses = await Promise.all(Array.from({ length: 65 }, () => quota.fetch(request())));
  assert.equal(responses.filter(response => response.status === 200).length, 60);
  assert.equal(responses.filter(response => response.status === 429).length, 5);
  assert.equal((await storage.get("counters")).photos, 60);
});

test("raising limits immediately admits a photo after the old budgets were exhausted", async () => {
  const { env, storage } = environment(1000);
  env.MINUTE_PHOTO_LIMIT = "60";
  await storage.put("counters", {
    day: Math.floor(seconds / 86400), photos: 10, minute: Math.floor(seconds / 60),
    photoMinute: 3, loginMinute: 0, identities: {},
  });
  const recreated = new PrototypeQuota({ storage }, env, () => seconds);
  const response = await recreated.fetch(new Request("https://quota/consume", {
    method: "POST", body: JSON.stringify({ kind: "estimate", identity: "" }),
  }));
  assert.equal(response.status, 200);
  const counters = await storage.get("counters");
  assert.equal(counters.photos, 11);
  assert.equal(counters.photoMinute, 4);
});

test("validated model output and provenance do not accept model-supplied extra fields", () => {
  const valid = validateAssessment(assessment(), "test-model");
  assert.equal(valid.estimate.carbohydrateGrams.value, 20);
  const invalid = assessment();
  invalid.estimate.provenance = "Clinically validated";
  assert.throws(() => validateAssessment(invalid, "test-model"));
});

test("provider responses are bounded while streaming", async () => {
  const { env } = environment();
  const response = await handler(async () => new Response("x".repeat(256 * 1024 + 1)))(await photoRequest(), env);
  assert.equal(response.status, 503);
});

test("deployment refuses missing secrets, other branches and malformed credentials before publishing", () => {
  const configured = {
    CLOUDFLARE_API_TOKEN: "test-only-not-a-real-token",
    CLOUDFLARE_ACCOUNT_ID: "a".repeat(32),
    FOOD_OPENAI_API_KEY: "sk-test-only-not-a-real-project-key",
    FOOD_TESTER_ACCESS_CODE: code,
    GITHUB_ACTIONS: "true", GITHUB_REPOSITORY: "jhardorp/LoopWorkspace",
    GITHUB_REF: "refs/heads/feature/ai-food-recognition",
  };
  const cases = [
    [{}, "Add these GitHub Actions secrets"],
    [{ ...configured, GITHUB_REF: "refs/heads/main" }, "restricted"],
    [{ ...configured, GITHUB_REPOSITORY: "another-owner/another-repo" }, "restricted"],
    [{ ...configured, CLOUDFLARE_ACCOUNT_ID: "invalid" }, "account ID"],
    [{ ...configured, FOOD_OPENAI_API_KEY: "invalid" }, "project API key"],
    [{ ...configured, FOOD_TESTER_ACCESS_CODE: "short" }, "separate random"],
    [{ ...configured, FOOD_TESTER_ACCESS_CODE: configured.FOOD_OPENAI_API_KEY }, "separate random"],
  ];
  for (const [environment, message] of cases) {
    assert.throws(() => deploymentSettings(environment), (error) => {
      assert.ok(error.message.includes(message));
      assert.ok(!error.message.includes(configured.FOOD_OPENAI_API_KEY));
      assert.ok(!error.message.includes(code));
      return true;
    });
  }
  assert.equal(deploymentSettings(configured).account, configured.CLOUDFLARE_ACCOUNT_ID);
});
