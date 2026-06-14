/**
 * The butler's generate pipeline. Returns the structured `state(...)` payload in
 * all cases — never throws — so the frontend always has something to render.
 *
 * Pure-ish: it takes already-loaded conversation `history` and `recalled`
 * memory; the callable owns all Firestore IO (persistence, recall).
 *
 * Diagnostic hooks (send as the prompt) report REAL state, not a fabricated one:
 *   "/model" — prints the model id this function is configured to use.
 *   "/quota" — probes the live key(s) with a tiny call and reports the actual
 *              provider state (reachable / quota exceeded / invalid key / …).
 *   "/ok"    — the one forced state: a canned OK reply to exercise the UI without
 *              spending model quota.
 * "/model" and "/quota" return `ok:false` so they render as transient diagnostic
 * bubbles and never get persisted into the conversation.
 */

const { googleAI } = require("@genkit-ai/googleai");
const logger = require("firebase-functions/logger");

const { MODEL } = require("../config");
const { getButler, buildSystem } = require("./butler");
const { getGeminiKeys } = require("./keys");
const { state, classifyError } = require("./errors");

/** The real "GEMINI_API_KEY isn't bound to this function" state. */
function apiKeyMissingState() {
  return state(
    "API_KEY_MISSING",
    `🔑 GEMINI_API_KEY is NOT available to this function. ` +
      `Note: \`apphosting:secrets:access\` does not bind a secret to Cloud Functions. ` +
      `Run \`firebase functions:secrets:set GEMINI_API_KEY\` and redeploy so the ` +
      `\`secrets: [geminiApiKey]\` binding can inject it.`,
  );
}

/**
 * Run `generate` across the available keys, rotating past ANY failure — with
 * rapid key swaps a key may be quota'd, invalid, or not-yet-active, and one dud
 * shouldn't break the call. On the first success, `onSuccess(result, keyIndex)`
 * maps it to a state. If every key fails, returns
 * `{ failed: true, allQuota, lastClassified }` so the caller can phrase the
 * "all keys failed" message in its own voice.
 *
 * @param {string[]} keys
 * @param {object} opts
 * @param {string} opts.system
 * @param {Array}  opts.messages
 * @param {boolean} [opts.useTools]   - attach the butler's tools (skills).
 * @param {object} [opts.context]     - per-request context propagated to tools.
 * @param {(res:object, keyIndex:number) => object} opts.onSuccess
 */
async function generateAcrossKeys(keys, { system, messages, useTools = false, context, onSuccess }) {
  let lastClassified = null;
  let allQuota = true;
  for (let i = 0; i < keys.length; i += 1) {
    try {
      const { instance, tools } = getButler(keys[i]);
      const res = await instance.generate({
        model: googleAI.model("gemini-2.5-flash"),
        system,
        tools: useTools ? tools : undefined,
        messages,
        // Per-request context propagated to tools (whereAmI reads `location`,
        // recallMemory/remember read `userId`). Concurrency-safe: not shared state.
        context,
      });
      if (i > 0) {
        logger.info(`Gemini succeeded on key #${i + 1}/${keys.length} after rotation`);
      }
      return onSuccess(res, i);
    } catch (err) {
      lastClassified = classifyError(err);
      if (lastClassified.code !== "QUOTA_EXCEEDED") allQuota = false;
      logger.error("Gemini generate() failed", {
        keyIndex: i + 1,
        keyCount: keys.length,
        code: lastClassified.code,
        status: err && (err.status || err.code),
        message: err && err.message,
      });
      // Rotate to the next key.
    }
  }
  return { failed: true, allQuota, lastClassified };
}

/**
 * "/quota" handler: a real, minimal probe (no tools, fixed tiny prompt) across
 * the live key(s). Surfaces the genuine provider state via the same classifier
 * the real flow uses — so the message matches what a normal chat would hit.
 */
async function probeApiState(context) {
  const keys = await getGeminiKeys();
  if (!keys.length) return apiKeyMissingState();

  const result = await generateAcrossKeys(keys, {
    system: "Health check. Reply with the single word: pong.",
    messages: [{ role: "user", content: [{ text: "ping" }] }],
    useTools: false,
    context,
    onSuccess: (_res, i) =>
      state(
        "OK",
        `✅ ${MODEL} is reachable on key #${i + 1}/${keys.length} — quota looks available, nya.`,
        false, // diagnostic: render transiently, don't persist.
      ),
  });
  if (!result.failed) return result;

  if (result.allQuota) {
    return state(
      "QUOTA_EXCEEDED",
      `📉 All ${keys.length} Gemini key(s) hit their quota / rate limit for ${MODEL}. ` +
        `Wait for the daily reset, add more keys to the config/gemini doc (ideally from ` +
        `different GCP projects), or enable billing.`,
    );
  }
  return (
    result.lastClassified ||
    state("UPSTREAM_ERROR", `⚠️ ${MODEL} probe failed for an unknown reason.`)
  );
}

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
  // Request-scoped collector for client UI actions (e.g. show an experience
  // card). Tools push into it via `context.actions`; we return it on success.
  const actions = [];
  const reqContext = { location, now, userId, sessionId, actions };

  // --- Diagnostic hooks -----------------------------------------------------
  if (hook === "/model") {
    // Print the actual configured model — never a hardcoded name.
    return state("OK", `🐱 Current model: ${MODEL}`, false);
  }
  if (hook === "/quota") {
    return probeApiState(reqContext);
  }
  if (hook === "/ok") {
    return state(
      "OK",
      `😺 (forced) Meow! How about a cozy ramen spot in Da'an? You said: "${prompt}".`,
      true,
    );
  }

  // --- Credential check before we even try ----------------------------------
  const keys = await getGeminiKeys();
  if (!keys.length) return apiKeyMissingState();

  const system = buildSystem({ now, recalled });
  // Drive from the full conversation: prior turns + the new user turn.
  const messages = [...history, { role: "user", content: [{ text: prompt }] }];

  // --- Real model call with key rotation ------------------------------------
  const result = await generateAcrossKeys(keys, {
    system,
    messages,
    useTools: true,
    context: reqContext,
    // Attach any client actions a tool collected during the turn.
    onSuccess: ({ text }) => ({ ...state("OK", text, true), actions }),
  });
  if (!result.failed) return result;

  // Every available key failed.
  if (result.allQuota) {
    return state(
      "QUOTA_EXCEEDED",
      `😿 Error: all keys quota exceeded. All ${keys.length} Gemini key(s) hit their ` +
        `quota / rate limit for ${MODEL}. Add more keys to the config/gemini doc ` +
        `(ideally from different GCP projects), wait for the daily reset, or enable billing.`,
    );
  }
  return state(
    result.lastClassified ? result.lastClassified.code : "UPSTREAM_ERROR",
    `😿 Error: all ${keys.length} Gemini key(s) failed and none worked. ` +
      `Last issue: ${result.lastClassified ? result.lastClassified.reply : "unknown"}`,
  );
}

module.exports = { runButlerFlow };
