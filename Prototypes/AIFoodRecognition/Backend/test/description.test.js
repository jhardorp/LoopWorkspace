import { test } from "node:test";
import assert from "node:assert/strict";
import { makeHandler, PrototypeQuota } from "../src/worker.js";
import { issueSession } from "../src/auth.js";
import { validateAssessment } from "../src/contract.js";
import { MAX_DESCRIPTION_BYTES } from "../src/description.js";

const origin = "https://meal-review.example.workers.dev", now = 1780000000;
const code = "description-test-only-access-code-not-for-real-use";
const quantity = (value, lower = value * 0.8, upper = value * 1.2) => ({ value, lower, upper });
const assessment = (count = 1) => ({ status: "estimate", reason: "", estimate: {
  foods: [{ name: "Honey", portionDescription: `${count} level tablespoons, assumed 15 ml each`,
    portionGrams: quantity(21 * count), carbohydrateGrams: quantity(17 * count), fatGrams: 0, proteinGrams: 0,
    fiberGrams: 0, carbohydrateType: "Sugars", glycemicCharacteristics: "Rapid availability; composition uncertain" }],
  carbohydrateGrams: quantity(17 * count), absorptionMinutes: quantity(60, 30, 90), confidence: "low",
  assumptions: ["Synthetic test fixture; level tablespoon and density assumed"], absorptionRationale: "Experimental unvalidated range",
} });
const providerReply = (value) => new Response(JSON.stringify({ status: "completed", output: [
  { type: "message", content: [{ type: "output_text", text: JSON.stringify(value) }] },
] }));
function environment(limit = 1000) {
  const values = new Map();
  const storage = { async get(key) { return structuredClone(values.get(key)); },
    async put(key, value) { values.set(key, structuredClone(value)); }, async transaction(fn) { return fn(this); } };
  const env = { OPENAI_API_KEY: "sk-description-test-only-key", TESTER_ACCESS_CODE: code, DAILY_PHOTO_LIMIT: limit };
  const quota = new PrototypeQuota({ storage }, env, () => now);
  env.QUOTA = { idFromName: (name) => name, get: () => ({ fetch: (url, init) => quota.fetch(new Request(url, init)) }) };
  return { env, values };
}
async function request(body = { description: "one tablespoon of honey" }, authenticated = true, headers = {}) {
  const { token } = await issueSession(code, origin, now);
  return new Request(`${origin}/v1/describe`, { method: "POST", headers: {
    "Content-Type": "application/json", ...(authenticated ? { Authorization: `Bearer ${token}` } : {}), ...headers,
  }, body: typeof body === "string" ? body : JSON.stringify(body) });
}

test("description-only estimate sends no image, uses the validated contract and retains low confidence", async () => {
  const { env, values } = environment(); let calls = 0;
  const run = makeHandler({ now: () => now, providerFetch: async (_, init) => {
    calls++; const body = JSON.parse(init.body), content = body.input[0].content;
    assert.equal(content.length, 1); assert.equal(content[0].type, "input_text");
    assert.equal(JSON.parse(content[0].text).description, "one tablespoon of honey");
    assert.match(body.instructions, /there is NO image/); assert.match(body.instructions, /Never claim to have seen a photo/);
    assert.equal(body.store, false); assert.equal(body.background, false); assert.equal(body.text.format.strict, true);
    return providerReply(assessment());
  } });
  const response = await run(await request(), env), result = await response.json();
  assert.equal(response.status, 200); assert.equal(result.estimate.carbohydrateGrams.value, 17);
  assert.equal(result.estimate.confidence, "low"); assert.match(result.estimate.provenance, /no photo/);
  assert.equal(calls, 1); assert.equal(values.get("counters").photos, 1);
  assert.ok(!JSON.stringify([...values]).includes("honey"));
});

test("text refinement preserves the description and ordered corrections without manufacturing an image", async () => {
  const { env } = environment();
  const previousEstimate = validateAssessment(assessment(), "test-model").estimate;
  const refinement = { previousEstimate, comments: ["Two tablespoons", "They are heaped"], question: "Level or heaped?" };
  const run = makeHandler({ now: () => now, providerFetch: async (_, init) => {
    const content = JSON.parse(init.body).input[0].content;
    assert.equal(content.length, 1);
    const context = JSON.parse(content[0].text);
    assert.equal(context.description, "one tablespoon of honey");
    assert.deepEqual(context.comments, refinement.comments); assert.equal(context.question, refinement.question);
    assert.equal(context.previousEstimate.carbohydrateGrams.value, 17);
    return providerReply(assessment(2));
  } });
  const response = await run(await request({ description: "one tablespoon of honey", refinement }), env);
  assert.equal(response.status, 200); assert.equal((await response.json()).estimate.carbohydrateGrams.value, 34);
});

test("invalid descriptions, extra therapy data and malformed contexts never reach the provider or quota", async () => {
  const { env, values } = environment();
  const run = makeHandler({ now: () => now, providerFetch: () => assert.fail("No provider call") });
  for (const body of [{ description: " " }, { description: "é".repeat(1025) }, { description: 3 },
    { description: "honey", glucose: 100 }, { description: "honey", imageBase64: "/9j/2Q==" },
    { description: "honey", refinement: null }, { description: "honey", refinement: { comments: [] } }, "not-json"]) {
    assert.equal((await run(await request(body), env)).status, 422);
  }
  const { token } = await issueSession(code, origin, now);
  const invalidUTF8 = new Request(`${origin}/v1/describe`, { method: "POST", headers: {
    "Content-Type": "application/json", Authorization: `Bearer ${token}` }, body: new Uint8Array([255]) });
  assert.equal((await run(invalidUTF8, env)).status, 422);
  assert.equal(values.get("counters"), undefined);
});

test("description bodies are bounded and require JSON and the existing session", async () => {
  const { env } = environment();
  const run = makeHandler({ now: () => now, providerFetch: () => assert.fail("No provider call") });
  assert.equal((await run(await request(undefined, false), env)).status, 401);
  assert.equal((await run(await request(undefined, true, { "Content-Type": "image/jpeg" }), env)).status, 400);
  assert.equal((await run(await request("x".repeat(MAX_DESCRIPTION_BYTES + 1)), env)).status, 413);
  assert.equal((await run(await request(undefined, true, { "Content-Length": String(MAX_DESCRIPTION_BYTES + 1) }), env)).status, 413);
});

test("photos, descriptions and text refinements consume the same request budget", async () => {
  const { env } = environment(2); let calls = 0;
  const run = makeHandler({ now: () => now, providerFetch: async () => { calls++; return providerReply(assessment()); } });
  assert.equal((await run(await request(), env)).status, 200);
  const { token } = await issueSession(code, origin, now);
  const photo = new Request(`${origin}/v1/estimate`, { method: "POST", headers: {
    "Content-Type": "image/jpeg", Authorization: `Bearer ${token}` }, body: new Uint8Array([255, 216, 255, 217]) });
  assert.equal((await run(photo, env)).status, 200);
  const refinement = { previousEstimate: validateAssessment(assessment(), "test-model").estimate, comments: ["Two spoons"], question: "" };
  assert.equal((await run(await request({ description: "honey", refinement }), env)).status, 429);
  assert.equal(calls, 2);
});

test("clarification, refusal, invalid estimates, errors and timeouts never return fallback numbers or retry", async () => {
  for (const kind of ["question", "refusal", "invalid", "error", "timeout"]) {
    const { env } = environment(); let calls = 0;
    const run = makeHandler({ now: () => now, timeoutMilliseconds: 1, providerFetch: async (_, init) => {
      calls++;
      if (kind === "timeout") return new Promise((resolve, reject) => init.signal.addEventListener("abort", () => reject(new Error("Timeout"))));
      if (kind === "error") return new Response("private error", { status: 503 });
      if (kind === "refusal") return new Response(JSON.stringify({ status: "completed", output: [
        { type: "message", content: [{ type: "refusal" }] },
      ] }));
      if (kind === "question") return providerReply({ status: "needsMoreInformation", estimate: null, reason: "How much?" });
      const value = assessment(); value.estimate.carbohydrateGrams.value = 100; return providerReply(value);
    } });
    const response = await run(await request(), env), result = await response.json();
    assert.equal(response.status, ["question", "refusal"].includes(kind) ? 200 : kind === "timeout" ? 504 : kind === "invalid" ? 502 : 503);
    assert.equal(result.estimate ?? null, null); assert.equal(calls, 1);
    assert.ok(!JSON.stringify(result).includes("sk-"));
    if (kind === "refusal") assert.doesNotMatch(result.reason, /image|photo/i);
  }
});
