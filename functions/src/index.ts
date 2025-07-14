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

// Debug helper function
function debugLog(message: string, data?: any) {
  logger.info(`[DEBUG] ${message}`, {
    structuredData: true,
    debugData: data,
  });
}

// Simple send-email API that returns "hello"
export const sendEmail = onRequest((request, response) => {
  // BREAKPOINT 1: Function entry point
  debugLog("=== SEND EMAIL API CALLED ===");
  
  // BREAKPOINT 2: Request details
  const requestInfo = {
    method: request.method,
    url: request.url,
    headers: request.headers,
    body: request.body,
    query: request.query,
  };
  debugLog("Request details", requestInfo);

  // BREAKPOINT 3: CORS setup
  debugLog("Setting CORS headers");
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Methods", "GET, POST");
  response.set("Access-Control-Allow-Headers", "Content-Type");

  // BREAKPOINT 4: Preflight handling
  if (request.method === "OPTIONS") {
    debugLog("Handling OPTIONS preflight request");
    response.status(204).send("");
    return;
  }

  // BREAKPOINT 5: Response preparation
  debugLog("Preparing response");
  const responseData = {
    message: "hello",
    timestamp: new Date().toISOString(),
    debug: {
      requestMethod: request.method,
      requestUrl: request.url,
      userAgent: request.headers["user-agent"],
    },
  };

  // BREAKPOINT 6: Sending response
  debugLog("Sending response", responseData);
  response.status(200).json(responseData);
  
  // BREAKPOINT 7: Function completion
  debugLog("=== SEND EMAIL API COMPLETED ===");
});

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
