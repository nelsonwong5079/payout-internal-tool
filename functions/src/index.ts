/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/https";
import {onSchedule} from "firebase-functions/scheduler";
import * as logger from "firebase-functions/logger";
import nodemailer from "nodemailer";
import * as archiver from "archiver";
import {defineSecret} from "firebase-functions/params";
import {
  CodaEnv,
  codaUrls,
  debugAccessToken,
  interpretResultCode,
  isDebugPanelEnabled,
  listDebugEvents,
  observedCodaFetch,
  recordDebugEvent,
  verifyCodaChecksum,
} from "./codaCardObservability";
// eslint-disable-next-line @typescript-eslint/no-var-requires
const ArchiverZipEncrypted = require("archiver-zip-encrypted");

// Define secrets
const emailAppPassword = defineSecret(
  "EMAIL_APP_PASSWORD"
);

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

/**
 * Helper function to create password-protected ZIP file using archiver
 * @param {string} csvContent - CSV file content
 * @param {string} fileName - Base filename without extension
 * @param {string} password - ZIP password
 * @return {Promise<Buffer>} ZIP file buffer
 */
async function createPasswordProtectedZip(
  csvContent: string,
  fileName: string,
  password: string
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    try {
      // Register the encrypted format only if not already registered
      try {
        archiver.registerFormat("zip-encrypted", ArchiverZipEncrypted);
      } catch (err) {
        // Format already registered, ignore the error
      }

      // Create archiver with encryption
      const archive = archiver.create("zip-encrypted", {
        zlib: {level: 8},
        encryptionMethod: "aes256",
        password: password,
      } as archiver.ArchiverOptions);

      const chunks: Buffer[] = [];

      archive.on("data", (chunk: Buffer) => {
        chunks.push(chunk);
      });

      archive.on("end", () => {
        const buffer = Buffer.concat(chunks);
        resolve(buffer);
      });

      archive.on("error", (err: Error) => {
        reject(err);
      });

      // Add the CSV content as a file
      archive.append(csvContent, {name: `${fileName}.csv`});

      // Finalize the archive
      archive.finalize();
    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Helper function to convert CSV content to have all payout status as APPROVED
 * @param {string} csvContent - Original CSV content
 * @return {string} Modified CSV content with APPROVED status
 */
function convertToApprovedStatus(csvContent: string): string {
  const lines = csvContent.split("\n");
  if (lines.length === 0) return csvContent;

  // Parse header to find payout status column
  const headers = lines[0].split(",").map((h) =>
    h.replace(/"/g, "").trim().toLowerCase()
  );
  const payoutStatusIndex = headers.findIndex((h) =>
    h.includes("payout status")
  );

  if (payoutStatusIndex === -1) {
    logger.warn("Payout Status column not found in CSV headers");
    return csvContent; // Return original if column not found
  }

  // Process each data row (skip header)
  const modifiedLines = [lines[0]]; // Keep header as is

  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === "") continue; // Skip empty lines

    const fields = lines[i].split(",");
    if (fields.length > payoutStatusIndex) {
      // Replace payout status with APPROVED
      fields[payoutStatusIndex] = "\"APPROVED\"";
      modifiedLines.push(fields.join(","));
    } else {
      modifiedLines.push(lines[i]); // Keep line as is if not enough fields
    }
  }

  return modifiedLines.join("\n");
}

/**
 * CSV to ZIP conversion API
 */
export const generateZipFiles = onRequest(async (request, response) => {
  // CORS headers
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  response.set("Access-Control-Allow-Headers", "Content-Type");

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed. Use POST."});
    return;
  }

  try {
    const {originalCsv, fileName, transactionType} = request.body;

    if (!originalCsv || !fileName || !transactionType) {
      response.status(400).json({error: "Missing required fields"});
      return;
    }

    const password = "P@ssw0rd";

    // File 1: approved_${fileName}${transactionType} with all APPROVED status
    const approvedFileName = `approved_${fileName}${transactionType}`;
    const approvedCsvContent = convertToApprovedStatus(originalCsv);

    // File 2: ${fileName}${transactionType} with user's selected status
    const originalFileName = `${fileName}${transactionType}`;
    const originalCsvContent = originalCsv;

    logger.info(`Generating files:
    1. ${approvedFileName}.zip - All payout status = APPROVED
    2. ${originalFileName}.zip - User's selected payout status`);

    // Create both password-protected ZIP files
    const [approvedZip, originalZip] = await Promise.all([
      createPasswordProtectedZip(
        approvedCsvContent,
        approvedFileName,
        password
      ),
      createPasswordProtectedZip(
        originalCsvContent,
        originalFileName,
        password
      ),
    ]);

    // Send ZIP files as base64 in response
    response.status(200).json({
      success: true,
      files: {
        approved: {
          name: `${approvedFileName}.zip`,
          content: approvedZip.toString("base64"),
        },
        original: {
          name: `${originalFileName}.zip`,
          content: originalZip.toString("base64"),
        },
      },
    });
  } catch (error) {
    logger.error("Error creating ZIP files", error);
    response.status(500).json({
      success: false,
      error: (error as Error).message,
    });
  }
});

// Email sending API with ZIP file generation and attachment
export const sendEmail = onRequest({secrets: [emailAppPassword]}, async (request, response) => {
  // CORS headers
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  response.set("Access-Control-Allow-Headers", "Content-Type");

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed. Use POST."});
    return;
  }

  try {
    const {originalCsv, fileName, transactionType, emailType} = request.body;

    if (!originalCsv || !fileName || !transactionType || !emailType) {
      response.status(400).json({error: "Missing required fields"});
      return;
    }

    const password = "P@ssw0rd";
    const recipient = "payout-qa-internal@codapayments.com";

    // Configure nodemailer with Gmail SMTP
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: "nelson.wong@codapayments.com",
        pass: emailAppPassword.value(), // Use environment variable
      },
    });

    if (emailType === "approved") {
      // Send approved ZIP file
      const approvedFileName = `approved_${fileName}${transactionType}`;
      const approvedCsvContent = convertToApprovedStatus(originalCsv);

      logger.info(`Sending approved email: ${approvedFileName}.zip`);

      const approvedZip = await createPasswordProtectedZip(
        approvedCsvContent,
        approvedFileName,
        password
      );

      const approvedMailOptions = {
        from: "nelson.wong@codapayments.com",
        to: recipient,
        subject: "Sandbox Txn Status Update",
        text: "This email is sent by PS Team Internal Tools. " +
          "If you have any concerns, please contact Nelson via Slack, " +
          "or Email to nelson.wong@codapayments.com.",
        attachments: [
          {
            filename: `${approvedFileName}.zip`,
            content: approvedZip,
          },
        ],
      };

      await transporter.sendMail(approvedMailOptions);
      logger.info("Approved email sent successfully");

      response.status(200).json({
        success: true,
        message: "Approved ZIP file sent via email successfully",
        fileName: `${approvedFileName}.zip`,
        type: "approved",
        zipContent: approvedZip.toString("base64"),
      });
    } else if (emailType === "original") {
      // Send original ZIP file
      const originalFileName = `${fileName}${transactionType}`;

      logger.info(`Sending original email: ${originalFileName}.zip`);

      const originalZip = await createPasswordProtectedZip(
        originalCsv,
        originalFileName,
        password
      );

      const originalMailOptions = {
        from: "nelson.wong@codapayments.com",
        to: recipient,
        subject: "Sandbox Txn Status Update",
        text: "This email is sent by PS Team Internal Tools. " +
          "If you have any concerns, please contact Nelson via Slack, " +
          "or Email to nelson.wong@codapayments.com.",
        attachments: [
          {
            filename: `${originalFileName}.zip`,
            content: originalZip,
          },
        ],
      };

      await transporter.sendMail(originalMailOptions);
      logger.info("Original email sent successfully");

      response.status(200).json({
        success: true,
        message: "Original ZIP file sent via email successfully",
        fileName: `${originalFileName}.zip`,
        type: "original",
        zipContent: originalZip.toString("base64"),
      });
    } else {
      response.status(400).json({
        error: "Invalid emailType. Use 'approved' or 'original'",
      });
      return;
    }
  } catch (error) {
    logger.error("Error in sendEmail function", error);
    response.status(500).json({
      success: false,
      error: (error as Error).message,
    });
  }
});

// Note: VPN check is done client-side using JavaScript fetch with no-cors mode
// Firebase Functions cannot access internal company VPN endpoints

/**
 * Sandbox Monitoring API
 * Checks the status of sandbox environment for both LCY and USD currencies
 */
export const checkSandboxStatus = onRequest(async (request, response) => {
  // CORS headers
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  response.set("Access-Control-Allow-Headers", "Content-Type");

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (request.method !== "POST" && request.method !== "GET") {
    response.status(405).json({error: "Method not allowed. Use POST or GET."});
    return;
  }

  try {
    const results = {
      timestamp: new Date().toISOString(), // This will be converted to GMT+8 on frontend
      paytype237: {
        lcy: await checkCurrencyStatus(458),
        usd: await checkCurrencyStatus(840),
      },
      paytype0: {
        lcy: await checkCurrencyStatusPaytype0(458),
        usd: await checkCurrencyStatusPaytype0(840),
      },
    };

    // Check for any DOWN statuses and prepare failedChecks array
    const failedChecks = [];

    // Check Paytype237 failures
    if (results.paytype237.lcy.status === "DOWN") {
      failedChecks.push({
        version: "v1",
        paytype: "237",
        currency: "LCY (MYR)",
        status: "DOWN",
        errorMessage: results.paytype237.lcy.errorMessage,
      });
    }

    if (results.paytype237.usd.status === "DOWN") {
      failedChecks.push({
        version: "v1",
        paytype: "237",
        currency: "USD",
        status: "DOWN",
        errorMessage: results.paytype237.usd.errorMessage,
      });
    }

    // Check Paytype0 failures
    if (results.paytype0.lcy.status === "DOWN") {
      failedChecks.push({
        version: "v1",
        paytype: "0",
        currency: "LCY (MYR)",
        status: "DOWN",
        errorMessage: results.paytype0.lcy.errorMessage,
      });
    }

    if (results.paytype0.usd.status === "DOWN") {
      failedChecks.push({
        version: "v1",
        paytype: "0",
        currency: "USD",
        status: "DOWN",
        errorMessage: results.paytype0.usd.errorMessage,
      });
    }

    // If any checks failed, send notification email
    if (failedChecks.length > 0) {
      await sendFailureNotificationEmail(failedChecks);
      logger.info("Failure notification sent for sandbox check", {
        failedChecks: failedChecks.length,
        structuredData: true,
      });
    }

    response.status(200).json({
      success: true,
      data: results,
    });
  } catch (error) {
    logger.error("Error checking sandbox status", error);

    // Create a failedCheck entry for the general error
    const failedChecks = [{
      version: "v1",
      paytype: "all",
      currency: "all",
      status: "DOWN",
      errorMessage: (error as Error).message || "Network error occurred while checking sandbox status",
    }];

    // Send notification email for the error
    try {
      await sendFailureNotificationEmail(failedChecks);
      logger.info("Failure notification sent for general error", {
        error: (error as Error).message,
        structuredData: true,
      });
    } catch (emailError) {
      logger.error("Failed to send error notification email", emailError);
    }

    response.status(500).json({
      success: false,
      error: (error as Error).message,
    });
  }
});

export const checkSandboxStatusV2 = onRequest(async (request, response) => {
  // CORS headers
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  response.set("Access-Control-Allow-Headers", "Content-Type");

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (request.method !== "POST" && request.method !== "GET") {
    response.status(405).json({error: "Method not allowed. Use POST or GET."});
    return;
  }

  try {
    const results = {
      timestamp: new Date().toISOString(), // This will be converted to GMT+8 on frontend
      paytype237: {
        lcy: await checkCurrencyStatusV2(458),
        usd: await checkCurrencyStatusV2(840),
      },
      paytype0: {
        lcy: await checkCurrencyStatusV2Paytype0(458),
        usd: await checkCurrencyStatusV2Paytype0(840),
      },
    };

    response.status(200).json({
      success: true,
      data: results,
    });
  } catch (error) {
    logger.error("Error checking sandbox v2.0 status", error);
    response.status(500).json({
      success: false,
      error: (error as Error).message,
    });
  }
});

/**
 * Helper function to check a specific currency status with paytype 237
 * @param {number} currency - Currency code (458 for LCY, 840 for USD)
 * @return {Promise<Object>} Status object
 */
async function checkCurrencyStatus(currency: number): Promise<{
  status: "UP" | "DOWN";
  resultCode?: number;
  errorMessage?: string;
  responseTime?: number;
  txnId?: number;
}> {
  const startTime = Date.now();

  try {
    const requestBody = {
      initRequest: {
        apiKey: "49005d8dd448ed1029c79615c44c2a792",
        orderId: `O${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        country: 458,
        currency: currency,
        payType: 237,
        items: [
          {
            code: "com.diamond_mt_id_25",
            name: "25+3",
            price: "1",
            type: 1,
          },
        ],
        profile: {
          entry: [
            {
              key: "user_id",
              value: "12345",
            },
          ],
        },
      },
    };

    // Create a timeout promise
    const timeout = new Promise<never>((_, reject) => {
      setTimeout(() => reject(new Error("Request timeout after 30 seconds")), 30000);
    });

    // Race between the fetch and timeout
    const response = await Promise.race([
      fetch("https://sandbox.codapayments.com/airtime/api/restful/v1.0/Payment/init.json", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(requestBody),
      }),
      timeout,
    ]).catch((error) => {
      throw new Error(`Network request failed: ${error.message}`);
    });

    const responseTime = Date.now() - startTime;

    if (!response.ok) {
      const errorMessage = `HTTP ${response.status}: ${response.statusText}`;
      logger.error("API request failed", {
        currency,
        status: response.status,
        statusText: response.statusText,
        responseTime,
        structuredData: true,
      });
      return {
        status: "DOWN",
        errorMessage,
        responseTime,
      };
    }

    // Get raw response text first
    const rawResponseText = await response.text().catch((error) => {
      throw new Error(`Failed to read response: ${error.message}`);
    });

    // Manually parse the JSON to preserve large number precision
    // First, let's extract the txnId as a string before parsing
    const txnIdMatch = rawResponseText.match(/"txnId":(\d+)/);
    let txnIdString = null;
    if (txnIdMatch) {
      txnIdString = txnIdMatch[1];
    }

    // Parse the raw response as JSON
    const data = JSON.parse(rawResponseText);

    // If we found a txnId in the raw text, use that exact string value
    if (txnIdString && data.initResult && data.initResult.txnId) {
      data.initResult.txnId = txnIdString;
    }

    if (data.initResult && data.initResult.resultCode === 0) {
      return {
        status: "UP",
        resultCode: 0,
        responseTime,
        txnId: data.initResult.txnId,
      };
    } else {
      return {
        status: "DOWN",
        resultCode: data.initResult?.resultCode,
        errorMessage: data.initResult?.resultMessage || "Unknown error",
        responseTime,
      };
    }
  } catch (error) {
    const responseTime = Date.now() - startTime;
    const errorMessage = (error as Error).message || "No response from sandbox environment";

    logger.error("Error in currency status check", {
      currency,
      error: errorMessage,
      responseTime,
      structuredData: true,
    });

    return {
      status: "DOWN",
      errorMessage,
      responseTime,
    };
  }
}

/**
 * Helper function to check a specific currency status with paytype 0
 * @param {number} currency - Currency code (458 for LCY, 840 for USD)
 * @return {Promise<Object>} Status object
 */
async function checkCurrencyStatusPaytype0(currency: number): Promise<{
  status: "UP" | "DOWN";
  resultCode?: number;
  errorMessage?: string;
  responseTime?: number;
  txnId?: number;
}> {
  const startTime = Date.now();

  try {
    const requestBody = {
      initRequest: {
        apiKey: "49005d8dd448ed1029c79615c44c2a792",
        orderId: `O${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        country: 458,
        currency: currency,
        payType: 0,
        items: [
          {
            code: "com.diamond_mt_id_25",
            name: "25+3",
            price: "1",
            type: 1,
          },
        ],
        profile: {
          entry: [
            {
              key: "user_id",
              value: "12345",
            },
          ],
        },
      },
    };

    const response = await fetch("https://sandbox.codapayments.com/airtime/api/restful/v1.0/Payment/init.json", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    const responseTime = Date.now() - startTime;

    if (!response.ok) {
      return {
        status: "DOWN",
        errorMessage: `HTTP ${response.status}: ${response.statusText}`,
        responseTime,
      };
    }

    // Get raw response text first
    const rawResponseText = await response.text();

    // Manually parse the JSON to preserve large number precision
    // First, let's extract the txnId as a string before parsing
    const txnIdMatch = rawResponseText.match(/"txnId":(\d+)/);
    let txnIdString = null;
    if (txnIdMatch) {
      txnIdString = txnIdMatch[1];
    }

    // Parse the raw response as JSON
    const data = JSON.parse(rawResponseText);

    // If we found a txnId in the raw text, use that exact string value
    if (txnIdString && data.initResult && data.initResult.txnId) {
      data.initResult.txnId = txnIdString;
    }

    if (data.initResult && data.initResult.resultCode === 0) {
      return {
        status: "UP",
        resultCode: 0,
        responseTime,
        txnId: data.initResult.txnId,
      };
    } else {
      return {
        status: "DOWN",
        resultCode: data.initResult?.resultCode,
        errorMessage: data.initResult?.resultMessage || "Unknown error",
        responseTime,
      };
    }
  } catch (error) {
    const responseTime = Date.now() - startTime;
    return {
      status: "DOWN",
      errorMessage: (error as Error).message || "No response from sandbox environment",
      responseTime,
    };
  }
}

/**
 * Helper function to check v2.0 API status for a specific currency with paytype 237
 * @param {number} currency - Currency code (458 for LCY/MYR, 840 for USD)
 * @return {Promise<Object>} Status object with response details
 */
async function checkCurrencyStatusV2(currency: number): Promise<{
  status: string;
  resultCode?: number;
  errorMessage?: string;
  responseTime?: number;
  txnId?: number;
}> {
  const startTime = Date.now();

  try {
    const requestBody = {
      initRequest: {
        country: 458,
        payType: 237,
        apiKey: "test_jCZnXkOIuiLsFm6uBkcjsyYUQQi",
        projectId: 230,
        orderId: "1321314",
        currency: currency, // Use 458 for LCY/MYR, 840 for USD
        items: [
          {
            code: "1",
            price: 1.00,
            name: "Test Item",
          },
        ],
        profile: {
          entry: [
            {
              key: "user_id",
              value: "105",
            },
          ],
        },
      },
    };

    const response = await fetch("https://sandbox.codapayments.com/airtime/api/restful/v2.0/Payment/init.json", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    const responseTime = Date.now() - startTime;

    if (!response.ok) {
      return {
        status: "DOWN",
        errorMessage: `HTTP ${response.status}: ${response.statusText}`,
        responseTime,
      };
    }

    // Get raw response text first
    const rawResponseText = await response.text();

    // Manually parse the JSON to preserve large number precision
    // First, let's extract the txnId as a string before parsing
    const txnIdMatch = rawResponseText.match(/"txnId":(\d+)/);
    let txnIdString = null;
    if (txnIdMatch) {
      txnIdString = txnIdMatch[1];
    }

    // Parse the raw response as JSON
    const data = JSON.parse(rawResponseText);

    // If we found a txnId in the raw text, use that exact string value
    if (txnIdString && data.initResult && data.initResult.txnId) {
      data.initResult.txnId = txnIdString;
    }

    if (data.initResult && data.initResult.resultCode === 0) {
      return {
        status: "UP",
        resultCode: 0,
        responseTime,
        txnId: data.initResult.txnId,
      };
    } else {
      return {
        status: "DOWN",
        resultCode: data.initResult?.resultCode,
        errorMessage: data.initResult?.resultMessage || "Unknown error",
        responseTime,
      };
    }
  } catch (error) {
    const responseTime = Date.now() - startTime;
    return {
      status: "DOWN",
      errorMessage: (error as Error).message || "No response from sandbox environment",
      responseTime,
    };
  }
}

/**
 * Helper function to check v2.0 API status for a specific currency with paytype 0
 * @param {number} currency - Currency code (458 for LCY/MYR, 840 for USD)
 * @return {Promise<Object>} Status object with response details
 */
async function checkCurrencyStatusV2Paytype0(currency: number): Promise<{
  status: string;
  resultCode?: number;
  errorMessage?: string;
  responseTime?: number;
  txnId?: number;
}> {
  const startTime = Date.now();

  try {
    const requestBody = {
      initRequest: {
        country: 458,
        payType: 0,
        apiKey: "test_jCZnXkOIuiLsFm6uBkcjsyYUQQi",
        projectId: 230,
        orderId: "1321314",
        currency: currency, // Use 458 for LCY/MYR, 840 for USD
        items: [
          {
            code: "1",
            price: 1.00,
            name: "Test Item",
          },
        ],
        profile: {
          entry: [
            {
              key: "user_id",
              value: "105",
            },
          ],
        },
      },
    };

    const response = await fetch("https://sandbox.codapayments.com/airtime/api/restful/v2.0/Payment/init.json", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    const responseTime = Date.now() - startTime;

    if (!response.ok) {
      return {
        status: "DOWN",
        errorMessage: `HTTP ${response.status}: ${response.statusText}`,
        responseTime,
      };
    }

    // Get raw response text first
    const rawResponseText = await response.text();

    // Manually parse the JSON to preserve large number precision
    // First, let's extract the txnId as a string before parsing
    const txnIdMatch = rawResponseText.match(/"txnId":(\d+)/);
    let txnIdString = null;
    if (txnIdMatch) {
      txnIdString = txnIdMatch[1];
    }

    // Parse the raw response as JSON
    const data = JSON.parse(rawResponseText);

    // If we found a txnId in the raw text, use that exact string value
    if (txnIdString && data.initResult && data.initResult.txnId) {
      data.initResult.txnId = txnIdString;
    }

    if (data.initResult && data.initResult.resultCode === 0) {
      return {
        status: "UP",
        resultCode: 0,
        responseTime,
        txnId: data.initResult.txnId,
      };
    } else {
      return {
        status: "DOWN",
        resultCode: data.initResult?.resultCode,
        errorMessage: data.initResult?.resultMessage || "Unknown error",
        responseTime,
      };
    }
  } catch (error) {
    const responseTime = Date.now() - startTime;
    return {
      status: "DOWN",
      errorMessage: (error as Error).message || "No response from sandbox environment",
      responseTime,
    };
  }
}

// Scheduled function to check sandbox status every hour from 9 AM to 6 PM GMT+8
export const scheduledSandboxCheck = onSchedule({
  // Run every hour from 1 AM to 10 AM UTC (9 AM to 6 PM GMT+8)
  schedule: "0 1-10 * * *",
  timeZone: "UTC",
  secrets: [emailAppPassword],
}, async () => {
  // Get current hour in GMT+8
  const now = new Date();
  const gmt8Hour = (now.getUTCHours() + 8) % 24;

  // Only run between 9 AM and 6 PM GMT+8
  if (gmt8Hour < 9 || gmt8Hour > 18) {
    logger.info("Outside of working hours in GMT+8, skipping check", {
      currentHourGMT8: gmt8Hour,
      structuredData: true,
    });
    return;
  }

  logger.info("Starting scheduled sandbox status check", {
    currentHourGMT8: gmt8Hour,
    structuredData: true,
  });

  try {
    // Check v1.0 API status
    const v1Results = {
      timestamp: new Date().toISOString(),
      paytype237: {
        lcy: await checkCurrencyStatus(458),
        usd: await checkCurrencyStatus(840),
      },
      paytype0: {
        lcy: await checkCurrencyStatusPaytype0(458),
        usd: await checkCurrencyStatusPaytype0(840),
      },
    };

    logger.info("V1.0 API check completed", {
      paytype237LcyStatus: v1Results.paytype237.lcy.status,
      paytype237UsdStatus: v1Results.paytype237.usd.status,
      paytype0LcyStatus: v1Results.paytype0.lcy.status,
      paytype0UsdStatus: v1Results.paytype0.usd.status,
      structuredData: true,
    });

    // Check v2.0 API status
    const v2Results = {
      timestamp: new Date().toISOString(),
      paytype237: {
        lcy: await checkCurrencyStatusV2(458),
        usd: await checkCurrencyStatusV2(840),
      },
      paytype0: {
        lcy: await checkCurrencyStatusV2Paytype0(458),
        usd: await checkCurrencyStatusV2Paytype0(840),
      },
    };

    logger.info("V2.0 API check completed", {
      paytype237LcyStatus: v2Results.paytype237.lcy.status,
      paytype237UsdStatus: v2Results.paytype237.usd.status,
      paytype0LcyStatus: v2Results.paytype0.lcy.status,
      paytype0UsdStatus: v2Results.paytype0.usd.status,
      structuredData: true,
    });

    // Log summary
    const allServices = [
      {name: "V1.0 Paytype237 LCY", status: v1Results.paytype237.lcy.status},
      {name: "V1.0 Paytype237 USD", status: v1Results.paytype237.usd.status},
      {name: "V1.0 Paytype0 LCY", status: v1Results.paytype0.lcy.status},
      {name: "V1.0 Paytype0 USD", status: v1Results.paytype0.usd.status},
      {name: "V2.0 Paytype237 LCY", status: v2Results.paytype237.lcy.status},
      {name: "V2.0 Paytype237 USD", status: v2Results.paytype237.usd.status},
      {name: "V2.0 Paytype0 LCY", status: v2Results.paytype0.lcy.status},
      {name: "V2.0 Paytype0 USD", status: v2Results.paytype0.usd.status},
    ];

    const upServices = allServices.filter((service) => service.status === "UP").length;
    const totalServices = allServices.length;

    logger.info("Scheduled check summary", {
      upServices,
      totalServices,
      uptimePercentage: Math.round((upServices / totalServices) * 100),
      currentHourGMT8: gmt8Hour,
      structuredData: true,
    });

    // Check for failures and send notification email
    const failedChecks = [];

    // Check V1.0 Paytype237 failures
    if (v1Results.paytype237.lcy.status === "DOWN") {
      failedChecks.push({
        version: "v1",
        paytype: "237",
        currency: "LCY (MYR)",
        status: "DOWN",
        errorMessage: v1Results.paytype237.lcy.errorMessage,
      });
    }

    if (v1Results.paytype237.usd.status === "DOWN") {
      failedChecks.push({
        version: "v1",
        paytype: "237",
        currency: "USD",
        status: "DOWN",
        errorMessage: v1Results.paytype237.usd.errorMessage,
      });
    }

    // Check V1.0 Paytype0 failures
    if (v1Results.paytype0.lcy.status === "DOWN") {
      failedChecks.push({
        version: "v1",
        paytype: "0",
        currency: "LCY (MYR)",
        status: "DOWN",
        errorMessage: v1Results.paytype0.lcy.errorMessage,
      });
    }

    if (v1Results.paytype0.usd.status === "DOWN") {
      failedChecks.push({
        version: "v1",
        paytype: "0",
        currency: "USD",
        status: "DOWN",
        errorMessage: v1Results.paytype0.usd.errorMessage,
      });
    }

    // Check V2.0 Paytype237 failures
    if (v2Results.paytype237.lcy.status === "DOWN") {
      failedChecks.push({
        version: "v2",
        paytype: "237",
        currency: "LCY (MYR)",
        status: "DOWN",
        errorMessage: v2Results.paytype237.lcy.errorMessage,
      });
    }

    if (v2Results.paytype237.usd.status === "DOWN") {
      failedChecks.push({
        version: "v2",
        paytype: "237",
        currency: "USD",
        status: "DOWN",
        errorMessage: v2Results.paytype237.usd.errorMessage,
      });
    }

    // Check V2.0 Paytype0 failures
    if (v2Results.paytype0.lcy.status === "DOWN") {
      failedChecks.push({
        version: "v2",
        paytype: "0",
        currency: "LCY (MYR)",
        status: "DOWN",
        errorMessage: v2Results.paytype0.lcy.errorMessage,
      });
    }

    if (v2Results.paytype0.usd.status === "DOWN") {
      failedChecks.push({
        version: "v2",
        paytype: "0",
        currency: "USD",
        status: "DOWN",
        errorMessage: v2Results.paytype0.usd.errorMessage,
      });
    }

    // Send failure notification if any checks failed
    if (failedChecks.length > 0) {
      await sendFailureNotificationEmail(failedChecks);
      logger.info("Failure notification sent", {
        failedChecks: failedChecks.length,
        structuredData: true,
      });
    }
  } catch (error) {
    logger.error("Error in scheduled sandbox check", error);
  }
});

/**
 * Send failure notification email for sandbox API failures
 * @param {Array} failedChecks - Array of failed check objects
 */
async function sendFailureNotificationEmail(
  failedChecks: Array<{version: string, paytype: string, currency: string, status: string, errorMessage?: string}>
) {
  try {
    logger.info("Starting to send failure notification email", {
      failedChecksCount: failedChecks.length,
      structuredData: true,
    });

    // Configure nodemailer with Gmail SMTP
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: "nelson.wong@codapayments.com",
        pass: emailAppPassword.value(), // Use environment variable
      },
    });

    logger.info("Nodemailer transporter configured", {
      user: "nelson.wong@codapayments.com",
      structuredData: true,
    });

    // Group failures by version
    const v1Failures = failedChecks.filter((check) => check.version === "v1");
    const v2Failures = failedChecks.filter((check) => check.version === "v2");

    // Build email body
    let emailBody = "One or more sandbox checks have failed:\n\n";

    if (v1Failures.length > 0) {
      emailBody += "Failed Version(s): v1\n";
      emailBody += "Failed Paytypes: " + v1Failures.map((f) => f.paytype).join(", ") + "\n";
      emailBody += "Failed Currency: " + v1Failures.map((f) => f.currency).join(", ") + "\n";
      if (v1Failures.some((f) => f.errorMessage)) {
        emailBody += "Error Details: " + v1Failures.find((f) => f.errorMessage)?.errorMessage + "\n";
      }
      emailBody += "\n";
    }

    if (v2Failures.length > 0) {
      emailBody += "Failed Version(s): v2\n";
      emailBody += "Failed Paytypes: " + v2Failures.map((f) => f.paytype).join(", ") + "\n";
      emailBody += "Failed Currency: " + v2Failures.map((f) => f.currency).join(", ") + "\n";
      if (v2Failures.some((f) => f.errorMessage)) {
        emailBody += "Error Details: " + v2Failures.find((f) => f.errorMessage)?.errorMessage + "\n";
      }
      emailBody += "\n";
    }

    emailBody += "Please investigate the issue.\n\n";
    emailBody += "This alert was sent automatically by the Sandbox Monitoring System.";

    const mailOptions = {
      from: "nelson.wong@codapayments.com",
      to: "nelson.wong@codapayments.com, wkarweng@icloud.com",
      cc: "codapay_integration@coda.co",
      subject: "[ALERT] Sandbox Failure Detected",
      text: emailBody,
    };

    logger.info("Mail options configured", {
      to: mailOptions.to,
      cc: mailOptions.cc,
      subject: mailOptions.subject,
      emailBodyLength: emailBody.length,
      structuredData: true,
    });

    logger.info("Attempting to send email...", {structuredData: true});
    const result = await transporter.sendMail(mailOptions);

    logger.info("Email sent successfully", {
      messageId: result.messageId,
      failedChecks: failedChecks.length,
      structuredData: true,
    });
  } catch (error) {
    logger.error("Error sending failure notification email", error);
  }
}

// HTTP function to trigger failure email notification
export const triggerFailureEmail = onRequest({
  secrets: [emailAppPassword],
}, async (request, response) => {
  // CORS headers
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  response.set("Access-Control-Allow-Headers", "Content-Type");

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed. Use POST."});
    return;
  }

  try {
    const {failedChecks} = request.body;

    if (!failedChecks || !Array.isArray(failedChecks)) {
      response.status(400).json({
        success: false,
        error: "Invalid request body. Expected 'failedChecks' array.",
      });
      return;
    }

    // Send failure notification email
    await sendFailureNotificationEmail(failedChecks);

    logger.info("Failure email triggered from frontend", {
      failedChecks: failedChecks.length,
      structuredData: true,
    });

    response.status(200).json({
      success: true,
      message: "Failure notification email sent successfully",
      failedChecks,
    });
  } catch (error) {
    logger.error("Error in triggerFailureEmail", error);
    response.status(500).json({
      success: false,
      error: (error as Error).message,
    });
  }
});

// Proxy payout renotify — browsers cannot call scheduler APIs directly (CORS).
export const payoutRenotify = onRequest(async (request, response) => {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  response.set("Access-Control-Allow-Headers", "Content-Type");

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed. Use POST."});
    return;
  }

  try {
    const {environment, payoutId} = request.body as {
      environment?: string;
      payoutId?: string;
    };

    if (!environment || !payoutId) {
      response.status(400).json({
        error: "Missing required fields: environment, payoutId",
      });
      return;
    }

    const notifyUrls: Record<string, string> = {
      staging: "https://payout-scheduler.codapay.net/backoffice/notify",
      production: "https://payout-scheduler.codainfra.net/backoffice/notify",
    };

    const targetUrl = notifyUrls[environment];
    if (!targetUrl) {
      response.status(400).json({
        error: "Invalid environment. Use 'staging' or 'production'.",
      });
      return;
    }

    logger.info("Proxying payout renotify", {
      environment,
      payoutId,
      targetUrl,
      structuredData: true,
    });

    const upstream = await fetch(targetUrl, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({payoutIds: [payoutId]}),
    });

    const body = await upstream.text();
    const contentType = upstream.headers.get("content-type") || "application/json";

    response.status(upstream.status);
    response.set("Content-Type", contentType);
    response.send(body);
  } catch (error) {
    logger.error("Error proxying payout renotify", error);
    response.status(502).json({
      message: "Unable to reach payout scheduler. Please ensure you are on VPN.",
      error: (error as Error).message,
    });
  }
});

// HTTP function to trigger mock fail scenario
export const triggerMockFail = onRequest({
  secrets: [emailAppPassword],
}, async (request, response) => {
  // CORS headers
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  response.set("Access-Control-Allow-Headers", "Content-Type");

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed. Use POST."});
    return;
  }

  try {
    // Simulate a failure in v1 LCY check with paytype 237
    const mockFailure = [
      {
        version: "v1",
        paytype: "237",
        currency: "LCY (MYR)",
        status: "DOWN",
        errorMessage: "Mock failure for testing purposes",
      },
    ];

    // Send failure notification email
    await sendFailureNotificationEmail(mockFailure);

    logger.info("Mock fail scenario triggered successfully", {structuredData: true});

    response.status(200).json({
      success: true,
      message: "Mock fail scenario triggered successfully",
      mockFailure,
    });
  } catch (error) {
    logger.error("Error in mock fail scenario", error);
    response.status(500).json({
      success: false,
      error: (error as Error).message,
    });
  }
});

/**
 * Apply CORS headers for the hosted-card tooling endpoints.
 * @param {Object} response HTTP response
 */
function setCodaCors(response: {
  set: (k: string, v: string) => void;
}): void {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  response.set(
    "Access-Control-Allow-Headers",
    "Content-Type, X-Coda-Debug-Token"
  );
}

/**
 * Proxy Coda Hosted Component init with full debug observability.
 */
export const codaCardInit = onRequest(async (request, response) => {
  setCodaCors(response);

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed. Use POST."});
    return;
  }

  const body = request.body as {
    env?: string;
    apiKey?: string;
    projectId?: string | number;
    country?: string | number;
    currency?: string | number;
    payType?: string | number;
    orderId?: string;
    userId?: string;
    correlationId?: string;
    items?: Array<{code?: string; price?: number; name?: string}>;
    enableSavePaymentMethod?: boolean;
    displaySavedPaymentMethodList?: boolean;
    userInitiated?: boolean;
    shopper?: {entry?: Array<{key: string; value: string}>};
  };

  const env = (body.env === "production" ? "production" : "sandbox") as CodaEnv;
  const apiKey = (body.apiKey || "").trim();
  const projectId = body.projectId;
  const country = body.country;
  const currency = body.currency;
  const payType = body.payType;
  const orderId = (body.orderId || "").trim();
  const userId = (body.userId || "").trim();
  const items = body.items;
  const correlationId =
    (body.correlationId || "").trim() || orderId || `corr_${Date.now()}`;

  try {
    if (!apiKey || projectId === undefined || country === undefined ||
      currency === undefined || payType === undefined || !orderId || !userId) {
      response.status(400).json({
        error:
          "Missing required fields: apiKey, projectId, country, currency, payType, orderId, userId",
      });
      return;
    }

    if (!Array.isArray(items) || items.length === 0) {
      response.status(400).json({error: "items must be a non-empty array"});
      return;
    }

    for (const item of items) {
      if (typeof item.price !== "number" || !item.name) {
        response.status(400).json({
          error: "Each item requires numeric price and name",
        });
        return;
      }
    }

    // Coda samples use numeric country/currency/payType/projectId.
    const initRequest: Record<string, unknown> = {
      country: Number(country),
      payType: Number(payType),
      apiKey,
      projectId: Number(projectId),
      orderId,
      currency: Number(currency),
      items: items.map((item) => ({
        ...(item.code ? {code: String(item.code)} : {}),
        price: item.price,
        name: String(item.name),
      })),
      profile: {
        entry: [{key: "user_id", value: userId}],
      },
    };

    // PART F — saved cards (off by default; requires Coda enablement).
    if (body.enableSavePaymentMethod === true) {
      initRequest.enableSavePaymentMethod = true;
      initRequest.displaySavedPaymentMethodList =
        body.displaySavedPaymentMethodList === true;
      initRequest.userInitiated = body.userInitiated !== false;
      if (body.shopper?.entry?.length) {
        initRequest.shopper = body.shopper;
      }
    }

    const {initUrl} = codaUrls(env);
    const {status, json, text, txnId: extractedTxnId} = await observedCodaFetch({
      env,
      step: "Coda init",
      method: "POST",
      url: initUrl,
      requestPayload: {initRequest},
      correlationId,
      orderId,
      interpret: (parsed) => {
        const initResult = (parsed as {
          initResult?: {resultCode?: number; resultDesc?: string};
        })?.initResult;
        const mapped = interpretResultCode(initResult?.resultCode);
        const desc = initResult?.resultDesc ?
          ` (${initResult.resultDesc})` :
          "";
        return {
          interpretedResult: `${mapped.label}${desc}`,
          badge: mapped.badge,
        };
      },
    });

    const initResult = (json as {
      initResult?: {
        resultCode?: number;
        resultDesc?: string;
        txnId?: number | string;
        clientSecret?: string;
      };
    })?.initResult;

    if (!initResult) {
      const rawBody = (json as {raw?: string})?.raw ?? text;
      const faultMatch = typeof rawBody === "string" ?
        rawBody.match(/<ns1:faultstring[^>]*>([\s\S]*?)<\/ns1:faultstring>/i) :
        null;
      const faultText = faultMatch?.[1]?.trim();
      const hint =
        Number(country) === 485 ?
          "Country 485 is not a valid Coda region code. Use country=458, currency=458 (Malaysia)." :
          "Coda did not return initResult. Check country/currency/payType/projectId for this API key.";

      response.status(502).json({
        error: faultText || "Missing initResult from Coda",
        hint,
        status,
        body: json,
        correlationId,
      });
      return;
    }

    if (initResult.resultCode !== 0) {
      response.status(400).json({
        error: initResult.resultDesc || "Coda init failed",
        resultCode: initResult.resultCode,
        resultDesc: initResult.resultDesc,
        orderId,
        env,
        correlationId,
      });
      return;
    }

    // Always return txnId as a string — numeric JSON would lose precision in browsers.
    const txnId =
      extractedTxnId ||
      (initResult.txnId !== undefined && initResult.txnId !== null ?
        String(initResult.txnId) :
        null);

    response.status(200).json({
      orderId,
      env,
      txnId,
      clientSecret: initResult.clientSecret,
      resultCode: initResult.resultCode,
      resultDesc: initResult.resultDesc || "Success",
      correlationId,
    });
  } catch (error) {
    logger.error("Error in codaCardInit", error);
    response.status(502).json({
      error: "Unable to reach Coda init API",
      detail: (error as Error).message,
      correlationId,
    });
  }
});

/**
 * Proxy Coda payment status inquiry with full debug observability.
 */
export const codaCardInquiry = onRequest(async (request, response) => {
  setCodaCors(response);

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed. Use POST."});
    return;
  }

  const body = request.body as {
    env?: string;
    apiKey?: string;
    projectId?: string | number;
    country?: string | number;
    txnId?: string | number;
    orderId?: string;
    correlationId?: string;
  };

  const env = (body.env === "production" ? "production" : "sandbox") as CodaEnv;
  const apiKey = (body.apiKey || "").trim();
  const projectId = body.projectId;
  const country = body.country;
  const txnId = body.txnId;
  const orderId = (body.orderId || "").trim() || null;
  const correlationId =
    (body.correlationId || "").trim() ||
    orderId ||
    String(txnId || `corr_${Date.now()}`);

  try {
    if (!apiKey || projectId === undefined || country === undefined ||
      txnId === undefined || txnId === null || String(txnId).trim() === "") {
      response.status(400).json({
        error: "Missing required fields: apiKey, projectId, country, txnId",
      });
      return;
    }

    const {inquiryUrl} = codaUrls(env);
    const inquiryPaymentRequest = {
      apiKey,
      country: Number(country),
      projectId: String(projectId),
      txnId: String(txnId),
      needStatusFinal: "true",
    };

    const {json} = await observedCodaFetch({
      env,
      step: "Coda status inquiry",
      method: "POST",
      url: inquiryUrl,
      requestPayload: {inquiryPaymentRequest},
      correlationId,
      orderId,
      txnId: String(txnId),
      interpret: (parsed) => {
        const paymentResult = (parsed as {
          paymentResult?: {
            resultCode?: number;
            resultDesc?: string;
            profile?: {status?: string};
          };
        })?.paymentResult;
        const mapped = interpretResultCode(paymentResult?.resultCode);
        const status = paymentResult?.profile?.status;
        const desc = paymentResult?.resultDesc ?
          ` (${paymentResult.resultDesc})` :
          "";
        return {
          interpretedResult: status ?
            `${mapped.label}; profile.status=${status}${desc}` :
            `${mapped.label}${desc}`,
          badge: mapped.badge,
        };
      },
    });

    const paymentResult = (json as {
      paymentResult?: {
        resultCode?: number;
        resultDesc?: string;
        txnId?: string;
        orderId?: string;
        totalPrice?: number;
        profile?: {
          status?: string;
          isStatusFinal?: string | boolean;
          PaymentType?: string;
        };
      };
    })?.paymentResult;

    if (!paymentResult) {
      response.status(502).json({
        error: "Missing paymentResult from Coda",
        body: json,
        correlationId,
      });
      return;
    }

    const resultCode = Number(paymentResult.resultCode);
    let status = paymentResult.profile?.status;
    if (!status) {
      if (resultCode === 0) status = "success";
      else if (resultCode === 431 || resultCode === 481 || resultCode === 216) {
        status = "pending";
      } else status = "failed";
    }

    response.status(200).json({
      env,
      txnId: paymentResult.txnId != null ?
        String(paymentResult.txnId) :
        String(txnId),
      orderId: paymentResult.orderId ?? orderId,
      resultCode,
      resultDesc: paymentResult.resultDesc,
      totalPrice: paymentResult.totalPrice,
      status,
      isStatusFinal: paymentResult.profile?.isStatusFinal,
      paymentType: paymentResult.profile?.PaymentType,
      paymentResult,
      correlationId,
    });
  } catch (error) {
    logger.error("Error in codaCardInquiry", error);
    response.status(502).json({
      error: "Unable to reach Coda inquiry API",
      detail: (error as Error).message,
      correlationId,
    });
  }
});

/**
 * Optional complete-notification webhook (GET query params).
 * Always records an INBOUND debug event. Checksum verified when merchant secret
 * + apiKey are provided (query/body/env). Primary PE Ops flow still uses inquiry.
 */
export const codaCardWebhook = onRequest(async (request, response) => {
  setCodaCors(response);

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  const params: Record<string, string> = {};
  const source = {
    ...((request.query || {}) as Record<string, unknown>),
    ...((request.body || {}) as Record<string, unknown>),
  };
  for (const [k, v] of Object.entries(source)) {
    if (v !== undefined && v !== null) params[k] = String(v);
  }

  const orderId = params.OrderId || params.orderId || null;
  const txnId = params.TxnId || params.txnId || null;
  const resultCode = params.ResultCode || params.resultCode;
  const correlationId = orderId || txnId || `wh_${Date.now()}`;
  const apiKey =
    params.apiKey ||
    process.env.CODA_API_KEY ||
    "";
  const merchantSecret =
    params.merchantSecret ||
    process.env.CODA_MERCHANT_SECRET ||
    "";

  let checksumVerified: boolean | null = null;
  if (merchantSecret && apiKey && (params.Checksum || params.checksum)) {
    checksumVerified = verifyCodaChecksum(params, apiKey, merchantSecret);
  }

  const mapped = interpretResultCode(resultCode);
  await recordDebugEvent({
    correlationId,
    orderId,
    txnId,
    direction: "INBOUND",
    step: "webhook received",
    method: request.method,
    url: request.originalUrl || "/codaCardWebhook",
    requestPayload: params,
    responseStatus: checksumVerified === false ? 401 : 200,
    responseBody: {
      ack: checksumVerified === false ? "checksum_failed" : "ResultCode=0",
    },
    latencyMs: 0,
    interpretedResult: mapped.label,
    badge: checksumVerified === false ? "error" : mapped.badge,
    checksumVerified,
    error: checksumVerified === false ? "Checksum verification failed" : null,
  });

  if (checksumVerified === false) {
    response.status(401).send("checksum_failed");
    return;
  }

  // Quick ack so Coda stops retrying. Fulfillment still gated on inquiry.
  response.status(200).send("ResultCode=0");
});

/**
 * Ingest frontend lifecycle summaries into the same debug stream.
 */
export const codaCardDebugIngest = onRequest(async (request, response) => {
  setCodaCors(response);

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (!isDebugPanelEnabled()) {
    response.status(404).json({error: "Debug panel disabled"});
    return;
  }

  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed. Use POST."});
    return;
  }

  const token = debugAccessToken();
  if (token) {
    const provided = String(request.get("X-Coda-Debug-Token") || "");
    if (provided !== token) {
      response.status(401).json({error: "Unauthorized debug token"});
      return;
    }
  }

  const body = request.body as {
    correlationId?: string;
    orderId?: string;
    txnId?: string | number;
    step?: string;
    message?: string;
    payload?: unknown;
    badge?: "success" | "pending" | "failed" | "info" | "error";
    env?: CodaEnv;
  };

  const event = await recordDebugEvent({
    correlationId:
      (body.correlationId || "").trim() ||
      (body.orderId || "").trim() ||
      `fe_${Date.now()}`,
    orderId: body.orderId || null,
    txnId: body.txnId !== undefined ? String(body.txnId) : null,
    direction: "INTERNAL",
    step: body.step || "frontend event",
    method: "CLIENT",
    url: "frontend://coda-hosted-card",
    requestPayload: body.payload ?? {message: body.message},
    responseStatus: null,
    responseBody: null,
    latencyMs: null,
    interpretedResult: body.message || body.step || "frontend event",
    badge: body.badge || "info",
    env: body.env || null,
  });

  response.status(200).json({ok: true, id: event.id});
});

/**
 * Live debug feed for the in-app activity panel (newest first).
 */
export const codaCardDebugFeed = onRequest(async (request, response) => {
  setCodaCors(response);

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }

  if (!isDebugPanelEnabled()) {
    response.status(404).json({
      error: "Debug panel disabled",
      hint: "Set CODA_DEBUG_PANEL_ENABLED=true to enable",
    });
    return;
  }

  if (request.method !== "GET" && request.method !== "POST") {
    response.status(405).json({error: "Method not allowed"});
    return;
  }

  const token = debugAccessToken();
  if (token) {
    const provided = String(
      request.get("X-Coda-Debug-Token") ||
        (request.query.token as string) ||
        ""
    );
    if (provided !== token) {
      response.status(401).json({error: "Unauthorized debug token"});
      return;
    }
  }

  const orderId = String(
    request.query.orderId ||
      (request.body && request.body.orderId) ||
      ""
  ).trim() || undefined;
  const txnId = String(
    request.query.txnId ||
      (request.body && request.body.txnId) ||
      ""
  ).trim() || undefined;
  const limit = Number(request.query.limit || 100);

  const events = await listDebugEvents({orderId, txnId, limit});
  response.status(200).json({
    enabled: true,
    count: events.length,
    events,
  });
});

/**
 * PART F stub — Authorize & Capture separation (disabled by default).
 */
export const codaCardCapture = onRequest(async (request, response) => {
  setCodaCors(response);
  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }
  response.status(501).json({
    error: "Authorize & Capture separation is disabled",
    enabled: false,
    hint: "Requires Coda account enablement + POST notifications",
  });
});

/**
 * PART F stub — Cancel an authorized payment (disabled by default).
 */
export const codaCardCancel = onRequest(async (request, response) => {
  setCodaCors(response);
  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }
  response.status(501).json({
    error: "Authorize & Capture cancel is disabled",
    enabled: false,
  });
});

