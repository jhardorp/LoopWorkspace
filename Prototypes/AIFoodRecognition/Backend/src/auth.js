import { Buffer } from "node:buffer";

const encoder = new TextEncoder();
const encode = (object) => Buffer.from(JSON.stringify(object)).toString("base64url");
const decode = (text) => JSON.parse(Buffer.from(text, "base64url").toString("utf8"));

async function sessionKey(accessCode) {
  return crypto.subtle.importKey("raw", encoder.encode(`loop-plus-session-v1\0${accessCode}`), { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
}

export async function sameAccessCode(input, expected) {
  if (typeof input !== "string" || input.length > 256) return false;
  const [a, b] = await Promise.all([input, expected].map(async (text) => new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(text)))));
  let difference = 0;
  for (let index = 0; index < a.length; index++) difference |= a[index] ^ b[index];
  return difference === 0;
}

export async function issueSession(accessCode, audience, now) {
  const expiresAt = now + 1800;
  const payload = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({ aud: audience, sub: "prototype-tester", iat: now, exp: expiresAt })}`;
  const signature = await crypto.subtle.sign("HMAC", await sessionKey(accessCode), encoder.encode(payload));
  return { token: `${payload}.${Buffer.from(signature).toString("base64url")}`, expiresAt };
}

export async function validSession(authorization, accessCode, audience, now) {
  try {
    if (typeof authorization !== "string" || authorization.length > 2055 || !/^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(authorization)) return false;
    const [header, payload, signature] = authorization.slice(7).split(".");
    const verified = await crypto.subtle.verify("HMAC", await sessionKey(accessCode), Buffer.from(signature, "base64url"), encoder.encode(`${header}.${payload}`));
    if (!verified) return false;
    const metadata = decode(header), claims = decode(payload);
    return metadata.alg === "HS256" && metadata.typ === "JWT" && claims.aud === audience
      && claims.sub === "prototype-tester" && Number.isInteger(claims.iat) && Number.isInteger(claims.exp)
      && claims.iat <= now + 30 && claims.exp > now && claims.exp - claims.iat === 1800;
  } catch { return false; }
}

export async function loginIdentity(request, accessCode) {
  // Rate-limit identity only: salted IP digest, with no raw IP or meal data in quota storage.
  const value = `${accessCode}\0${request.headers.get("CF-Connecting-IP") ?? "unknown"}`;
  return Buffer.from(await crypto.subtle.digest("SHA-256", encoder.encode(value))).toString("hex");
}
