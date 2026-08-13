/**
 * Sandbox / Production Check Balance (migrated from internal Python CLI).
 * No secrets required — caller supplies secret/api_key per request.
 */
import {onRequest} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {generatePayoutJwt} from "./payoutJwt";

const SANDBOX_BALANCE_URL =
  "https://payout.codapayments-staging.com/balance";
const PROD_BALANCE_URL = "https://payout.codapayments.com/balance";

/**
 * Apply CORS headers for browser POSTs from the Flutter web app.
 * @param {object} response Express-like response
 */
function setCors(response: {
  set: (k: string, v: string) => void;
}): void {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  response.set("Access-Control-Allow-Headers", "Content-Type");
}

/**
 * Require a non-empty string field from the JSON body.
 * @param {Record<string, unknown>} body Request body
 * @param {string} key Field name
 * @return {string} Trimmed value
 */
function requireString(body: Record<string, unknown>, key: string): string {
  const v = body[key];
  if (typeof v !== "string" || !v.trim()) {
    throw new Error(`Missing or invalid field: ${key}`);
  }
  return v.trim();
}

/**
 * POST /checkBalance
 * body: { secret, partner_id, api_key, production?: boolean }
 */
export const checkBalance = onRequest(
  {timeoutSeconds: 60, maxInstances: 10},
  async (request, response) => {
    setCors(response);
    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }
    if (request.method !== "POST") {
      response.status(405).json({error: "Method not allowed. Use POST."});
      return;
    }

    try {
      const body = (request.body || {}) as Record<string, unknown>;
      const secret = requireString(body, "secret");
      const partnerId = requireString(body, "partner_id");
      const apiKey = requireString(body, "api_key");
      const production = body.production === true;

      const token = generatePayoutJwt(secret, partnerId);
      const url = production ? PROD_BALANCE_URL : SANDBOX_BALANCE_URL;

      logger.info("checkBalance request", {
        partnerId,
        production,
        url,
        structuredData: true,
      });

      const upstream = await fetch(url, {
        method: "GET",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
          "X-API-Key": apiKey,
        },
      });

      const text = await upstream.text();
      let data: unknown = text;
      try {
        data = JSON.parse(text);
      } catch (_) {
        // keep raw text
      }

      if (!upstream.ok) {
        response.status(upstream.status).json({
          success: false,
          error: `Balance API returned HTTP ${upstream.status}`,
          status: upstream.status,
          data,
          environment: production ? "production" : "sandbox",
        });
        return;
      }

      response.status(200).json({
        success: true,
        environment: production ? "production" : "sandbox",
        url,
        data,
      });
    } catch (error) {
      logger.error("checkBalance failed", error);
      response.status(500).json({
        success: false,
        error: (error as Error).message || "Check balance failed",
      });
    }
  }
);
