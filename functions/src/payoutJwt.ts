/**
 * Shared HS256 JWT helper for payout sandbox tools.
 */
import {createHmac} from "crypto";

/**
 * Base64url encode without '=' padding.
 * @param {Buffer|string} data Input bytes or utf8 string
 * @return {string} base64url string
 */
function base64UrlEncode(data: Buffer | string): string {
  const buf = Buffer.isBuffer(data) ? data : Buffer.from(data, "utf8");
  return buf
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

/**
 * HS256 JWT: header.payload.signature (no padding on base64url segments).
 * @param {string} secret HMAC secret
 * @param {string} partnerId Partner / publisher id
 * @return {string} compact JWT
 */
export function generatePayoutJwt(secret: string, partnerId: string): string {
  const header = {alg: "HS256", typ: "JWT"};
  const payload = {
    partner_id: partnerId,
    iat: Math.floor(Date.now() / 1000),
  };
  const headerB64 = base64UrlEncode(JSON.stringify(header));
  const payloadB64 = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${headerB64}.${payloadB64}`;
  const signature = createHmac("sha256", secret)
    .update(signingInput)
    .digest();
  return `${signingInput}.${base64UrlEncode(signature)}`;
}
