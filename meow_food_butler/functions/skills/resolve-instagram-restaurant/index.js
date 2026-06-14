/**
 * Skill: resolveInstagramRestaurant (L2 Agent)
 *
 * Orchestrates the full Instagram-to-JSON Food Butler agentic flow:
 *
 *   fetchInstagramCaption  →  searchGooglePlace  →  fetchPlaceDetails
 *
 * Decision logic (mirrors insta_to_json_prompt.md):
 *   decision_1: Use locationName as search query if non-empty,
 *               otherwise fall back to first 60 chars of caption's first line.
 *   decision_2: Abort with structured error at each step per 情境 1-7.
 *
 * This is a Genkit `generate`-backed agent: the model can call the L1 tools
 * in any order it chooses, but the system prompt guides the happy-path sequence.
 *
 * Required env: APIFY_TOKEN, GOOGLE_PLACES_API_KEY, OUTSCRAPER_API_KEY
 */

const { z } = require("genkit");
const { defineFetchInstagramCaption } = require("../fetch-instagram-caption");
const { defineSearchGooglePlace } = require("../search-google-place");
const { defineFetchPlaceDetails } = require("../fetch-place-details");

const logger = require("firebase-functions/logger");

// ─── Output schema ────────────────────────────────────────────────────────────

const RestaurantSchema = z.object({
  id: z.null(),
  placeId: z.string(),
  placeTitle: z.string(),
  placeAddress: z.string(),
  latitude: z.number().nullable(),
  longitude: z.number().nullable(),
  rating: z.number(),
  workingHours: z.record(z.array(z.string())),
  popularTimes: z.array(z.unknown()),
  originalURL: z.string(),
  photoPaths: z.array(z.string()),
  photoUrls: z.array(z.string()),
  personalRating: z.number(),
  personalNote: z.string(),
  isDone: z.boolean(),
  createdTime: z.string(),
});

const AgentOutputSchema = z.union([
  RestaurantSchema,
  z.object({ error: z.string() }),
]);

// ─── Error strings (情境 1-7) ─────────────────────────────────────────────────

const Errors = {
  noInstagramData: "無法解析 Instagram 連結",
  noNameDetected: "無法識別餐廳名稱",
  noGooglePlace: "找不到對應餐廳，請手動輸入店名",
  noOutscraperPlace: "找不到對應餐廳商家資訊",
  outscraperTimeout: "找不到對應餐廳商家資訊 (timeout)",
};

// ─── Agent definition ─────────────────────────────────────────────────────────

function defineResolveInstagramRestaurant(ai) {
  // Register L1 tools so Genkit knows about them
  const fetchCaption = defineFetchInstagramCaption(ai);
  const searchPlace = defineSearchGooglePlace(ai);
  const fetchDetails = defineFetchPlaceDetails(ai);

  return ai.defineTool(
    {
      name: "resolveInstagramRestaurant",
      description:
        "L2 agent. Given an Instagram Reels URL, runs the full Food Butler " +
        "pipeline: scrape caption/location → find Google Place → fetch " +
        "Outscraper business details. Returns a Firestore-ready Restaurant " +
        "JSON, or { error: '...' } on failure.",
      inputSchema: z.object({
        url: z.string().url().describe("Instagram Reels URL"),
      }),
      outputSchema: AgentOutputSchema,
    },
    async ({ url }) => {
      // ── Step 1: Instagram caption ────────────────────────────────────────
      const ig = await fetchCaption({ url });
      logger.info(`Step 1 - Instagram, { caption: ${ig.caption?.slice(0, 80)}, locationName: ig.locationName }`); // debug
      if (!ig.caption && !ig.locationName) {
        return { error: Errors.noInstagramData };
      }

      // ── decision_1: Build search query ───────────────────────────────────
      // Priority: locationName → first line of caption (≤60 chars)
      const searchQuery = buildSearchQuery(ig.caption, ig.locationName);
      logger.info(`Step 2 - Search query, { ${searchQuery} }`); // debug
      if (!searchQuery) {
        return { error: Errors.noNameDetected };
      }

      // ── Step 2: Google Places ────────────────────────────────────────────
      const place = await searchPlace({ query: searchQuery });
      logger.info(`Step 3 - Google Place", { placeId: ${place.placeId}, displayName: ${place.displayName} }`); // debug
      if (!place.placeId) {
        return { error: Errors.noGooglePlace };
      }

      // ── Step 3: Outscraper details ───────────────────────────────────────
      const details = await fetchDetails({ placeId: place.placeId });
      logger.info(`Step 4 - Outscraper, { found: ${details.found}, timedOut: ${details.timedOut}, name: ${details.name} }`); // debug

      // decision_2: Timeout vs not-found
      if (details.timedOut) {
        return { error: Errors.outscraperTimeout };
      }
      if (!details.found) {
        return { error: Errors.noOutscraperPlace };
      }

      // ── Assemble Restaurant JSON ─────────────────────────────────────────
      return {
        id: null,
        placeId: place.placeId,
        placeTitle: details.name,              // kept as-is per user request
        placeAddress: details.fullAddress,
        latitude: details.latitude,
        longitude: details.longitude,
        rating: details.rating,
        workingHours: details.workingHours,
        popularTimes: details.popularTimes,   // [] if Outscraper returned null (情境 6)
        originalURL: url,
        photoPaths: [],
        photoUrls: details.photoUrls,         // [] if none returned (情境 5)
        personalRating: 0.0,
        personalNote: ig.caption,
        isDone: false,
        createdTime: new Date().toISOString(),
      };
    },
  );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * decision_1: Prefer locationName; fall back to first line of caption ≤60 chars.
 * Returns null if neither yields a usable string (triggers 情境 2).
 */
function buildSearchQuery(caption, locationName) {
  const loc = locationName?.trim();
  if (loc) return loc;

  const firstLine = (caption ?? "").split("\n")[0].trim();
  if (!firstLine) return null;

  return firstLine.length > 60 ? firstLine.slice(0, 60) : firstLine;
}

module.exports = { defineResolveInstagramRestaurant };