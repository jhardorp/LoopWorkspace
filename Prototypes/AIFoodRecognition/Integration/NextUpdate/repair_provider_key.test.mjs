import test from "node:test";
import assert from "node:assert/strict";
import { checkOrRepair } from "./repair_provider_key.mjs";

const key = "sk-test_" + "x".repeat(32);
const environment = { GITHUB_ACTIONS: "true", GITHUB_REPOSITORY: "jhardorp/LoopWorkspace",
  GITHUB_REF: "refs/heads/migration/loop4-ai-photo", GITHUB_SHA: "test-source",
  CLOUDFLARE_ACCOUNT_ID: "a1af98f116246104f077ba72071d4dad", CLOUDFLARE_API_TOKEN: "test-cf-token",
  FOOD_OPENAI_API_KEY: key, OWNER_AUTHORIZED_KEY_REPAIR: "REPAIR_LOOP_AI_OPENAI_KEY" };
const bindings = [
  { name: "OPENAI_API_KEY", type: "secret_text" }, { name: "TESTER_ACCESS_CODE", type: "secret_text" },
  { name: "QUOTA", type: "durable_object_namespace", class_name: "PrototypeQuota", namespace_id: "kept-namespace" },
  { name: "OPENAI_MODEL", type: "plain_text", text: "gpt-4.1-2025-04-14" },
  { name: "DAILY_PHOTO_LIMIT", type: "plain_text", text: "1000" },
  { name: "MINUTE_PHOTO_LIMIT", type: "plain_text", text: "60" },
];
function fake({ providerStatus = 200, changeAfter = false, throwSecret = false } = {}) {
  const calls = [];
  let reads = 0;
  const fetcher = async (url, options) => {
    calls.push({ url, method: options.method || "GET", body: options.body });
    if (throwSecret) throw new Error("must-never-log-" + key);
    let status = 200, body;
    if (url.endsWith("/settings")) {
      reads++;
      const values = structuredClone(bindings);
      if (changeAfter && reads > 1) values.find(x => x.name === "QUOTA").namespace_id = "unexpected";
      body = { success: true, result: { bindings: values } };
    } else if (url.endsWith("/responses")) {
      status = providerStatus;
      body = status === 200 ? { status: "completed" }
        : { error: { code: "invalid_api_key", type: "authentication_error", message: key } };
    } else if (url.endsWith("/secrets")) body = { success: true };
    else throw new Error("Unexpected request");
    return { status, json: async () => body };
  };
  return { calls, fetcher };
}
test("a rejected OpenAI key never changes a server secret or exposes its value", async () => {
  const f = fake({ providerStatus: 401 });
  const result = await checkOrRepair({ operation: "repair", environment, fetcher: f.fetcher });
  assert.equal(result.issue, "provider_authentication_rejected");
  assert.equal(result.secretUpdated, false);
  assert.equal(f.calls.some(x => x.method === "PUT"), false);
  assert.equal(JSON.stringify(result).includes(key), false);
});
test("check mode verifies the key without changing a server secret", async () => {
  const f = fake();
  const result = await checkOrRepair({ operation: "check", environment, fetcher: f.fetcher });
  assert.equal(result.providerVerified, true);
  assert.equal(result.secretUpdated, false);
  assert.equal(f.calls.some(x => x.method === "PUT"), false);
});
test("authorized repair changes only OPENAI_API_KEY after the provider probe succeeds", async () => {
  const f = fake();
  const result = await checkOrRepair({ operation: "repair", environment, fetcher: f.fetcher });
  assert.equal(result.issue, null);
  assert.equal(result.secretUpdated, true);
  assert.equal(result.configurationUnchanged, true);
  const writes = f.calls.filter(x => x.method === "PUT");
  assert.equal(writes.length, 1);
  assert.deepEqual(JSON.parse(writes[0].body), { name: "OPENAI_API_KEY", type: "secret_text", text: key });
  assert.ok(f.calls.findIndex(x => x.url.endsWith("/responses")) < f.calls.findIndex(x => x.method === "PUT"));
});
test("repair without owner authorization makes no requests", async () => {
  const f = fake();
  const result = await checkOrRepair({ operation: "repair",
    environment: { ...environment, OWNER_AUTHORIZED_KEY_REPAIR: "" }, fetcher: f.fetcher });
  assert.equal(result.issue, "owner_authorization_required");
  assert.equal(f.calls.length, 0);
});
test("an unexpected Cloudflare account makes no requests", async () => {
  const f = fake();
  const result = await checkOrRepair({ operation: "repair",
    environment: { ...environment, CLOUDFLARE_ACCOUNT_ID: "other" }, fetcher: f.fetcher });
  assert.equal(result.issue, "existing_cloudflare_access_required");
  assert.equal(f.calls.length, 0);
});
test("changed quota or binding metadata prevents a successful repair report", async () => {
  const f = fake({ changeAfter: true });
  const result = await checkOrRepair({ operation: "repair", environment, fetcher: f.fetcher });
  assert.equal(result.secretUpdated, true);
  assert.equal(result.issue, "configuration_changed_requires_followup");
  assert.equal(result.configurationUnchanged, false);
});
test("network failures never copy exception messages or key values into the report", async () => {
  const f = fake({ throwSecret: true });
  const result = await checkOrRepair({ operation: "repair", environment, fetcher: f.fetcher });
  assert.equal(result.secretUpdated, false);
  assert.equal(JSON.stringify(result).includes(key), false);
  assert.equal(JSON.stringify(result).includes("must-never-log"), false);
});
