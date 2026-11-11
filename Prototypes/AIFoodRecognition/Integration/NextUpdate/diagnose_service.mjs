import { readFileSync, writeFileSync, appendFileSync } from "node:fs";
import { validateAssessment } from "../../Backend/src/contract.js";

const env = process.env;
if (env.GITHUB_ACTIONS !== "true" || env.GITHUB_REPOSITORY !== "jhardorp/LoopWorkspace"
    || env.GITHUB_REF !== "refs/heads/migration/loop4-ai-photo") {
  throw new Error("Restricted to the owner's migration diagnostics");
}
const HOST = "https://loop-plus-meal-review.jan-1af.workers.dev";
const ACCOUNT = "a1af98f116246104f077ba72071d4dad";
const DEFAULT_MODEL = "gpt-4.1-2025-04-14";
const inputKind = env.AI_DIAGNOSTIC_INPUT === "photo" ? "photo" : "description";
const successDiagnosis = inputKind === "photo" ? "service_healthy_for_synthetic_photo" : "service_healthy_for_synthetic_description";
const codes = new Set(["insufficient_quota", "billing_hard_limit_reached", "invalid_api_key",
  "model_not_found", "rate_limit_exceeded", "account_deactivated", "permission_denied",
  "invalid_request_error", "invalidDescription", "invalidResponse", "rateLimited",
  "authenticationRequired", "serviceNotConfigured", "serviceUnavailable", "providerUnavailable",
  "timedOut", "notFound", "invalidRequest", "invalidPhoto"]);
const report = { checkedAt: new Date().toISOString(), source: env.GITHUB_SHA, host: HOST,
  inputKind, deploymentModified: false, appModified: false, personalMealDataSent: false,
  workerAnalysisRequests: 0, directProviderProbeRequests: 0, checks: [], diagnosis: "incomplete" };
function errorCode(body) {
  const candidate = typeof body?.error === "string" ? body.error : body?.error?.code;
  return codes.has(candidate) ? candidate : body?.error ? "unclassified_service_error" : null;
}
async function request(url, options = {}) {
  try {
    const { timeout = 20000, ...init } = options;
    const response = await fetch(url, { ...init, redirect: "error",
      signal: AbortSignal.timeout(timeout),
      headers: { "Accept": "application/json", "User-Agent": "LoopMealReviewServiceCheck/1.0", ...init.headers } });
    const reader = response.body?.getReader();
    const chunks = [];
    let length = 0;
    if (reader) {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        length += value.byteLength;
        if (length > 512 * 1024) { await reader.cancel(); return { status: response.status, body: null, failure: "response_too_large" }; }
        chunks.push(value);
      }
    }
    const data = Buffer.concat(chunks);
    let body = null;
    try { body = JSON.parse(data.toString("utf8")); } catch {}
    return { status: response.status, body, error: errorCode(body) };
  } catch (error) {
    return { status: null, body: null, failure: error.name === "TimeoutError" || error.name === "AbortError" ? "timeout" : "network_error" };
  }
}
function check(name, response, extra = {}) {
  const result = { name, httpStatus: response.status, ...extra };
  if (response.error) result.errorCode = response.error;
  if (response.failure) result.failure = response.failure;
  report.checks.push(result);
}
async function run() {
  const health = await request(HOST + "/health");
  check("worker_health", health, { ready: health.body?.status === "ready",
    descriptionFeature: health.body?.features?.mealDescription === true,
    photoRefinementFeature: health.body?.features?.mealRefinement === true });
  let model = DEFAULT_MODEL;
  if (env.CLOUDFLARE_ACCOUNT_ID === ACCOUNT && env.CLOUDFLARE_API_TOKEN) {
    const settings = await request("https://api.cloudflare.com/client/v4/accounts/" + ACCOUNT
      + "/workers/scripts/loop-plus-meal-review/settings",
      { headers: { Authorization: "Bearer " + env.CLOUDFLARE_API_TOKEN } });
    const bindings = Array.isArray(settings.body?.result?.bindings) ? settings.body.result.bindings : [];
    const serverModel = bindings.find(item => item.name === "OPENAI_MODEL")?.text;
    const knownModelShape = typeof serverModel === "string" && /^(gpt-|o[134](?:-|$))[A-Za-z0-9._-]{0,70}$/.test(serverModel);
    if (knownModelShape) model = serverModel;
    check("worker_binding_metadata", settings, {
      providerSecretPresent: bindings.some(item => item.type === "secret_text" && item.name === "OPENAI_API_KEY"),
      testerSecretPresent: bindings.some(item => item.type === "secret_text" && item.name === "TESTER_ACCESS_CODE"),
      modelIdentifierValid: knownModelShape });
  }
  report.model = model;
  const keyReady = typeof env.FOOD_OPENAI_API_KEY === "string" && /^sk-[A-Za-z0-9_-]{20,}$/.test(env.FOOD_OPENAI_API_KEY);
  if (keyReady) {
    const modelCheck = await request("https://api.openai.com/v1/models/" + encodeURIComponent(model),
      { headers: { Authorization: "Bearer " + env.FOOD_OPENAI_API_KEY } });
    check("repository_provider_model_access", modelCheck, { expectedModelReturned: modelCheck.body?.id === model });
  }
  const testerReady = typeof env.FOOD_TESTER_ACCESS_CODE === "string"
    && /^[\x21-\x7e]{32,256}$/.test(env.FOOD_TESTER_ACCESS_CODE)
    && !env.FOOD_TESTER_ACCESS_CODE.startsWith("sk-");
  let session = null, analysis = null;
  if (health.status === 200 && health.body?.status === "ready" && testerReady) {
    session = await request(HOST + "/v1/session", { method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ accessCode: env.FOOD_TESTER_ACCESS_CODE }) });
    const token = session.body?.token;
    const tokenValid = typeof token === "string" && token.length <= 2055
      && /^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test("Bearer " + token);
    check("worker_login", session, { validSessionReturned: session.status === 200 && tokenValid });
    if (session.status === 200 && tokenValid && (inputKind === "photo" || health.body?.features?.mealDescription === true)) {
      report.workerAnalysisRequests++;
      const photo = inputKind === "photo" ? readFileSync(env.RUNNER_TEMP + "/LoopSyntheticPhoto.jpg") : null;
      analysis = await request(HOST + (photo ? "/v1/estimate" : "/v1/describe"), { method: "POST", timeout: 65000,
        headers: { "Content-Type": photo ? "image/jpeg" : "application/json", Authorization: "Bearer " + token },
        body: photo ?? JSON.stringify({ description: "One level tablespoon of plain honey, one serving. No other food." }) });
      let validated = false;
      if (analysis.status === 200 && analysis.body?.schemaVersion === 1) {
        try {
          let estimate = analysis.body.estimate;
          if (estimate) { const { provenance, ...fields } = estimate; estimate = fields; }
          validateAssessment({ status: analysis.body.status, reason: analysis.body.reason, estimate }, model);
          validated = true;
        } catch {}
      }
      check(inputKind === "photo" ? "synthetic_photo_analysis" : "synthetic_description_analysis", analysis, {
        validResponse: validated,
        outcome: validated ? analysis.body.status : null });
      if (validated) report.diagnosis = successDiagnosis;
    }
  }
  let probe = null;
  if (report.diagnosis !== successDiagnosis && keyReady) {
    report.directProviderProbeRequests++;
    probe = await request("https://api.openai.com/v1/responses", {
      method: "POST", timeout: 45000,
      headers: { Authorization: "Bearer " + env.FOOD_OPENAI_API_KEY, "Content-Type": "application/json" },
      body: JSON.stringify({ model, input: "Reply with OK.", max_output_tokens: 16, store: false, background: false }) });
    check("minimal_repository_provider_probe", probe, { completed: probe.status === 200 && probe.body?.status === "completed" });
  }
  if (report.diagnosis === successDiagnosis) return;
  if (health.failure) report.diagnosis = "worker_network_or_timeout_failure";
  else if (health.status !== 200 || health.body?.status !== "ready") report.diagnosis = "worker_health_not_ready";
  else if (!testerReady) report.diagnosis = "repository_tester_credential_unavailable_or_invalid";
  else if (session?.status !== 200) report.diagnosis = session?.status === 429 ? "worker_login_throttled" : "worker_login_rejected_or_failed";
  else if (inputKind === "description" && health.body?.features?.mealDescription !== true) report.diagnosis = "deployed_description_feature_missing";
  else if (probe?.error === "insufficient_quota" || probe?.error === "billing_hard_limit_reached") report.diagnosis = "repository_openai_key_quota_or_billing_error";
  else if (probe?.status === 401) report.diagnosis = "repository_openai_key_authentication_error";
  else if (probe?.error === "model_not_found") report.diagnosis = "repository_openai_model_unavailable";
  else if (analysis?.status === 429) report.diagnosis = "worker_or_provider_request_limit";
  else if (analysis?.error === "invalidResponse") report.diagnosis = "meal_response_validation_failure";
  else report.diagnosis = "worker_analysis_failure_requires_followup";
}
try { await run(); } catch { report.diagnosis = "diagnostic_execution_failure"; }
writeFileSync(env.RUNNER_TEMP + "/AIServiceDiagnostic.json", JSON.stringify(report, null, 2) + "\n");
console.log("AI_SERVICE_DIAGNOSTIC: " + JSON.stringify(report));
if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY,
  "## Loop AI service diagnosis\n\nOnly sanitized HTTP/error codes and fixed synthetic inputs were used.\n\n"
  + "\u0060\u0060\u0060json\n" + JSON.stringify(report, null, 2) + "\n\u0060\u0060\u0060\n");
if (report.diagnosis !== successDiagnosis) process.exitCode = 1;
