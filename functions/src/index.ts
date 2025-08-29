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

    response.status(200).json({
      success: true,
      data: results,
    });
  } catch (error) {
    logger.error("Error checking sandbox status", error);
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

// Scheduled function to check sandbox status at 9 AM and 1 PM GMT+8
export const scheduledSandboxCheck = onSchedule({
  schedule: "0 1,5 * * *", // 1 AM and 5 AM UTC = 9 AM and 1 PM GMT+8
  timeZone: "UTC",
  secrets: [emailAppPassword],
}, async () => {
  logger.info("Starting scheduled sandbox status check", {structuredData: true});

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

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

