# Agent Design — Meow Food Butler

Our design focuses on **"Tools implementation"** and **"Memory"**. This document is
the implementation blueprint that decomposes the two design diagrams
(`flow_chart.drawio.png`, `agentic_flow.png`) into concrete subtasks.

The butler is a **narrow** agent: a food butler, not a general assistant. It
autonomously picks which skills to run, asks clarifying/confirmation questions,
and only exposes skills defined by the dev team.

---

## 1. Two-layer model (from `agentic_flow.png`)

The agent runs in two layers. Each box in the diagram is a **Skill** backed by a
**Tool**. Skills are LLM-orchestrated steps; Tools are deterministic functions
(Genkit tools / Cloud Functions) the LLM may call.

```
L1 — Initial Intelligence & Planning        L2 — Execution & Interaction
─────────────────────────────────────       ───────────────────────────────────────
User Context Identified                      Skill: Distance Calculation
  └ Skill: Find Free Time                       └ Tool: Maps API / Location Tool
       Tool: User Calendar                   ┌▶ Confirm with User? (Fri 5:30 PM)
  └ Skill: Memory Retrieval                  │     ├ No  → back to L1 Search & Parse
       Tool: Preferences DB (RAG)            │     └ Yes ▼
  └ Skill: Search & Parse ◀──────────────────┘  Skill: Departure Monitoring
       Tool: Web Scraper / IG Parser              Tool: Location Tracker
                                                Skill: Record Writing
                                                  Tool: Sentiment & Image AI
                                                User Confirms & Edits → Final Save
```

---

## 2. Runtime state machine (from `flow_chart.drawio.png`)

The canonical worked scenario: *user has no class Friday after 3:20, prefers
ramen, dislikes crowds, wants a <20 min walk → butler proposes Tai-He Ramen
(18 min walk), notifies, reminds, confirms arrival, and writes the experience.*

| # | State | Layer | Type | Transitions |
|---|-------|-------|------|-------------|
| S0 | **Data Analysis** — parse user context (free time, prefs, constraints) | L1 | entry | → S1 |
| S1 | **Source** — pull Web Recs / IG Saved Links | L1 | input | → S2 |
| S2 | **Calculation** — score candidates (e.g. Tai-He Ramen, 18m walk), add to Candidate List | L2 | process | → S3; self-loop `Reselect` |
| S3 | **Notify (5:30 PM Fri): User Accepts?** | L2 | decision | accept → S4; **reject → S2 (Reselect)** |
| S4 | **Departure Reminder (5:12 PM): User Moving?** | L2 | decision | moving → S5; **not moving → S0 (Reschedule)** |
| S5 | **Arrival Check (5:30 PM)** — GPS or manual confirmation | L2 | process | → S6 |
| S6 | **Post-1hr: Ask Experience** (retry limit: N) | L2 | decision | answered → S7; no-answer within N retries → end |
| S7 | **Auto-Generate Card** — Tags, Rating, Media → User Edit & Save | L2 | output | → persist `ExperienceCard` |

Loop-backs (the `jal x0, Lx` annotations):
- **S3 reject → S2**: pick the next candidate without re-planning.
- **S4 not-moving → S0**: full re-plan / reschedule.

---

## 3. Skills catalog

Each skill maps a diagram box to a backend Tool, its I/O, and the persisted data.
State column: ✅ exists · 🟡 stub · ⬜ to build.

| Skill | Tool (integration) | Input → Output | Backend binding | State |
|-------|--------------------|----------------|-----------------|-------|
| **Find Free Time** | User Calendar | calendar events → free slots (e.g. "Fri ≥3:20") | `calendar` service / `getFreeSlots` tool | ⬜ |
| **Memory Retrieval** | Preferences DB (RAG) | user query → ranked prefs/past experiences | `memory/store.js` (embeddings + cosine); `recallMemory` + `remember` tools | ✅ |
| **Memory Edit** | Memory + Constraint | changed/retracted taste → delete stale fact; changed walk limit → update profile | `forget` tool (`memory/store.js` cosine delete) + `setPreference` tool (`profile.maxWalkMinutes` only) | ✅ |
| **Search & Parse** | Web Scraper / IG Parser | location + prefs → candidate spots | `searchSpots` tool (Places API + IG saved links) | ⬜ |
| **Distance Calculation** | Maps API / Location | candidate + origin → walk time/route | `routeDistance` tool (Google Maps) | ⬜ |
| **Confirm with User** | FCM + chat | candidate → accept/reject | `chatWithButler` reply + push prompt | 🟡 |
| **Departure Monitoring** | Location Tracker | scheduled time + GPS → moving? | client geolocation + scheduled fn | ⬜ |
| **Arrival Check** | Location / manual | GPS vs spot → arrived? | scheduled fn + manual confirm | ⬜ |
| **Record Writing** | Sentiment & Image AI | user notes + photos → draft `ExperienceCard` | `draftExperience` tool (Gemini multimodal) | ⬜ |

---

## 4. Persona & system prompt

As a Meow Food Butler you are a **wise cat**. Talk in a cat-like tone — end
sentences with "meow", "nya", "prrr", etc., varying with the chat mood. Stay in
character but keep recommendations accurate and concise. (Genkit `system` prompt
in `index.js`.)

---

## 5. Memory (RAG)

本專案以 **RAG（檢索增強生成）** 為使用者建立長期記憶。每位使用者的記憶存於
Firestore 的 `users/{uid}/memory` 集合，並將 Gemini 產生的 **embedding 向量**直接存成
一個 array 欄位（不使用向量索引）。當使用者提問時，系統先把問句嵌入成向量，從該使用者的
記憶中最多取出 **`MAX_SCAN`（200）** 筆，逐筆以 **Cosine Similarity** 計算語意相似度、
排序後取 top-k，再注入系統提示，讓 butler 回答更貼近個人偏好。Cosine 衡量「方向相近度」，
分數高代表語意越相關；`MAX_SCAN` 則是 demo 規模下暴力比對的上限，避免掃描整個集合。

**`memory` 欄位裡儲存什麼、形式為何：**

- **`text`** — 蒸餾後的事實／偏好句子（字串），例：「使用者喜歡菠菜」。
- **`embedding`** — 對應 `text` 的數值向量（`number[]` 陣列），供 Cosine 比對。
- **`kind`** — 記憶類型標籤（字串，如 `note`、偏好等）。
- **`sessionId`** — 來源對話 session 的 id（字串／null）。
- **`createdAt`** — 伺服器寫入時間戳（timestamp）。

實作見 [`memory/store.js`](memory/store.js)（`embed` / `remember` / `recall` / `forget` / `cosine`）。
這是**蒸餾層**（事實／偏好），與 `sessions/store.js` 的逐字對話歷史分開。寫入由
`remember` skill（LLM 可呼叫）觸發；`recall` 為 best-effort，空集合或失敗時回傳 `[]`。
升級路徑：語料變大後改用 Firestore Vector Search（`findNearest`）取代暴力 cosine。

**收斂後的分工：口味走 memory，唯一可運算的限制走 profile。**

口味（喜歡／討厭的菜系、去過覺得不錯的店）一律放**自由文字 RAG memory**，不再進 `profile`
的結構化陣列——它們本來就是開放式、靠語意檢索的。`profile` 文件只保留 **`maxWalkMinutes`**
這一個欄位，因為它得是**數字**，agent 要拿它過濾候選（走路時間 ≤ N 分鐘）。這樣就不必在
memory 與 profile 之間同步重疊的 `likes`/`dislikes`。

- **`remember` / `forget`**（`memory/store.js`）：口味的新增與刪除。`forget` 把要遺忘的事實
  嵌入向量，刪除 `memory` 集合中 cosine ≥ `floor`（預設 0.82，刻意設高只刪明顯同義者）的
  記憶；回傳 `{ deleted, texts }`。
- **`setPreference`**（寫 `preferences/profile.maxWalkMinutes`）：只設定走路時間上限，`merge`
  寫入單一欄位，不碰口味。

當使用者**改變或收回口味**時：`forget` 舊事實 →（有新口味才）`remember` 新事實。
當使用者**改變走路上限**時：`setPreference` 覆寫 `maxWalkMinutes`。`recallMemory` 不再回
假資料——回傳 `maxWalkMinutes`（未設定為 `null`）＋ 召回的 memory 片段（口味由此而來）。

---

## 6. Backend mapping

- **Cloud Functions** (`index.js`): host the Genkit flow + tools. `chatWithButler`
  is the entry callable; planning/execution skills become Genkit **tools** the
  flow can call, plus **scheduled functions** for time-triggered states (S3 5:30,
  S4 5:12, S6 +1hr).
- **FCM**: push notifications for S3 (accept?), S4 (departure reminder), S6 (ask
  experience).
- **Firestore**: `FoodCard` (candidates), `ExperienceCard` (saved records),
  preferences/memory collections.
- **Models touched**: `FoodCard` (candidate list, S2), `ExperienceCard` (S7),
  `ChatMessage` (`recommendation` type carries `recommendedSpotIds` for the
  swipe-stack at S2/S3).

---

## 7. User commands

- `/skills` — list available skills (or ask "What skills do you have?").
- `/pat` — pat the butler; it "prrrr"s or reacts per mood.
- `/memory` — manage memory: **view** recalled facts (`recallMemory`), **forget**
  a stale taste (`forget`, cosine-delete from `memory`), and **set** the walk-time
  limit (`setPreference` on `profile.maxWalkMinutes`). Tastes live in free-text
  memory; only the numeric walk limit is structured.
- `/ok` — grant the agent permission to act (e.g. send notify, write record).
- `/reco` — quick-launch a recommendation (jump to S1/S2).
- `/help` — list available commands.

---

## 8. Implementation subtasks

**Phase 0 — Foundation** ✅
- [x] `chatWithButler` callable returns structured `{ ok, code, model, reply }`.
- [x] Genkit tool-calling scaffold in the flow — tools registered (`tools.js`), cat-butler `SYSTEM_PROMPT` set, tools passed to `generate()`.
- [x] Firestore foundation — `collections.js` (admin init + `food_cards`/`experiences`/`preferences`/`memory` names).

> Phase 1/2 tools below are already **mock-scaffolded** in `tools.js` ("Mix" mode:
> Gemini real, tools return deterministic data). Each item is "done" when its
> `TODO(real)` integration replaces the mock.

**Phase 1 — Planning (L1)**
- [~] `findFreeTime` tool (User Calendar) — Find Free Time. *(mock)*
- [~] `recallMemory` tool (RAG over Preferences DB) — Memory Retrieval. *(reads Firestore prefs, mock fallback)*
- [~] `searchSpots` tool (Places API + IG parser) — Search & Parse → Candidate List. *(mock)*

**Phase 2 — Execution (L2)**
- [x] `whereAmI` tool — resolves the user's GPS (sent from the client, read via Genkit `context.location`) into nearby places using the **real** Google Places `searchNearby` API. Test: "Do you know where am i?" → client prompts location permission, agent lists nearby spots. *(real)*
- [~] `routeDistance` tool (Maps API) — Distance Calculation + filter by max walk time. *(mock)*
- [ ] FCM "Confirm with User" push (S3) + accept/reject handling; reject → reselect (S2).
- [ ] Scheduled departure reminder (S4, 5:12 PM) + movement check; not-moving → reschedule (S0).
- [ ] Arrival check (S5) — GPS + manual fallback.

**Phase 3 — Record (S6–S7)**
- [ ] Post-visit "Ask Experience" prompt (S6) with retry limit.
- [~] `draftExperience` tool (Sentiment + Image AI) → auto-generated `ExperienceCard`. *(mock)*
- [ ] User edit & final save to Firestore; write-back to memory.

**Phase 4 — UX commands & polish**
- [ ] Implement `/skills`, `/pat`, `/memory`, `/ok`, `/reco`, `/help`.
- [ ] Cat-tone persona tuning + mood handling.
