/**
 * Skill: searchGooglePlace (L1)
 *
 * Resolves a free-text query (e.g. "圍爐烤肉 台南" or a locationName tag)
 * into a Google Place ID + canonical name + address via Places API v1.
 *
 * Port of: Tool 2 in insta_to_json_prompt.md
 * Required env: GOOGLE_PLACES_API_KEY
 */

const { z } = require("genkit");

const PLACES_URL = "https://places.googleapis.com/v1/places:searchText";

function defineSearchGooglePlace(ai) {
  return ai.defineTool(
    {
      name: "searchGooglePlace",
      description:
        "L1 skill. Accepts a natural-language restaurant query " +
        "(e.g. a locationName tag or the first line of a caption) and returns " +
        "the top Google Maps match: placeId, displayName, and formattedAddress. " +
        "Returns null fields when no match is found.",
      inputSchema: z.object({
        query: z
          .string()
          .describe(
            "Search string, e.g. locationName or first 60 chars of caption",
          ),
      }),
      outputSchema: z.object({
        placeId: z.string().describe("Google Place ID, empty string if not found"),
        displayName: z.string(),
        formattedAddress: z.string(),
      }),
    },
    async ({ query }) => {
      const apiKey = process.env.GOOGLE_PLACES_API_KEY;
      if (!apiKey) throw new Error("Missing env: GOOGLE_PLACES_API_KEY");

      const res = await fetch(PLACES_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask":
            "places.id,places.displayName,places.formattedAddress",
        },
        body: JSON.stringify({ textQuery: query }),
      });

      if (!res.ok) {
        console.error("Google Places error:", await res.text());
        return { placeId: "", displayName: "", formattedAddress: "" };
      }

      const { places } = await res.json();
      if (!places?.length) {
        return { placeId: "", displayName: "", formattedAddress: "" };
      }

      const first = places[0];
      return {
        placeId: first.id ?? "",
        displayName: first.displayName?.text ?? "",
        formattedAddress: first.formattedAddress ?? "",
      };
    },
  );
}

module.exports = { defineSearchGooglePlace };