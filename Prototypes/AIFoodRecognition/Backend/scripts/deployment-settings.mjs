export function deploymentSettings(environment) {
  const required = ["CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ACCOUNT_ID", "FOOD_OPENAI_API_KEY", "FOOD_TESTER_ACCESS_CODE"];
  const missing = required.filter((name) => !environment[name]);
  if (missing.length) throw new Error(`Add these GitHub Actions secrets before deployment: ${missing.join(", ")}`);
  if (environment.GITHUB_ACTIONS === "true"
      && (environment.GITHUB_REF !== "refs/heads/feature/ai-food-recognition" || environment.GITHUB_REPOSITORY !== "jhardorp/LoopWorkspace")) {
    throw new Error("Deployment is restricted to the owner's food-recognition feature branch.");
  }
  const account = environment.CLOUDFLARE_ACCOUNT_ID;
  if (!/^[a-f0-9]{32}$/i.test(account)) throw new Error("CLOUDFLARE_ACCOUNT_ID must be the 32-character account ID.");
  if (!/^sk-[A-Za-z0-9_-]{20,}$/.test(environment.FOOD_OPENAI_API_KEY)) throw new Error("FOOD_OPENAI_API_KEY must contain the OpenAI project API key.");
  if (!/^[\x21-\x7e]{32,256}$/.test(environment.FOOD_TESTER_ACCESS_CODE) || environment.FOOD_TESTER_ACCESS_CODE.startsWith("sk-")) {
    throw new Error("FOOD_TESTER_ACCESS_CODE must be a separate random 32–256 character code without spaces.");
  }
  return { account, openAIKey: environment.FOOD_OPENAI_API_KEY, testerCode: environment.FOOD_TESTER_ACCESS_CODE };
}
