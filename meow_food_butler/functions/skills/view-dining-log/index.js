/**
 * Skill: viewDiningLog (L2) — look up the user's OWN past dining experiences.
 *
 * Answers "show my last meal" / "the last time I ate ramen". The experiences
 * are written by the client (`ExperienceRepository`) under
 * `users/{uid}/experiences`; Firestore has no full-text search, so this reads
 * the most recent N and filters in-function (same brute-force style as the RAG
 * memory cosine ranking) by place name, tags, or note.
 *
 * On a match it records a `showExperienceCard` action into the request-scoped
 * `context.actions` collector — `agent/flow.js` returns that to the client,
 * which injects the tappable card by id. The tool's RETURN value (place/date)
 * is what the LLM uses to phrase a short, accurate reply.
 */

const { z } = require("genkit");
const logger = require("firebase-functions/logger");

const { experiencesCol, DEMO_USER } = require("../../collections");

// How many recent experiences to scan when filtering by keyword.
const SCAN_LIMIT = 100;

/** Whether an experience doc matches an already-lowercased keyword. */
function matchesNeedle(data, needle) {
  const haystack = [
    data.placeTitle,
    data.personalNote,
    ...(Array.isArray(data.personalTags) ? data.personalTags : []),
  ]
    .filter((s) => typeof s === "string" && s)
    .join(" ")
    .toLowerCase();
  return haystack.includes(needle);
}

/** Format a Firestore Timestamp as a Taiwan (UTC+8) date, matching the card. */
function taiwanDate(ts) {
  if (!ts || typeof ts.toDate !== "function") return null;
  const t = new Date(ts.toDate().getTime() + 8 * 60 * 60 * 1000);
  const y = t.getUTCFullYear();
  const m = String(t.getUTCMonth() + 1).padStart(2, "0");
  const d = String(t.getUTCDate()).padStart(2, "0");
  return `${y}/${m}/${d}`;
}

function defineViewDiningLog(ai) {
  return ai.defineTool(
    {
      name: "viewDiningLog",
      description:
        "Look up the user's OWN past dining experiences (their saved meal log). " +
        "Call this when the user wants to SEE a meal they already logged — e.g. " +
        "'show my last meal', 'find the last time I ate ramen', 'what did I eat " +
        "at that pasta place'. Pass `query` for a cuisine/dish/place keyword " +
        "(e.g. 'ramen'); omit it for their most recent meal overall. The app " +
        "shows the matching card automatically, so keep your reply short and do " +
        "NOT invent a place when found=false.",
      inputSchema: z.object({
        query: z
          .string()
          .optional()
          .describe(
            "Cuisine/dish/place keyword, e.g. 'ramen'. Omit for the latest meal.",
          ),
      }),
      outputSchema: z.object({
        found: z.boolean(),
        query: z.string().nullable(),
        placeTitle: z.string().nullable(),
        date: z.string().nullable(),
        rating: z.number().nullable(),
      }),
    },
    async ({ query }, { context }) => {
      const userId = (context && context.userId) || DEMO_USER;
      const needle = (query || "").trim().toLowerCase();

      let docs = [];
      try {
        const snap = await experiencesCol(userId)
          .orderBy("createdTime", "desc")
          .limit(SCAN_LIMIT)
          .get();
        docs = snap.docs;
      } catch (e) {
        logger.warn("viewDiningLog: experiences read failed", e);
      }

      // Docs are newest-first, so the first match is the latest one.
      let match = null;
      for (const doc of docs) {
        const data = doc.data() || {};
        if (needle && !matchesNeedle(data, needle)) continue;
        match = { id: doc.id, data };
        break;
      }

      if (!match) {
        return {
          found: false,
          query: query || null,
          placeTitle: null,
          date: null,
          rating: null,
        };
      }

      // Tell the client to inject the experience card by id. The model may call
      // this tool more than once in a turn (esp. with ambiguous phrasing), so
      // dedupe by id — otherwise the same card is shown several times.
      if (context && Array.isArray(context.actions)) {
        const already = context.actions.some(
          (a) =>
            a && a.type === "showExperienceCard" && a.experienceId === match.id,
        );
        if (!already) {
          context.actions.push({
            type: "showExperienceCard",
            experienceId: match.id,
          });
        }
      }

      const data = match.data;
      return {
        found: true,
        query: query || null,
        placeTitle: typeof data.placeTitle === "string" ? data.placeTitle : null,
        date: taiwanDate(data.createdTime),
        rating:
          typeof data.personalRating === "number" ? data.personalRating : null,
      };
    },
  );
}

module.exports = { defineViewDiningLog };
