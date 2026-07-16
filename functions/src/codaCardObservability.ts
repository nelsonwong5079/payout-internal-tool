import {createHash, timingSafeEqual} from "crypto";
import {initializeApp, getApps} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

export type CodaEnv = "sandbox" | "production";
export type DebugBadge = "success" | "pending" | "failed" | "info" | "error";
export type DebugDirection = "OUTBOUND" | "INBOUND" | "INTERNAL";

export interface CodaDebugEvent {
  id?: string;
  timestamp: string;
  correlationId: string;
  orderId?: string | null;
  txnId?: string | null;
  direction: DebugDirection;
  step: string;
  method: string;
  url: string;
  requestPayload: unknown;
  responseStatus?: number | null;
  responseBody?: unknown;
  latencyMs?: number | null;
  interpretedResult?: string | null;
  badge: DebugBadge;
  checksumVerified?: boolean | null;
  error?: string | null;
  env?: CodaEnv | null;
}

const COLLECTION = "coda_card_debug_events";

/** In-process fallback when Firestore is unavailable. */
const memoryRing: CodaDebugEvent[] = [];

function ensureAdmin(): void {
  if (!getApps().length) {
    initializeApp();
  }
}

export function isDebugPanelEnabled(): boolean {
  const raw = (process.env.CODA_DEBUG_PANEL_ENABLED || "true").toLowerCase();
  return raw === "1" || raw === "true" || raw === "yes";
}

export function debugMaxEvents(): number {
  const n = Number(process.env.CODA_DEBUG_MAX_EVENTS || "200");
  return Number.isFinite(n) && n > 0 ? Math.min(Math.floor(n), 2000) : 200;
}

export function debugAccessToken(): string {
  return (process.env.CODA_DEBUG_ACCESS_TOKEN || "").trim();
}

export function maskSecret(value: unknown): string {
  const s = value === undefined || value === null ? "" : String(value);
  if (!s) return "";
  if (s.length <= 8) return "••••";
  return `${s.slice(0, 4)}…${s.slice(-4)}`;
}

const SENSITIVE_KEYS = new Set([
  "apikey",
  "api_key",
  "coda_api_key",
  "merchantsecret",
  "merchant_secret",
  "coda_merchant_secret",
  "clientsecret",
  "client_secret",
  "authorization",
  "password",
  "secret",
  "cardnumber",
  "card_number",
  "cvv",
  "cvc",
  "securitycode",
  "pan",
]);

function isSensitiveKey(key: string): boolean {
  const normalized = key.replace(/[^a-z0-9]/gi, "").toLowerCase();
  if (SENSITIVE_KEYS.has(normalized)) return true;
  if (normalized.includes("secret")) return true;
  if (normalized.includes("apikey")) return true;
  if (normalized.includes("cardnumber") || normalized === "pan") return true;
  if (normalized === "cvv" || normalized === "cvc") return true;
  return false;
}

/**
 * Deep-clone and redact secrets / card-like fields for safe panel display.
 * @param {unknown} input Arbitrary JSON-like value
 * @return {unknown} Redacted clone
 */
export function redactForDebug(input: unknown): unknown {
  if (input === null || input === undefined) return input;
  if (typeof input === "string") {
    // JWT-shaped client secrets
    if (input.startsWith("eyJ") && input.length > 40) {
      return maskSecret(input);
    }
    // Long digit sequences that look like PANs
    if (/^\d{12,19}$/.test(input.replace(/\s+/g, ""))) {
      return "••••••••••••";
    }
    return input;
  }
  if (typeof input !== "object") return input;
  if (Array.isArray(input)) return input.map((v) => redactForDebug(v));

  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(input as Record<string, unknown>)) {
    if (isSensitiveKey(key)) {
      out[key] = maskSecret(value);
    } else {
      out[key] = redactForDebug(value);
    }
  }
  return out;
}

export function codaUrls(env: CodaEnv): {initUrl: string; inquiryUrl: string} {
  if (env === "production") {
    return {
      initUrl:
        "https://airtime.codapayments.com/airtime/api/restful/v2.0/Payment/Component/init.json",
      inquiryUrl:
        "https://airtime.codapayments.com/airtime/api/restful/v2.0/Payment/inquiryPaymentResult.json",
    };
  }
  return {
    initUrl:
      "https://sandbox.codapayments.com/airtime/api/restful/v2.0/Payment/Component/init.json",
    inquiryUrl:
      "https://sandbox.codapayments.com/airtime/api/restful/v2.0/Payment/inquiryPaymentResult.json",
  };
}

export function interpretResultCode(resultCode: unknown): {
  label: string;
  badge: DebugBadge;
} {
  const code = Number(resultCode);
  if (!Number.isFinite(code)) {
    return {label: `resultCode=${String(resultCode)}`, badge: "info"};
  }
  if (code === 0) return {label: "resultCode=0 → SUCCESS", badge: "success"};
  if (code === 431 || code === 481 || code === 216) {
    return {label: `resultCode=${code} → PENDING`, badge: "pending"};
  }
  return {label: `resultCode=${code} → FAILED`, badge: "failed"};
}

/**
 * Common Codapay complete-notification checksum:
 * md5(TxnId + apiKey + OrderId + ResultCode + merchantSecret)
 * Field order may vary by account — panel records pass/fail either way.
 * @param {Record<string, string>} params Notification params
 * @param {string} apiKey API key
 * @param {string} merchantSecret Merchant secret
 * @return {boolean} Whether checksum matches
 */
export function verifyCodaChecksum(
  params: Record<string, string>,
  apiKey: string,
  merchantSecret: string
): boolean {
  const txnId = params.TxnId || params.txnId || "";
  const orderId = params.OrderId || params.orderId || "";
  const resultCode = params.ResultCode || params.resultCode || "";
  const checksum = params.Checksum || params.checksum || "";
  if (!checksum || !merchantSecret) return false;

  const candidates = [
    `${txnId}${apiKey}${orderId}${resultCode}${merchantSecret}`,
    `${txnId}${orderId}${resultCode}${merchantSecret}`,
    `${apiKey}${txnId}${orderId}${resultCode}${merchantSecret}`,
  ];

  const provided = Buffer.from(checksum.toLowerCase());
  for (const raw of candidates) {
    const digest = createHash("md5").update(raw).digest("hex");
    const expected = Buffer.from(digest.toLowerCase());
    if (
      provided.length === expected.length &&
      timingSafeEqual(provided, expected)
    ) {
      return true;
    }
  }
  return false;
}

async function trimRetention(): Promise<void> {
  const max = debugMaxEvents();
  while (memoryRing.length > max) memoryRing.pop();

  try {
    ensureAdmin();
    const db = getFirestore();
    const snap = await db
      .collection(COLLECTION)
      .orderBy("timestamp", "desc")
      .offset(max)
      .limit(50)
      .get();
    if (snap.empty) return;
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  } catch (error) {
    logger.warn("coda debug retention trim failed", error);
  }
}

/**
 * Persist a debug event (always logs; stores when possible).
 * @param {Omit<CodaDebugEvent, "timestamp"|"id"> & {timestamp?: string}} partial Event
 * @return {Promise<CodaDebugEvent>} Stored event
 */
export async function recordDebugEvent(
  partial: Omit<CodaDebugEvent, "timestamp" | "id"> & {timestamp?: string}
): Promise<CodaDebugEvent> {
  const event: CodaDebugEvent = {
    ...partial,
    timestamp: partial.timestamp || new Date().toISOString(),
    requestPayload: redactForDebug(partial.requestPayload),
    responseBody: redactForDebug(partial.responseBody),
  };

  logger.info("coda_debug_event", {
    structuredData: true,
    ...event,
  });

  memoryRing.unshift(event);
  await trimRetention();

  try {
    ensureAdmin();
    const db = getFirestore();
    const ref = await db.collection(COLLECTION).add({
      ...event,
      createdAt: FieldValue.serverTimestamp(),
    });
    event.id = ref.id;
  } catch (error) {
    logger.warn("coda debug Firestore write failed; using memory ring", error);
    event.id = `mem_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  }

  return event;
}

/**
 * Fetch recent debug events, newest first.
 * @param {{orderId?: string, txnId?: string, limit?: number}} filters Filters
 * @return {Promise<CodaDebugEvent[]>} Events
 */
export async function listDebugEvents(filters: {
  orderId?: string;
  txnId?: string;
  limit?: number;
}): Promise<CodaDebugEvent[]> {
  const limit = Math.min(filters.limit || 100, debugMaxEvents());

  try {
    ensureAdmin();
    const db = getFirestore();
    let query = db.collection(COLLECTION).orderBy("timestamp", "desc");

    // Firestore inequality/compound limits: filter in memory when needed.
    const snap = await query.limit(Math.min(limit * 3, debugMaxEvents())).get();
    let events = snap.docs.map((doc) => {
      const data = doc.data() as CodaDebugEvent;
      return {...data, id: doc.id};
    });

    if (filters.orderId) {
      events = events.filter((e) => e.orderId === filters.orderId);
    }
    if (filters.txnId) {
      events = events.filter((e) => String(e.txnId) === String(filters.txnId));
    }
    return events.slice(0, limit);
  } catch (error) {
    logger.warn("coda debug Firestore read failed; using memory ring", error);
    let events = [...memoryRing];
    if (filters.orderId) {
      events = events.filter((e) => e.orderId === filters.orderId);
    }
    if (filters.txnId) {
      events = events.filter((e) => String(e.txnId) === String(filters.txnId));
    }
    return events.slice(0, limit);
  }
}

/**
 * Execute an outbound Coda HTTP call with full observability.
 * @param {object} args Call args
 * @return {Promise<{status: number, text: string, json: unknown, latencyMs: number}>}
 */
export async function observedCodaFetch(args: {
  env: CodaEnv;
  step: string;
  method: string;
  url: string;
  requestPayload: unknown;
  correlationId: string;
  orderId?: string | null;
  txnId?: string | null;
  interpret?: (json: unknown, status: number) => {
    interpretedResult: string;
    badge: DebugBadge;
  };
}): Promise<{status: number; text: string; json: unknown; latencyMs: number}> {
  const started = Date.now();
  try {
    const upstream = await fetch(args.url, {
      method: args.method,
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(args.requestPayload),
    });
    const text = await upstream.text();
    const latencyMs = Date.now() - started;
    let json: unknown = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = {raw: text};
    }

    const interpreted = args.interpret ?
      args.interpret(json, upstream.status) :
      {
        interpretedResult: `HTTP ${upstream.status}`,
        badge: (upstream.ok ? "info" : "error") as DebugBadge,
      };

    await recordDebugEvent({
      correlationId: args.correlationId,
      orderId: args.orderId,
      txnId: args.txnId,
      direction: "OUTBOUND",
      step: args.step,
      method: args.method,
      url: args.url,
      requestPayload: args.requestPayload,
      responseStatus: upstream.status,
      responseBody: json,
      latencyMs,
      interpretedResult: interpreted.interpretedResult,
      badge: interpreted.badge,
      env: args.env,
      error: upstream.ok ? null : `Upstream HTTP ${upstream.status}`,
    });

    return {status: upstream.status, text, json, latencyMs};
  } catch (error) {
    const latencyMs = Date.now() - started;
    const detail = (error as Error).message;
    await recordDebugEvent({
      correlationId: args.correlationId,
      orderId: args.orderId,
      txnId: args.txnId,
      direction: "OUTBOUND",
      step: args.step,
      method: args.method,
      url: args.url,
      requestPayload: args.requestPayload,
      responseStatus: null,
      responseBody: null,
      latencyMs,
      interpretedResult: "NETWORK/EXCEPTION",
      badge: "error",
      env: args.env,
      error: detail,
    });
    throw error;
  }
}
