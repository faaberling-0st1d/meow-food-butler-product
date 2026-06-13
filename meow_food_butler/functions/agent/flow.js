/**
 * The butler's generate pipeline. Returns the structured `state(...)` payload in
 * all cases — never throws — so the frontend always has something to render.
 *
 * Pure-ish: it takes already-loaded conversation `history` and `recalled`
 * memory; the callable owns all Firestore IO (persistence, recall).
 *
 * Test hooks let the client force a state without configuring anything: send
 * "/quota", "/model", or "/ok" as the prompt.
 */

const { googleAI } = require("@genkit-ai/googleai");
const logger = require("firebase-functions/logger");

const { MODEL, resolveGeminiApiKeys } = require("../config");
const { getButler, buildSystem } = require("./butler");
const { state, classifyError } = require("./errors");

/**
 * @param {string} prompt
 * @param {object} ctx
 * @param {object} [ctx.location] - { latitude, longitude }
 * @param {object} [ctx.now]      - { local?, iso? }
 * @param {string} [ctx.userId]
 * @param {string} [ctx.sessionId]
 * @param {Array}  [ctx.history]  - prior Genkit messages (oldest-first, excl. current turn)
 * @param {Array}  [ctx.recalled] - top-k recalled memories
 */
async function runButlerFlow(prompt, ctx = {}) {
  const { location, now, userId, sessionId, history = [], recalled = [] } = ctx;
  const hook = prompt.trim().toLowerCase();

  // --- Forced states for testing the UI without real calls ------------------
  if (hook === "/quota") {
    return state("QUOTA_EXCEEDED", `📉 (forced) Quota exceeded for ${MODEL}.`);
  }
  if (hook === "/model") {
    return state("MODEL_NOT_FOUND", `🚫 (forced) Model "${MODEL}" not found or not enabled.`);
  }
  if (hook === "/ok") {
    return state(
      "OK",
      `😺 (forced) Meow! How about a cozy ramen spot in Da'an? You said: "${prompt}".`,
      true,
    );
  }

  // --- Credential check before we even try ----------------------------------
  const keys = resolveGeminiApiKeys();
  if (!keys.length) {
    return state(
      "API_KEY_MISSING",
      `🔑 GEMINI_API_KEY is NOT available to this function. ` +
        `Note: \`apphosting:secrets:access\` does not bind a secret to Cloud Functions. ` +
        `Run \`firebase functions:secrets:set GEMINI_API_KEY\` and redeploy so the ` +
        `\`secrets: [geminiApiKey]\` binding can inject it.`,
    );
  }

  const system = buildSystem({ now, recalled });
  // Drive from the full conversation: prior turns + the new user turn.
  const messages = [...history, { role: "user", content: [{ text: prompt }] }];

  // --- Real model call with QUOTA-based key rotation ------------------------
  // Try each available key in turn. On a quota / rate-limit error, rotate to the
  // next key; any OTHER error (bad key, model not found, …) short-circuits with
  // its message so we don't burn the remaining keys on a non-quota problem.
  for (let i = 0; i < keys.length; i += 1) {
    try {
      const { instance, tools } = getButler(keys[i]);
      const { text } = await instance.generate({
        model: googleAI.model("gemini-2.5-flash"),
        system,
        tools,
        messages,
        // Per-request context propagated to tools (whereAmI reads `location`,
        // recallMemory/remember read `userId`). Concurrency-safe: not shared state.
        context: { location, now, userId, sessionId },
      });
      if (i > 0) {
        logger.info(`Gemini succeeded on key #${i + 1}/${keys.length} after rotation`);
      }
      return state("OK", text, true);
    } catch (err) {
      const classified = classifyError(err);
      logger.error("Gemini generate() failed", {
        keyIndex: i + 1,
        keyCount: keys.length,
        code: classified.code,
        status: err && (err.status || err.code),
        message: err && err.message,
      });
      // Non-quota error: return it immediately. Quota: fall through to next key.
      if (classified.code !== "QUOTA_EXCEEDED") {
        return classified;
      }
    }
  }

  // Every available key is quota-exhausted.
  return state(
    "QUOTA_EXCEEDED",
    `😿 Error: all keys quota exceeded. All ${keys.length} GEMINI_API_KEY value(s) ` +
      `hit their quota / rate limit for ${MODEL}. Add more keys (newline- or ` +
      `comma-separated in the GEMINI_API_KEY secret, ideally from different GCP ` +
      `projects) and redeploy, wait for the daily reset, or enable billing.`,
  );
}

module.exports = { runButlerFlow };
