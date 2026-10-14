import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { Miniflare, convertV4MiniflareOptions } from "miniflare";

test("Cloudflare runtime sends the provider request and rejects redirects without following them", async () => {
  const root = fileURLToPath(new URL("../", import.meta.url));
  const config = JSON.parse(readFileSync(new URL("../wrangler.jsonc", import.meta.url), "utf8"));
  const accessCode = "runtime-test-only-access-code-never-used-on-a-server";
  const origin = "https://meal-review.example.workers.dev";
  const providerRequests = [];
  const providerBodies = [];
  let providerStatus = 200;
  const runtime = new Miniflare(convertV4MiniflareOptions({
    name: config.name, cf: false, modulesRoot: root,
    modules: [{
      type: "ESModule", path: `${root}runtime-test-entry.js`,
      contents: 'export { default, PrototypeQuota } from "./src/worker.js";',
    }, ...["worker.js", "auth.js", "contract.js", "refinement.js"].map((name) => ({
      type: "ESModule", path: `${root}src/${name}`,
      contents: readFileSync(new URL(`../src/${name}`, import.meta.url), "utf8"),
    }))],
    compatibilityDate: config.compatibility_date,
    compatibilityFlags: config.compatibility_flags,
    bindings: { ...config.vars, OPENAI_API_KEY: "sk-runtime-test-only-key", TESTER_ACCESS_CODE: accessCode },
    durableObjects: { QUOTA: { className: "PrototypeQuota", useSQLite: true } },
    outboundService: async (request) => {
      providerRequests.push({ url: request.url, authorization: request.headers.get("Authorization") });
      providerBodies.push(await request.json());
      return providerStatus === 200 ? new Response(JSON.stringify({
        status: "completed", output: [{ type: "message", content: [{ type: "output_text", text: JSON.stringify({
          status: "needsMoreInformation", estimate: null, reason: "Provide a clear portion view.",
        }) }] }],
      })) : new Response(null, { status: providerStatus, headers: { Location: "https://redirect.example/" } });
    },
  }));
  try {
    const login = await runtime.dispatchFetch(`${origin}/v1/session`, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ accessCode }),
    });
    assert.equal(login.status, 200);
    const { token } = await login.json();
    for (const status of [200, 302, 307]) {
      providerStatus = status;
      const before = providerRequests.length;
      const response = await runtime.dispatchFetch(`${origin}/v1/estimate`, {
        method: "POST", headers: { "Content-Type": "image/jpeg", Authorization: `Bearer ${token}` },
        body: new Uint8Array([255, 216, 255, 217]),
      });
      assert.equal(response.status, status === 200 ? 200 : 503, `Provider status ${status}`);
      assert.equal(providerRequests.length, before + 1, "Exactly one request, with no redirect or retry");
      assert.deepEqual(providerRequests.at(-1), {
        url: "https://api.openai.com/v1/responses", authorization: "Bearer sk-runtime-test-only-key",
      });
      const result = await response.json();
      assert.equal(status === 200 ? result.status : result.error, status === 200 ? "needsMoreInformation" : "providerUnavailable");
    }
    providerStatus = 200;
    const previousEstimate = {
      foods: [{ name: "Bread", portionDescription: "One slice", portionGrams: { value: 40, lower: 30, upper: 50 },
        carbohydrateGrams: { value: 20, lower: 15, upper: 25 }, fatGrams: 2, proteinGrams: 4, fiberGrams: 3,
        carbohydrateType: "Starch", glycemicCharacteristics: "Uncertain preparation" }],
      carbohydrateGrams: { value: 20, lower: 15, upper: 25 }, absorptionMinutes: { value: 180, lower: 90, upper: 300 },
      confidence: "low", assumptions: ["Runtime test fixture"], absorptionRationale: "Experimental range", provenance: "Test only",
    };
    const refined = await runtime.dispatchFetch(`${origin}/v1/refine`, {
      method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify({ imageBase64: "/9j/2Q==", refinement: { previousEstimate, comments: ["Two slices"], question: "" } }),
    });
    assert.equal(refined.status, 200);
    const context = JSON.parse(providerBodies.at(-1).input[0].content[0].text);
    assert.deepEqual(context.comments, ["Two slices"]);
    assert.equal(providerBodies.at(-1).input[0].content[1].image_url, "data:image/jpeg;base64,/9j/2Q==");
  } finally { await runtime.dispose(); }
});
