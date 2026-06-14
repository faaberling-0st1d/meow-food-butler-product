/**
 * Skill: fetchInstagramCaption (L1)
 *
 * Scrapes an Instagram Reels URL via Apify (apify~instagram-scraper),
 * polls until the run succeeds, and returns the caption + locationName.
 *
 * Port of: test_apify_caption_speed.py
 * Required env: APIFY_TOKEN
 */

const { z } = require("genkit");

const ACTOR_ID = "apify~instagram-scraper";
const APIFY_BASE = "https://api.apify.com/v2";
const POLL_INTERVAL_MS = 3_000;
const TIMEOUT_MS = 90_000;

function defineFetchInstagramCaption(ai) {
  return ai.defineTool(
    {
      name: "fetchInstagramCaption",
      description:
        "L1 skill. Given an Instagram Reels URL, returns the post caption " +
        "and check-in locationName. Uses Apify instagram-scraper actor with " +
        "polling until SUCCEEDED (up to 90 s). Returns empty strings on failure.",
      inputSchema: z.object({
        url: z.string().url().describe("Instagram Reels URL"),
      }),
      outputSchema: z.object({
        caption: z.string().describe("Full Instagram post caption"),
        locationName: z.string().describe("Check-in location tag (may be empty)"),
      }),
    },
    async ({ url }) => {
      const token = process.env.APIFY_TOKEN;
      if (!token) throw new Error("Missing env: APIFY_TOKEN");

      // 1. Start the actor run
      const startRes = await fetch(
        `${APIFY_BASE}/acts/${ACTOR_ID}/runs?token=${token}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            directUrls: [url],
            resultsType: "posts",
            resultsLimit: 1,
            addParentData: false,
          }),
        },
      );

      if (!startRes.ok) {
        console.error("Apify start failed:", await startRes.text());
        return { caption: "", locationName: "" };
      }

      const { data: runData } = await startRes.json();
      const runId = runData.id;

      // 2. Poll for SUCCEEDED / terminal
      const deadline = Date.now() + TIMEOUT_MS;
      let statusData;

      while (true) {
        await sleep(POLL_INTERVAL_MS);

        const statusRes = await fetch(
          `${APIFY_BASE}/actor-runs/${runId}?token=${token}`,
        );
        statusData = (await statusRes.json()).data;
        const { status } = statusData;

        if (status === "SUCCEEDED") break;
        if (["FAILED", "ABORTED", "TIMED-OUT"].includes(status)) {
          console.error("Apify run terminal:", status);
          return { caption: "", locationName: "" };
        }
        if (Date.now() > deadline) {
          console.error("fetchInstagramCaption: polling timeout");
          return { caption: "", locationName: "" };
        }
      }

      // 3. Read dataset
      const datasetId = statusData.defaultDatasetId;
      const itemsRes = await fetch(
        `${APIFY_BASE}/datasets/${datasetId}/items?token=${token}&format=json`,
      );
      const items = await itemsRes.json();

      if (!items?.length) return { caption: "", locationName: "" };

      return {
        caption: items[0].caption ?? "",
        locationName: items[0].locationName ?? "",
      };
    },
  );
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

module.exports = { defineFetchInstagramCaption };