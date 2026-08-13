/**
 * Sandbox Balance Update (migrated from internal Python CLI).
 *
 * Flow: offset CSV → AES zip → email → wait 15s → scheduler ping.
 * Secrets / signing stay on the backend.
 */
import {onRequest} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {defineSecret, defineString} from "firebase-functions/params";
import nodemailer from "nodemailer";
import * as archiver from "archiver";
import {generatePayoutJwt} from "./payoutJwt";
// eslint-disable-next-line @typescript-eslint/no-var-requires
const ArchiverZipEncrypted = require("archiver-zip-encrypted");

const emailAppPassword = defineSecret("EMAIL_APP_PASSWORD");
const balanceZipPassword = defineSecret("BALANCE_ZIP_PASSWORD");

const smtpUser = defineString("SMTP_USER", {
  default: "",
  description: "SMTP login / From address (e.g. nelson.wong@codapayments.com)",
});
const balanceEmailTo = defineString("BALANCE_EMAIL_TO", {
  default: "payout-qa-internal@codapayments.com",
});
const balanceEmailCc = defineString("BALANCE_EMAIL_CC", {
  default: "codapay_integration@codapayments.com",
});
const schedulerCheckUrl = defineString("BALANCE_SCHEDULER_URL", {
  default:
    "https://payout-scheduler.codapay.net/internal/scheduler/email-workflow/check-new-email",
});

const API_CALL_DELAY_MS = 15_000;

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
 * Intentional business rule — balance as offset from baseline 100 (NOT a bug).
 * @param {number} balanceValue Desired balance value from the form
 * @return {string} Signed offset string for the CSV "Payout Balance" column
 */
export function computePayoutBalanceOffset(balanceValue: number): string {
  if (balanceValue < 100) {
    return "-" + String(Math.trunc(100 - balanceValue));
  }
  return "+" + String(Math.trunc(balanceValue - 100));
}

/**
 * Build the BALANCE_*.csv content with required headers/row.
 * @param {object} params CSV fields
 * @param {string} params.partnerId Publisher ID
 * @param {string} params.payoutBalance Offset string
 * @param {string} params.currency Currency code
 * @param {number|string} params.creditLimit Credit limit
 * @return {string} CSV text
 */
function buildBalanceCsv(params: {
  partnerId: string;
  payoutBalance: string;
  currency: string;
  creditLimit: number | string;
}): string {
  const headers = [
    "Publisher ID",
    "Publisher",
    "Payout Balance",
    "Balance Currency",
    "Credit Limit",
    "Credit Currency",
  ];
  const row = [
    params.partnerId,
    "Publisher A",
    params.payoutBalance,
    params.currency,
    String(params.creditLimit),
    params.currency,
  ];
  return `${headers.join(",")}\n${row.join(",")}\n`;
}

/**
 * Create an AES-encrypted zip containing one CSV file.
 * @param {string} csvContent CSV file body
 * @param {string} csvFileName Name inside the zip
 * @param {string} password AES zip password
 * @return {Promise<Buffer>} Zip bytes
 */
async function createAesZip(
  csvContent: string,
  csvFileName: string,
  password: string
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    try {
      try {
        archiver.registerFormat("zip-encrypted", ArchiverZipEncrypted);
      } catch (_) {
        // already registered
      }

      const archive = archiver.create("zip-encrypted", {
        zlib: {level: 8},
        encryptionMethod: "aes256",
        password,
      } as archiver.ArchiverOptions);

      const chunks: Buffer[] = [];
      archive.on("data", (chunk: Buffer) => chunks.push(chunk));
      archive.on("end", () => resolve(Buffer.concat(chunks)));
      archive.on("error", (err: Error) => reject(err));
      archive.append(csvContent, {name: csvFileName});
      archive.finalize();
    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Promise-based delay.
 * @param {number} ms Milliseconds to wait
 * @return {Promise<void>}
 */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
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
 * POST /balanceUpdate
 * body: { secret, partner_id, api_key, balance_value, currency, credit_limit }
 */
export const balanceUpdate = onRequest(
  {
    secrets: [emailAppPassword, balanceZipPassword],
    timeoutSeconds: 120,
    maxInstances: 5,
  },
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

    const steps = {
      csvBuilt: false,
      zipBuilt: false,
      emailSent: false,
      schedulerAck: false,
    };

    try {
      const body = (request.body || {}) as Record<string, unknown>;
      const secret = requireString(body, "secret");
      const partnerId = requireString(body, "partner_id");
      // api_key kept for CLI parity (email/CSV path does not call the balance API).
      requireString(body, "api_key");
      generatePayoutJwt(secret, partnerId);

      const balanceRaw = body.balance_value;
      const creditRaw = body.credit_limit;
      const currencyRaw = requireString(body, "currency");

      if (typeof balanceRaw !== "number" && typeof balanceRaw !== "string") {
        throw new Error("balance_value must be numeric");
      }
      if (typeof creditRaw !== "number" && typeof creditRaw !== "string") {
        throw new Error("credit_limit must be numeric");
      }

      const balanceValue = Number(balanceRaw);
      const creditLimit = Number(creditRaw);
      if (!Number.isFinite(balanceValue)) {
        throw new Error("balance_value must be numeric");
      }
      if (!Number.isFinite(creditLimit)) {
        throw new Error("credit_limit must be numeric");
      }

      const currency = currencyRaw.toUpperCase();
      if (!/^[A-Z]+$/.test(currency)) {
        throw new Error("currency must be alphabetic only");
      }

      const smtpFrom = smtpUser.value().trim();
      const smtpPass = emailAppPassword.value();
      const zipPass = balanceZipPassword.value();
      if (!smtpFrom || !smtpPass) {
        throw new Error(
          "SMTP credentials missing. Set SMTP_USER and EMAIL_APP_PASSWORD."
        );
      }
      if (!zipPass) {
        throw new Error(
          "BALANCE_ZIP_PASSWORD secret is not set. " +
            "Configure it via Firebase secrets (rotate from legacy default)."
        );
      }

      // Intentional ±100 baseline offset (see computePayoutBalanceOffset).
      const payoutBalance = computePayoutBalanceOffset(balanceValue);
      const csvContent = buildBalanceCsv({
        partnerId,
        payoutBalance,
        currency,
        creditLimit,
      });
      steps.csvBuilt = true;

      const csvName = `BALANCE_${partnerId}.csv`;
      const zipName = `BALANCE_${partnerId}.zip`;
      const zipBuffer = await createAesZip(csvContent, csvName, zipPass);
      steps.zipBuilt = true;

      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {user: smtpFrom, pass: smtpPass},
      });

      await transporter.sendMail({
        from: smtpFrom,
        to: balanceEmailTo.value(),
        cc: balanceEmailCc.value(),
        subject: "Sandbox Txn Status Update",
        text:
          "This email is sent by PS Team Internal Tools. " +
          "If you have any concerns, please contact Nelson via Slack, " +
          "or Email to nelson.wong@codapayments.com.",
        attachments: [
          {
            filename: zipName,
            content: zipBuffer,
          },
        ],
      });
      steps.emailSent = true;
      logger.info("balanceUpdate email sent", {partnerId, zipName});

      await sleep(API_CALL_DELAY_MS);

      // payout-scheduler.codapay.net is VPN-only and usually unreachable
      // from Cloud Functions. Soft-fail so the client can retry on VPN.
      let schedulerError: string | undefined;
      try {
        const schedulerUrl = schedulerCheckUrl.value();
        const schedulerRes = await fetch(schedulerUrl, {method: "POST"});
        steps.schedulerAck = schedulerRes.status === 204;
        if (!steps.schedulerAck) {
          schedulerError =
            `Scheduler returned HTTP ${schedulerRes.status} (expected 204)`;
        }
      } catch (err) {
        schedulerError = (err as Error).message || "fetch failed";
        logger.warn("balanceUpdate scheduler unreachable from CF", {
          error: schedulerError,
          structuredData: true,
        });
      }

      response.status(200).json({
        // Email path is the critical server work; scheduler may need VPN.
        success: true,
        steps,
        payout_balance: payoutBalance,
        currency,
        credit_limit: creditLimit,
        zip_name: zipName,
        needs_client_scheduler_ping: !steps.schedulerAck,
        scheduler_error: schedulerError,
        message: steps.schedulerAck ?
          "Balance CSV emailed and scheduler acknowledged (HTTP 204)." :
          "Balance CSV emailed. Scheduler unreachable from Cloud Functions " +
            "(VPN-only). Client will retry the ping.",
      });
    } catch (error) {
      logger.error("balanceUpdate failed", error);
      response.status(500).json({
        success: false,
        steps,
        error: (error as Error).message || "Balance update failed",
      });
    }
  }
);
