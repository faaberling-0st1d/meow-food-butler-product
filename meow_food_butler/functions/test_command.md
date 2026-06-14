# Agentic Flow — User Scenarios

## 0. Diagnostic commands

Send these as a chat message to inspect backend state. They render as transient
bubbles and are **not** persisted into the conversation (except `/ok`). Handled in
`agent/flow.js`.

| Command | What it does | Cost |
|---|---|---|
| `/model` | Prints the actual model id this function is configured to use (`config.js` `MODEL`) — not a hardcoded name. | None (config read). |
| `/quota` | Real probe: sends a tiny `ping` across the live key(s) and reports the genuine provider state via `classifyError` — reachable / quota exceeded / invalid key / permission denied / missing key. | One small request **per key** against the real API. |
| `/ok` | Forced canned OK reply to exercise the UI without spending model quota. Persisted (tests the `ok` path). | None (no model call). |

## 1. Recommendation
**Goal:** suggest nearby spots matching a craving.

| | |
|---|---|
| **User** | "Hey, I want to eat pasta!" |
| **Agent** | "Got it! You're near **Section 2, Guangfu Rd, Hsinchu**. Here are some picks." |
| **Output** | A swipe-stack of nearby pasta spots. |

**Behind the scenes**
1. `recallMemory` for preferences/constraints.
2. `searchSpots` for candidates near the user.
3. `routeDistance` to drop anything past the user's max walk time.


### testcase: suggession ✅ PASS
user: "hi, I want to eat ramen."
agent: "Meow, hello there! Ramen sounds purr-fect nya. Let me just check if you have any special preferences for ramen, prrr. And where are you right now, so I can find the best spots for you, meow?"

**Analysis**
"Meow, hello there! Ramen sounds purr-fect nya."  -- Nice tone, keep it.
"Let me just check if you have any special preferences for ramen, prrr." -- The memory is working correctly. You should call memory skills here, nice job.
"And where are you right now, so I can find the best spots for you, meow?" -- ❌FAILED. Agent should ask for location only if the location permission is not on. If location permission is on, the location tool should load here.
"" -- ❌FAILED. Agent doesn't grab the current time data.

**Suggest output**
"Meow, hello there! Ramen sounds purr-fect nya. Let me just check if you have any special preferences for ramen, prrr. It looks like you are near Ginzeng, nya!, it's now 11:30, wanna take a bite? It's 500m away!"

## 2. View my dining log

user: "I want to view my last visit to ramen."
agent: "" (directly shows the card , once clicked it, show the detailed page.)

### testcase: view last logged meal (viewDiningLog)
- user: "find me the last time I ate ramen"
- agent: calls `viewDiningLog({ query: "ramen" })`; short reply (e.g. "Here's your last ramen at <place>, nya 🍜") and the app injects the experience card below it. Tapping the card opens the detail page.
- user: "show my last meal" → `viewDiningLog({})` (latest overall).
- If nothing matches (`found=false`), the agent says they haven't logged that yet and shows NO card.
- Mechanism: the tool records `{ type: "showExperienceCard", experienceId }` in `context.actions`; `agent/flow.js` returns `actions` on the `ok` payload; the client (`ChatService._applyActions`) injects the card by id — the same render path as the `/latest-card` command.


**Goal:** recall and filter past experiences by cuisine and time.

| | |
|---|---|
| **User** | "Remember I went for pasta last week? What did I eat?" |
| **Agent** | "Found an entry from **2026/06/01** — here's the card." |
| **Output** | A single experience card linked to that record. |

| | |
|---|---|
| **User** | "How many times have I eaten pasta recently?" |
| **Agent** | "Searching… found **4 entries** across **3 restaurants**." |
| **Output** | A scrollable list of experience cards. |

**Behind the scenes**
1. Query the `experiences` collection, filtered by cuisine + date range.
2. Aggregate (count, group-by restaurant).
3. Return structured cards, not just prose.


### testcase: Log a dining experience

**Goal:** turn a casual chat message (plus a photo and the user's location) into a
saved `ExperienceCard`.

| | |
|---|---|
| **User** | "this is soooo nice!!!" *(attaches a photo)* |
| **Agent** | "Let me see — you're at **杜蘭小麥 義大利麵·披薩**, 66 Jianxin Rd, East District, Hsinchu City. Want me to log your visit here?" |
| **Choices** | `Yes, log here` · `No, I'll type the place` · `No, don't log a place` |
| **Agent** | "How many stars would you give it?" *(shows a draggable star bar)* |
| **Result** | Creates an experience card with tags, photos, and the place. |

**Behind the scenes**
1. Read the user's current GPS → reverse-geocode to a specific place.
2. Run sentiment/vision on the message + photo to seed tags.
3. Collect the star rating via the inline widget.
4. On confirm, write an `ExperienceCard` referencing the resolved `foodCardId`.


## 3. Memory

### testcase: store
- user: "Hey, I really like spinach." 
- agent: "Noted — I'll remember you love spinach. 🌿"
Open another session.
- user: "What do I like to eat?"
- agent: "spinach!"

### testcase: remove
- user: "Hey I don't like spinach any more."
- agent: "Noted. I'll delete the memory."
**The data should be deleted on firestore.**

### testcase: delete all memory ✅ PASS
- user: "remove all my memory"
- agent: "yeah".
(The memory fieled is delete on firestore.) ✅ PASS