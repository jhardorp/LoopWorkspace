import { test } from "node:test";
import assert from "node:assert/strict";
import { makeHandler, PrototypeQuota } from "../src/worker.js";
import { issueSession } from "../src/auth.js";
import { validateAssessment } from "../src/contract.js";

const origin = "https://meal-review.example.workers.dev", now = 1780000000;
const code = "refinement-test-only-access-code-not-for-real-use";
const jpeg = new Uint8Array([255, 216, 255, 217]);
const quantity = (value) => ({ value, lower: value * 0.8, upper: value * 1.2 });
const assessment = (count = 1) => ({ status: "estimate", reason: "", estimate: {
  foods: [{ name: "Bread", portionDescription: `${count} slices`, portionGrams: quantity(40 * count),
    carbohydrateGrams: quantity(20 * count), fatGrams: 2 * count, proteinGrams: 4 * count,
    fiberGrams: 3 * count, carbohydrateType: "Starch", glycemicCharacteristics: "Uncertain preparation" }],
  carbohydrateGrams: quantity(20 * count), absorptionMinutes: { value: 180, lower: 90, upper: 300 },
  confidence: "low", assumptions: ["Test fixture only"], absorptionRationale: "Experimental composition-based range",
} });
const previous = () => validateAssessment(assessment(), "test-model").estimate;
const payload = (comments = ["I eat two of those"]) => ({ imageBase64: Buffer.from(jpeg).toString("base64"),
  refinement: { previousEstimate: previous(), comments, question: "" } });
const providerReply = (result) => new Response(JSON.stringify({ status: "completed",
  output: [{ type: "message", content: [{ type: "output_text", text: JSON.stringify(result) }] }],
}));
function environment(limit = 1000) {
  const values = new Map();
  const storage = { async get(key) { return structuredClone(values.get(key)); },
    async put(key, value) { values.set(key, structuredClone(value)); },
    async transaction(callback) { return callback(this); } };
  const env = { OPENAI_API_KEY: "sk-test-not-real", TESTER_ACCESS_CODE: code, DAILY_PHOTO_LIMIT: limit };
  const quota = new PrototypeQuota({ storage }, env, () => now);
  env.QUOTA = { idFromName: (name) => name, get: () => ({ fetch: (url, init) => quota.fetch(new Request(url, init)) }) };
  return { env, values };
}
async function request(body = payload(), authenticated = true) {
  const { token } = await issueSession(code, origin, now);
  return new Request(`${origin}/v1/refine`, { method: "POST", headers: { "Content-Type": "application/json",
    ...(authenticated ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body) });
}

test("refinement sends the same photo, current estimate and ordered food comments, then returns revised totals", async () => {
  const comments = ["The bread slice is on the big side", "I eat two of those", "It is a Langnese Cornetto", "Banana is not ripe"];
  const { env, values } = environment();
  let calls = 0;
  const run = makeHandler({ now: () => now, providerFetch: async (_, init) => {
    calls++;
    const body = JSON.parse(init.body), context = JSON.parse(body.input[0].content[0].text);
    assert.deepEqual(context.comments, comments);
    assert.equal(context.previousEstimate.carbohydrateGrams.value, 20);
    assert.equal(body.input[0].content[1].image_url, "data:image/jpeg;base64,/9j/2Q==");
    assert.equal(body.store, false);
    assert.equal(body.previous_response_id, undefined);
    assert.equal(body.text.format.strict, true);
    assert.match(body.instructions, /later conflicting correction supersedes/);
    assert.match(body.instructions, /Recalculate totals/);
    return providerReply(assessment(2));
  } });
  const response = await run(await request(payload(comments)), env);
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.equal(result.estimate.carbohydrateGrams.value, 40);
  assert.equal(result.estimate.foods[0].portionDescription, "2 slices");
  assert.equal(calls, 1);
  assert.equal(values.get("counters").photos, 1);
  const stored = JSON.stringify([...values]);
  assert.ok(!stored.includes("Cornetto") && !stored.includes("/9j/2Q=="));
});

test("a clarification answer includes the prior question and still returns a complete validated result", async () => {
  const { env } = environment();
  const body = payload(["I eat two of those", "The bread slices"]);
  body.refinement.question = "Which item do you eat two of?";
  const run = makeHandler({ now: () => now, providerFetch: async (_, init) => {
    const context = JSON.parse(JSON.parse(init.body).input[0].content[0].text);
    assert.equal(context.question, body.refinement.question);
    assert.deepEqual(context.comments, body.refinement.comments);
    return providerReply(assessment(2));
  } });
  assert.equal((await run(await request(body), env)).status, 200);
});

test("refinement accepts a JPEG at the full supported photo size", async () => {
  const { env } = environment();
  const photo = new Uint8Array(1024 * 1024);
  photo[0] = 255; photo[1] = 216; photo[photo.length - 2] = 255; photo[photo.length - 1] = 217;
  const body = payload(); body.imageBase64 = Buffer.from(photo).toString("base64");
  const run = makeHandler({ now: () => now, providerFetch: async () => providerReply(assessment(2)) });
  assert.equal((await run(await request(body), env)).status, 200);
});

test("invalid refinement context, unknown inputs and invalid photos never consume quota or reach the provider", async () => {
  const { env, values } = environment();
  const run = makeHandler({ now: () => now, providerFetch: () => assert.fail("No provider call") });
  const cases = [
    (p) => { p.refinement.comments = [" "]; },
    (p) => { p.refinement.comments = ["é".repeat(1025)]; },
    (p) => { p.refinement.comments = Array(21).fill("large slice"); },
    (p) => { p.refinement.comments = Array(9).fill("x".repeat(2048)); },
    (p) => { p.refinement.previousEstimate.carbohydrateGrams.value = 100; },
    (p) => { p.refinement.previousEstimate.glucose = 100; },
    (p) => { p.history = []; },
    (p) => { p.imageBase64 = "invalid base64"; },
    (p) => { p.imageBase64 = Buffer.from([1, 2, 3, 4]).toString("base64"); },
  ];
  for (const mutate of cases) {
    const body = payload(); mutate(body);
    assert.equal((await run(await request(body), env)).status, 422);
  }
  assert.equal(values.get("counters"), undefined);
});

test("refinement requires authorization and shares the normal photo budget", async () => {
  const { env } = environment(1);
  let calls = 0;
  const run = makeHandler({ now: () => now, providerFetch: async () => { calls++; return providerReply(assessment(2)); } });
  assert.equal((await run(await request(payload(), false), env)).status, 401);
  const { token } = await issueSession(code, origin, now);
  const initial = new Request(`${origin}/v1/estimate`, { method: "POST", headers: {
    Authorization: `Bearer ${token}`, "Content-Type": "image/jpeg" }, body: jpeg });
  assert.equal((await run(initial, env)).status, 200);
  assert.equal((await run(await request(), env)).status, 429);
  assert.equal(calls, 1);
});

test("refinement failures and clarification return no manufactured updated numbers and do not retry", async () => {
  for (const kind of ["unavailable", "invalidTotal", "question"]) {
    const { env } = environment(); let calls = 0;
    const run = makeHandler({ now: () => now, providerFetch: async () => {
      calls++;
      if (kind === "unavailable") return new Response("private provider error", { status: 503 });
      if (kind === "question") return providerReply({ status: "needsMoreInformation", reason: "Which portion?", estimate: null });
      const body = assessment(2); body.estimate.carbohydrateGrams.value = 5;
      return providerReply(body);
    } });
    const response = await run(await request(), env);
    assert.equal(response.status, kind === "unavailable" ? 503 : kind === "invalidTotal" ? 502 : 200);
    assert.equal((await response.json()).estimate ?? null, null);
    assert.equal(calls, 1);
  }
});
