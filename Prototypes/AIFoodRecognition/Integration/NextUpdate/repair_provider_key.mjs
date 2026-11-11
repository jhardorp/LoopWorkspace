import { writeFileSync, appendFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const ACCOUNT = "a1af98f116246104f077ba72071d4dad";
const WORKER = "loop-plus-meal-review";
const MODEL = "gpt-4.1-2025-04-14";
const ROOT = "https://api.cloudflare.com/client/v4/accounts/" + ACCOUNT + "/workers/scripts/" + WORKER;
const identifier = value => typeof value === "string" && /^[A-Za-z][A-Za-z0-9_]{0,63}$/.test(value) ? value : null;

export async function checkOrRepair({ operation, environment, fetcher = fetch }) {
  const e = environment;
  const report = { source: e.GITHUB_SHA, checkedAt: new Date().toISOString(), operation,
    providerVerified: false, providerHttpStatus: null, secretUpdated: false,
    configurationUnchanged: null, appCodeChanged: false, issue: null };
  if (e.GITHUB_ACTIONS !== "true" || e.GITHUB_REPOSITORY !== "jhardorp/LoopWorkspace"
      || e.GITHUB_REF !== "refs/heads/migration/loop4-ai-photo") {
    report.issue = "wrong_execution_scope"; return report;
  }
  if (!["check", "repair"].includes(operation)) { report.issue = "invalid_operation"; return report; }
  if (operation === "repair" && e.OWNER_AUTHORIZED_KEY_REPAIR !== "REPAIR_LOOP_AI_OPENAI_KEY") {
    report.issue = "owner_authorization_required"; return report;
  }
  if (e.CLOUDFLARE_ACCOUNT_ID !== ACCOUNT || !e.CLOUDFLARE_API_TOKEN) {
    report.issue = "existing_cloudflare_access_required"; return report;
  }
  if (typeof e.FOOD_OPENAI_API_KEY !== "string" || !/^sk-[A-Za-z0-9_-]{20,}$/.test(e.FOOD_OPENAI_API_KEY)) {
    report.issue = "provider_credential_missing_or_invalid_format"; return report;
  }
  async function send(url, options = {}) {
    try {
      const response = await fetcher(url, { ...options, redirect: "error", signal: AbortSignal.timeout(45000) });
      let body = null;
      try { body = await response.json(); } catch {}
      return { status: response.status, body };
    } catch { return { status: null, body: null }; }
  }
  const cfHeaders = { Authorization: "Bearer " + e.CLOUDFLARE_API_TOKEN, "Accept": "application/json" };
  const before = await send(ROOT + "/settings", { headers: cfHeaders });
  function snapshot(response) {
    if (response.status !== 200 || response.body?.success !== true || !Array.isArray(response.body?.result?.bindings)) return null;
    const b = response.body.result.bindings;
    const variable = name => b.find(x => x.type === "plain_text" && x.name === name)?.text;
    const quota = b.find(x => x.name === "QUOTA" && x.type === "durable_object_namespace" && x.class_name === "PrototypeQuota");
    const model = variable("OPENAI_MODEL") ?? MODEL;
    if (model !== MODEL || !quota?.namespace_id
        || !b.some(x => x.name === "TESTER_ACCESS_CODE" && x.type === "secret_text")
        || !b.some(x => x.name === "OPENAI_API_KEY" && x.type === "secret_text")) return null;
    return { model, namespace: quota.namespace_id,
      daily: variable("DAILY_PHOTO_LIMIT") ?? "1000", minute: variable("MINUTE_PHOTO_LIMIT") ?? "60",
      secretNames: b.filter(x => x.type === "secret_text").map(x => x.name).sort() };
  }
  const saved = snapshot(before);
  if (!saved) { report.issue = "existing_worker_configuration_not_verified"; report.cloudflareHttpStatus = before.status; return report; }
  const provider = await send("https://api.openai.com/v1/responses", {
    method: "POST", headers: { Authorization: "Bearer " + e.FOOD_OPENAI_API_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ model: saved.model, input: "Reply with OK.", max_output_tokens: 16, store: false, background: false }) });
  report.providerHttpStatus = provider.status;
  report.providerErrorCode = identifier(provider.body?.error?.code);
  report.providerErrorType = identifier(provider.body?.error?.type);
  if (provider.status !== 200 || provider.body?.status !== "completed") {
    report.issue = provider.status === 401 ? "provider_authentication_rejected"
      : provider.status === 429 ? "provider_quota_or_rate_limit" : "provider_credential_not_verified";
    return report;
  }
  report.providerVerified = true;
  if (operation === "check") return report;
  const update = await send(ROOT + "/secrets", {
    method: "PUT", headers: { ...cfHeaders, "Content-Type": "application/json" },
    body: JSON.stringify({ name: "OPENAI_API_KEY", type: "secret_text", text: e.FOOD_OPENAI_API_KEY }) });
  report.cloudflareHttpStatus = update.status;
  if (![200, 201].includes(update.status) || update.body?.success !== true) {
    report.issue = "provider_secret_update_failed";
    report.cloudflareErrorCodes = Array.isArray(update.body?.errors)
      ? update.body.errors.map(x => x.code).filter(Number.isInteger) : [];
    return report;
  }
  report.secretUpdated = true;
  const after = snapshot(await send(ROOT + "/settings", { headers: cfHeaders }));
  report.configurationUnchanged = after !== null && JSON.stringify(after) === JSON.stringify(saved);
  if (!report.configurationUnchanged) report.issue = "configuration_changed_requires_followup";
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let report;
  try { report = await checkOrRepair({ operation: process.env.AI_SERVICE_REPAIR_OPERATION || "check", environment: process.env }); }
  catch { report = { issue: "credential_check_execution_failed", secretUpdated: false, providerVerified: false }; }
  writeFileSync(process.env.RUNNER_TEMP + "/AIProviderCredentialRepair.json", JSON.stringify(report, null, 2) + "\n");
  console.log("AI_PROVIDER_CREDENTIAL: " + JSON.stringify(report));
  if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, "applied=" + (report.secretUpdated && !report.issue ? "true" : "false") + "\n");
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY,
    "## Loop AI provider credential\n\n" + JSON.stringify(report, null, 2) + "\n");
  if (report.issue || !report.providerVerified) process.exitCode = 1;
}
