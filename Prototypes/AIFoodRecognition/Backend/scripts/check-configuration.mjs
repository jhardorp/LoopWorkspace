import { appendFileSync } from "node:fs";
import { deploymentSettings } from "./deployment-settings.mjs";

// Status only: do not print, persist, return or transmit any credential value.
const names = ["FOOD_OPENAI_API_KEY", "CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_API_TOKEN", "FOOD_TESTER_ACCESS_CODE"];
const lines = names.map((name) => `${name}: ${process.env[name] ? "present" : "missing"}`);
let ready = false;
if (names.every((name) => process.env[name])) {
  try {
    deploymentSettings(process.env);
    ready = true;
    lines.push("All four secrets are present and their checked formats are valid.");
  } catch (error) {
    // The settings module uses fixed errors containing names/instructions, never values.
    lines.push(error.message);
  }
}
lines.push("No publication, provider authentication or paid photo analysis was performed.");
process.stdout.write(lines.join("\n") + "\n");
if (process.env.GITHUB_STEP_SUMMARY) {
  appendFileSync(process.env.GITHUB_STEP_SUMMARY,
    `### Loop+ backend configuration status\n\n${lines.map((line) => `- ${line}`).join("\n")}\n`);
}
if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, `ready=${ready}\n`);
