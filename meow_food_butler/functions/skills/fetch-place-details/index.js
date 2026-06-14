/**
 * Skill: fetchPlaceDetails (L1)
 *
 * Given a Google Place ID, fetches full business details from Outscraper
 * maps/search-v3: name, address, rating, working_hours, popular_times,
 * and up to 5 menu photo URLs.
 *
 * Handles Outscraper's async flow:
 *   POST → { status: "Pending", results_location: "..." }
 *   Poll results_location every 3 s → until status === "Success" or 60 s timeout.
 *
 * Port of: outscraper_menu.py + outscraper_popular_times.py +
 *           outscraper_coords.py + insta_to_json_prompt.md
 * Required env: OUTSCRAPER_API_KEY
 */

const { z } = require("genkit");
const logger = require("firebase-functions/logger");

const OUTSCRAPER_BASE = "https://api.app.outscraper.com";
const POLL_INTERVAL_MS = 3_000;
const TIMEOUT_MS = 60_000;

const EMPTY = {
  found: false,
  timedOut: false,
  name: "",
  fullAddress: "",
  rating: 0,
  workingHours: {},
  popularTimes: [],
  photoUrls: [],
  latitude: null,
  longitude: null,
};

const PopularTimeSlot = z.object({
  hour: z.number(),
  percentage: z.number(),
  time: z.string(),
  title: z.string(),
});

const PopularTimeDay = z.object({
  day: z.number(),
  day_text: z.string(),
  popular_times: z.array(PopularTimeSlot),
});

function defineFetchPlaceDetails(ai) {
  return ai.defineTool(
    {
      name: "fetchPlaceDetails",
      description:
        "L1 skill. Accepts a Google Place ID and returns full business details " +
        "from Outscraper: name, full_address, rating, working_hours (object), " +
        "popular_times (array, may be empty), and up to 5 menu photoUrls. " +
        "Falls back to Google Places API if Outscraper has no data.",
      inputSchema: z.object({
        placeId: z.string().describe("Google Place ID, e.g. ChIJ..."),
        photosLimit: z.number().int().min(1).max(10).default(5)
          .describe("Max menu photos to return"),
      }),
      outputSchema: z.object({
        found: z.boolean(),
        timedOut: z.boolean(),
        name: z.string(),
        fullAddress: z.string(),
        rating: z.number(),
        workingHours: z.record(z.array(z.string())),
        popularTimes: z.array(PopularTimeDay),
        photoUrls: z.array(z.string()),
        latitude: z.number().nullable(),
        longitude: z.number().nullable(),
      }),
    },
    async ({ placeId, photosLimit = 5 }) => {
      const apiKey = process.env.OUTSCRAPER_API_KEY;
      const placesKey = process.env.GOOGLE_PLACES_API_KEY;
      if (!apiKey) throw new Error("Missing env: OUTSCRAPER_API_KEY");
      if (!placesKey) throw new Error("Missing env: GOOGLE_PLACES_API_KEY");

      // 嘗試 1: Outscraper by Place ID
      let placeData = await outscraperQuery(`place_id:${placeId}`, apiKey, photosLimit);

      // 嘗試 2: Outscraper by 店名
      if (!placeData) {
        logger.info(`Outscraper place_id miss, trying name search, ${placeId}`);
        const nameRes = await fetch(
          `https://places.googleapis.com/v1/places/${placeId}`,
          {
            headers: {
              "X-Goog-Api-Key": placesKey,
              "X-Goog-FieldMask": "displayName,formattedAddress",
            },
          }
        );
        if (nameRes.ok) {
          const nameData = await nameRes.json();
          const query = `${nameData.displayName?.text ?? ""} ${nameData.formattedAddress ?? ""}`;
          placeData = await outscraperQuery(query, apiKey, photosLimit);
        }
      }

      // 嘗試 3: Google Places API fallback
      if (!placeData) {
        logger.info(`Outscraper name miss, falling back to Google Places, ${ placeId }`);
        return await googlePlacesFallback(placeId, placesKey, photosLimit);
      }

      return placeData;
    },
  );
}

async function outscraperQuery(query, apiKey, photosLimit) {
  const params = new URLSearchParams({
    query,
    limit: "1",
    tag: "menu",
    photosLimit: String(photosLimit),
    fields: "name,full_address,rating,working_hours,popular_times,photos_data,latitude,longitude",
    async: "true",
  });

  const initialRes = await fetch(`${OUTSCRAPER_BASE}/maps/search-v3?${params}`, {
    headers: { "X-API-KEY": apiKey },
  });
  if (!initialRes.ok) return null;

  let data = await initialRes.json();
  if (data.status === "Pending" && data.results_location) {
    data = await pollResults(data.results_location, apiKey);
    if (!data) return null;
  }

  const places = data.data ?? [];
  const placeData = Array.isArray(places[0]) ? places[0][0] : places[0];
  if (!placeData || !placeData.name) return null;

  const photosRaw = placeData.photos_data ?? [];
  const photoUrls = photosRaw
    .slice(0, photosLimit)
    .map((p) => p.photo_url_large ?? p.photo_url ?? "")
    .filter(Boolean);

  return {
    found: true,
    timedOut: false,
    name: placeData.name ?? "",
    fullAddress: placeData.full_address ?? "",
    rating: placeData.rating ?? 0,
    workingHours: placeData.working_hours ?? {},
    popularTimes: placeData.popular_times ?? [],
    photoUrls,
    latitude: placeData.latitude ?? null,
    longitude: placeData.longitude ?? null,
  };
}

async function googlePlacesFallback(placeId, apiKey, photosLimit) {
  const res = await fetch(
    `https://places.googleapis.com/v1/places/${placeId}`,
    {
      headers: {
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": [
          "displayName",
          "formattedAddress",
          "rating",
          "regularOpeningHours",
          "photos",
          "location",
        ].join(","),
      },
    }
  );

  if (!res.ok) return { ...EMPTY };

  const d = await res.json();

  const photoUrls = await Promise.all(
    (d.photos ?? []).slice(0, photosLimit).map(async (p) => {
      const photoRes = await fetch(
        `https://places.googleapis.com/v1/${p.name}/media?maxHeightPx=800&key=${apiKey}`
      );
      return photoRes.url ?? "";
    })
  ).then((urls) => urls.filter(Boolean));

  const workingHours = {};
  for (const period of d.regularOpeningHours?.weekdayDescriptions ?? []) {
    const [day, ...rest] = period.split(": ");
    workingHours[day] = [rest.join(": ")];
  }

  return {
    found: true,
    timedOut: false,
    name: d.displayName?.text ?? "",
    fullAddress: d.formattedAddress ?? "",
    rating: d.rating ?? 0,
    workingHours,
    popularTimes: [],
    photoUrls,
    latitude: d.location?.latitude ?? null,
    longitude: d.location?.longitude ?? null,
  };
}

async function pollResults(resultsLocation, apiKey) {
  const deadline = Date.now() + TIMEOUT_MS;
  while (Date.now() < deadline) {
    await sleep(POLL_INTERVAL_MS);
    const res = await fetch(resultsLocation, {
      headers: { "X-API-KEY": apiKey },
    });
    if (!res.ok) continue;
    const data = await res.json();
    if (data.status === "Success") return data;
  }
  logger.error("fetchPlaceDetails: Outscraper polling timed out");
  return null;
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

module.exports = { defineFetchPlaceDetails };