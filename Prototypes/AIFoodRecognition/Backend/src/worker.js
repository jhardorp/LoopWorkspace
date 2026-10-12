import { Buffer } from "node:buffer";
import { instructions, modelSchema, validateAssessment } from "./contract.js";
import { issueSession, validSession, sameAccessCode, loginIdentity } from "./auth.js";

export const MAX_PHOTO_BYTES = 1024 * 1024;
const MAX_PROVIDER_BYTES = 256 * 1024;
const DEFAULT_MODEL = "gpt-4.1-2025-04-14";
const json = (value, status = 200, extra = {}) => new Response(JSON.stringify(value), {
  status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", ...extra },
});
const failure = (error, status) => json({ error }, status);
const dayLimit = (env) => {
  const value = Number(env.DAILY_PHOTO_LIMIT ?? 10);
  if (!Number.isInteger(value) || value < 1 || value > 20) throw new Error("Invalid daily quota");
  return value;
};
function configured(env) {
  return typeof env.OPENAI_API_KEY === "string" && env.OPENAI_API_KEY.startsWith("sk-")
    && typeof env.TESTER_ACCESS_CODE === "string" && /^[\x21-\x7e]{32,256}$/.test(env.TESTER_ACCESS_CODE)
    && !env.TESTER_ACCESS_CODE.startsWith("sk-") && env.QUOTA;
}

async function readBounded(body, limit) {
  if (!body) throw new Error("Missing body");
  const reader = body.getReader();
  const chunks = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > limit) throw new Error("Body exceeds limit");
      chunks.push(value);
    }
  } catch (error) { await reader.cancel(); throw error; }
  const result = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { result.set(chunk, offset); offset += chunk.byteLength; }
  return result;
}

async function consume(env, kind, identity = "") {
  const id = env.QUOTA.idFromName("single-owner-prototype-v1");
  const result = await env.QUOTA.get(id).fetch("https://quota/consume", {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ kind, identity }),
  });
  if (result.status !== 200) return result.status === 429 ? failure("rateLimited", 429) : failure("serviceUnavailable", 503);
  return null;
}

export function makeHandler({ providerFetch = fetch, now = () => Math.floor(Date.now() / 1000), timeoutMilliseconds = 35000 } = {}) {
  return async (request, env) => {
    try {
      const url = new URL(request.url);
      if (url.protocol !== "https:" || url.search || url.hash) return failure("invalidRequest", 400);
      const ready = configured(env);
      if (request.method === "GET" && url.pathname === "/health") {
        if (!ready) return json({ schemaVersion: 1, status: "setupRequired" }, 503);
        dayLimit(env);
        return json({ schemaVersion: 1, status: "ready" });
      }
      if (request.method !== "POST" || !["/v1/session", "/v1/estimate"].includes(url.pathname)) return failure("notFound", 404);
      if (!ready) return failure("serviceNotConfigured", 503);
      dayLimit(env);
      if (url.pathname === "/v1/session") {
        const denied = await consume(env, "session", await loginIdentity(request, env.TESTER_ACCESS_CODE));
        if (denied) return denied;
        if (request.headers.get("Content-Type")?.split(";")[0].trim() !== "application/json") return failure("invalidRequest", 400);
        let body;
        try { body = JSON.parse(new TextDecoder().decode(await readBounded(request.body, 1024))); }
        catch { return failure("invalidRequest", 400); }
        if (!body || Object.keys(body).length !== 1 || !Object.hasOwn(body, "accessCode")) return failure("invalidRequest", 400);
        if (!await sameAccessCode(body.accessCode, env.TESTER_ACCESS_CODE)) return failure("authenticationRequired", 401);
        return json(await issueSession(env.TESTER_ACCESS_CODE, url.origin, now()));
      }
      if (!await validSession(request.headers.get("Authorization"), env.TESTER_ACCESS_CODE, url.origin, now())) return failure("authenticationRequired", 401);
      if (request.headers.get("Content-Type") !== "image/jpeg") return failure("invalidPhoto", 415);
      if (Number(request.headers.get("Content-Length")) > MAX_PHOTO_BYTES) return failure("invalidPhoto", 413);
      let bytes;
      try { bytes = await readBounded(request.body, MAX_PHOTO_BYTES); }
      catch { return failure("invalidPhoto", 413); }
      if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes.at(-2) !== 0xff || bytes.at(-1) !== 0xd9) return failure("invalidPhoto", 415);
      const denied = await consume(env, "estimate");
      if (denied) return denied;
      const model = env.OPENAI_MODEL || DEFAULT_MODEL;
      if (!/^[A-Za-z0-9._-]{1,80}$/.test(model)) return failure("serviceNotConfigured", 503);
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMilliseconds);
      let result;
      try {
        const response = await providerFetch("https://api.openai.com/v1/responses", {
          method: "POST", headers: { "Content-Type": "application/json", "Authorization": `Bearer ${env.OPENAI_API_KEY}` },
          // workerd supports manual/follow only. Reject redirects below instead of following them.
          redirect: "manual",
          signal: controller.signal,
          body: JSON.stringify({
            model, store: false, background: false, max_output_tokens: 4000,
            instructions,
            input: [{ role: "user", content: [
              { type: "input_text", text: "Analyze only this meal image. Return the structured estimate or a clarification request." },
              { type: "input_image", image_url: `data:image/jpeg;base64,${Buffer.from(bytes).toString("base64")}`, detail: "high" },
            ] }],
            text: { format: { type: "json_schema", name: "meal_review_v1", strict: true, schema: modelSchema } },
          }),
        });
        if (response.status === 429) return failure("rateLimited", 429);
        if (!response.ok) return failure("providerUnavailable", 503);
        result = JSON.parse(new TextDecoder().decode(await readBounded(response.body, MAX_PROVIDER_BYTES)));
      } catch {
        return failure(controller.signal.aborted ? "timedOut" : "providerUnavailable", controller.signal.aborted ? 504 : 503);
      } finally { clearTimeout(timer); }
      if (result.status !== "completed" || !Array.isArray(result.output)) return failure("invalidResponse", 502);
      const content = result.output.filter((item) => item.type === "message").flatMap((item) => item.content ?? []);
      if (content.some((item) => item.type === "refusal")) {
        return json({ schemaVersion: 1, status: "needsMoreInformation", estimate: null, reason: "The image could not be interpreted. Photograph just the meal and provide a clear portion view." });
      }
      try {
        const text = content.filter((item) => item.type === "output_text").map((item) => item.text).join("");
        return json(validateAssessment(JSON.parse(text), model));
      } catch { return failure("invalidResponse", 502); }
    } catch { return failure("serviceUnavailable", 503); }
  };
}

export default { fetch: makeHandler() };

/// Shared, transactional counters. Never stores images, estimates, raw IPs, glucose, or meal history.
export class PrototypeQuota {
  constructor(state, env, clock = () => Math.floor(Date.now() / 1000)) { this.storage = state.storage; this.env = env; this.clock = clock; }
  async fetch(request) {
    try {
      const body = await request.json();
      if (!["session", "estimate"].includes(body.kind) || typeof body.identity !== "string" || body.identity.length > 64) return failure("invalidRequest", 400);
      if (body.kind === "session" && !/^[0-9a-f]{64}$/.test(body.identity)) return failure("invalidRequest", 400);
      const now = this.clock(), day = Math.floor(now / 86400), minute = Math.floor(now / 60);
      const allowed = await this.storage.transaction(async (transaction) => {
        let state = await transaction.get("counters");
        if (!state || state.day !== day) state = { day, photos: 0, minute, photoMinute: 0, loginMinute: 0, identities: {} };
        if (state.minute !== minute) Object.assign(state, { minute, photoMinute: 0, loginMinute: 0, identities: {} });
        if (body.kind === "estimate") {
          if (state.photos >= dayLimit(this.env) || state.photoMinute >= 3) return false;
          state.photos++; state.photoMinute++;
        } else {
          const count = state.identities[body.identity] ?? 0;
          if (state.loginMinute >= 60 || count >= 5) return false;
          state.loginMinute++; state.identities[body.identity] = count + 1;
        }
        await transaction.put("counters", state);
        return true;
      });
      return allowed ? json({ allowed: true }) : failure("rateLimited", 429);
    } catch { return failure("serviceUnavailable", 503); }
  }
}
