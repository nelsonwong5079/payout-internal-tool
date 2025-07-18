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
import * as logger from "firebase-functions/logger";
import nodemailer from "nodemailer";
import * as archiver from "archiver";
// eslint-disable-next-line @typescript-eslint/no-var-requires
const ArchiverZipEncrypted = require("archiver-zip-encrypted");

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
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const archive = archiver.create("zip-encrypted", {
        zlib: {level: 8},
        encryptionMethod: "aes256",
        password: password,
      } as any);

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
export const sendEmail = onRequest(async (request, response) => {
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
        pass: "cwkb zqbq dwau aohd", // Use app password
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

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

