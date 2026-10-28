# Mockups → product map

Written at the start of Stage 0 (2026-10-28) from the mockups as they exist today. Every gap and
contradiction below needs an owner decision before the stage that touches it (see the "Needed by" column).

## 0. Where the mockups are

`docs/design/` holds no exported images yet. The mockups are a Claude Design handoff bundle; its design
files are copied into `docs/design/source/` (the original bundle is `saff-mobile-app-prototype/` next to
this repo):

| File | What it is |
|---|---|
| `source/Duha Prototype.dc.html` | The clickable prototype (Android 412 × 915). One React component; every screen is a state of it, selected by a `preset`. Contains all copy, colours, sample data and interaction rules. |
| `source/Duha Screens.dc.html` | The "Saff · screens" board: the prototype frozen at one preset per frame, grouped in numbered sections. The frame ids below (1a, 6d, ...) are this board's labels. |
| `source/support.js` | The design-tool runtime (not design content); needed to open the two HTML files. |
| `source/HANDOFF.md` | The bundle's README for coding agents. |

Not copied (left in the original bundle):
| File | Why |
|---|---|
| `uploads/pasted-*.png` | Two copies of a stock wallpaper (an anime character). Only plausible use: the sample image for frame 1i "Ali's photo (drop one in)". Not a design asset, and not ours to redistribute. |
| `_ds/organic-*/` | A separate design system ("Organic": cream/terracotta/sage, Caprasimo + Figtree). **Not referenced by either HTML file.** See contradiction C-14. |
| `.thumbnail` | WebP cover image of the project. |

The prototype's own tokens (the ones every frame uses): light `bg #F7F8FA`, `surface #FFFFFF`, `text #161A22`,
`muted #646B7A`, `line #E3E6EC`, `soft #FDF3DC`; dark `bg #0F1524`, `surface #172033`, `text #EEF1F6`; accent gold
`#F2B33D`; status dots asleep `#A7AEBB`, up/done `#2F9E6E`, playing `#7FA7E6`, offline/error `#D64B4B`; wake
gradient stops night `rgb(15,21,36)` → fajr `rgb(35,50,92)` → dawn `rgb(233,168,107)` → duha `rgb(246,210,122)`;
fonts Geist (UI), Amiri Quran (ayahs), Amiri (dua). The wake flow uses its own palette in both themes.

---

## 1. Mockup inventory

"Frame" = label on the screens board. "Preset" = the prototype state. Section numbers refer to `PRODUCT.md`.

### 1 · Alarm ringing, pair (wake flow)
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 1a | `alarm-0` | Ringing at 0 s, night palette. Time 04:50, "Fajr · Thursday", "Today: Card Duel", waking dua (Arabic + English + "Waking dua · Bukhari"). "Ali is still asleep" + Nudge / Ring louder. You = sun in the bottom-right corner, "Swipe up to wake". Snooze 5 min. | §6.1, §6.2 |
| 1b | `alarm-1` | Same at 10 s, fajr palette. | §6.1 (ramp + brightening) |
| 1c | `alarm-2` | Same at 20 s, dawn palette (text flips dark past the midpoint). | §6.1 |
| 1d | `alarm-3` | 30 s, duha palette. Ali is up: "He's 0:12 ahead of you. Swipe to catch up", Ali's quote bubble replaces the dua. | §6.1, §6.2 |
| 1e | `alarm-nudged` | You nudged Ali and asked his phone to ring louder: "Nudged. His phone just buzzed. You're still ahead." | **Not in PRODUCT** (G-M3) |
| 1f | `alarm-swipe` | Mid-swipe: the sun grows as you drag it up. | **Contradicts §6.1** (C-1) |
| 1g | `alarm-ahead` | Ali woke first, night palette. | §6.2 |
| 1h | `alarm-1` + text "Ad-Duha 93:1–2" | Ayah instead of the dua. | **Not in PRODUCT** (G-M2) |
| 1i | `alarm-1` + buddy photo | Ali's photo in the peek instead of his colour. | **Not in PRODUCT** (G-M4) |
| 1j | `alarm-snoozed` | After snooze: button gone, "Snoozed. Ali was told." | §6.1 snooze |
| (prototype only) | flow "Ali is offline" | Ali "is offline · Last seen 23:10" on the ringing screen. | §6.2 `offline` |

### 1G · Alarm ringing, saff of 3 or more
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 1Ga | `alarm-group-0` | "0 of 3 up". Row of dashed gaps snoring z's, Nudge under each. You = gold face in the corner, "Drag yourself into your spot". | §6.1, §6.2 (C-1 for the gesture) |
| 1Gb | `alarm-group` | Sara up first (filled, "+0:42 · first"). | §6.2 |
| 1Gc | `alarm-group-nudged` | Bilal nudged (button "Nudged"). | G-M3 |
| 1Gd | `alarm-group-last` | Everyone else up: "Your spot is the last gap in the row." | §6.2 |
| 1Gb2 | `alarm-group-drag` | Dragging yourself; the spot glows when near and snaps. | C-1 |
| 1Ge | `alarm-group-4` | Saff of 4. | §6.2 |
| 1Gf | `alarm-group-12` | Saff of 12: first-up + sleepers shown, rest folded into "+8 others" with one "Nudge 6". | **Contradicts §3** (C-3) |

### 1H · Today's setup (between dismissing the alarm and playing)
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 1Ha | `brief` | "Thursday 22 October · Fajr", game "Card Duel · 8 cards from what you learned · 25 s each", "From last night: Al-Fil · 105:1–2, plus 1 card Ali left you", Goal "30 mornings in a row · Morning 13 of 30", your saff with statuses, "Ali is up. Scores reveal together.", CTA "Start Card Duel". | **Not in PRODUCT** (G-M1) |
| 1Hb | `brief-group` | Group: "4 cards from what you learned", goal "Everyone up, 5 mornings running", "3 of 3 are up. Rounds lock at 06:30." | G-M1, C-7, C-12 |
| 1Hc | `brief-climber` | Climber, Ali asleep: "Ali is still asleep. You get a head start." | G-M1 |

### 2 · Rounds
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 2a | `duel-0` | Card Duel typed card ("1 of 3"), 25 s bar (turns red under 6 s), source label, "Ali playing" chip, "Send answer". | §7 Card Duel, §8.1 typed, §6.3 (C-5 for 3 cards) |
| 2b | `duel-1` | Multiple-choice card (4 options, picked option highlighted). | §8.1 choice |
| 2c | `duel-2` | Ayah card: Arabic ayah above the question, choice options. | §8.1 choice, CONTENT §4 (`{{arabic}}`) |
| 2d | `climber` | Climber playing: canvas, sky brightens with height, metres counter, "Hold left or right to steer". | §7 Climber (C-13 for touch steering) |
| 2e | `climber-over` | "You reached 1,240 m · Your height is locked in." Continue. | §7 Climber |

### 3 · Waiting
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 3a | `waiting-playing` | "Your score is locked in · Scores reveal together." Ali is playing (pulsing dot). Call on WhatsApp (secondary). | §6.4 |
| 3b | `waiting-asleep` | "Ali hasn't woken up yet · Alarm rang 6 min ago". "Rang again · 2 left · next in 1:58". "Reveal at 05:20 if Ali doesn't play". | §6.4 nudge, §6.5 deadline |
| 3c | `waiting-offline` | "Ali's phone seems to be offline. You may want to call and check on them." Ring hidden, WhatsApp call primary. | §6.4 offline alert |

### 4 · Reveal and card review
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 4a | `reveal-win` | Pair reveal: both scores count up, winner gets a gold underline, "2 of 3 correct", "You woke first by 3 min", "Streak: 13 days". See the cards / Go to chat. | §6.5 reveal |
| 4b | `reveal-missed` | Climber, Ali missed: "—", "Didn't play", "Ali didn't wake up this time. You win by default.", "Streak reset". Go to chat only. | §6.5 deadline, `missed` (C-10 for "win by default") |
| 4c | `review-0` | Card review 1 of 3: question, You / Ali answers with Correct/Wrong, Answer, explanation, ayah + translation + ref, "Talk about it", Next card, Report a problem. | §6.5 card review |
| 4d | `review-2` | Last card: "Go to chat". | §6.5 |

### 5 · Home (the Today tab)
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 5a / 5b | `today` light / dark | Several saffs. "Next alarm" card (time, "Tomorrow · in 7h 12m", weekday chips, 12-day streak, people + "Message"). Tonight's actions: "Leave Ali a card · 2 left tonight", "Learn tomorrow's material". Teaser "Ali left you something for tomorrow". "Your saffs" list with New saff; a saff "Waiting for Zara to accept". Avatar → Settings. | §3 (Today = next alarm across saffs), §5.2 teaser + plant entry, §9 |
| 5c | `home-one` | One saff + "Start another saff". | §3 |
| 5d / 5f | `home-none` light / dark | Empty: "Meet your people", Start a saff / I have an invite. | §3 |
| 5e | `today-morning` | Morning after: next alarm in 23 h, streak 13. | §3 |

### 6 · Chats and alarm proposals
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 6a | `chats` | Chats list, one row per saff (pair rows named after the other person), unread dot. | §10 (one chat per saff) |
| 6b / 6f | `chat` light / dark | Pair chat: header (avatar, "Fajr saff · online", WhatsApp chat + WhatsApp call buttons), pinned alarm bar, day separators, round result card, ticks, "Ali proposed a change · Fajr 04:50 → 04:40 · From Friday" with Accept / Suggest / No, + button, composer. | §10, §4.2 |
| 6c | `chat-group` | Group chat: sender names, result card "Sunday · Sara won · Climber · 3 players". | §10 |
| 6d | `chat-changed` | Counter-proposal: your proposal "Replaced by a newer suggestion", Ali's "suggested another time" pending. | §4.2 suggest another time, supersede |
| 6e | `chat-morning` | After the round: result card, proposal accepted, messages sent/seen. | §6.5 result card, §10 |
| 6g | `sheet-plus` | + sheet: Propose an alarm / Change an alarm / Skip a morning ("2 skips left this month"). | §4.2, §4.3 |
| 6h | `sheet-propose` | Change Fajr: hour/minute steppers, "Pick a different time" guard, name, weekday chips, personal Sound ("Only you hear this"), "Ali needs to accept before this starts", "Send to Ali". | §4.1, §4.2 |
| 6i | `sheet-skip` | Skip a morning: next 4 dates, "Thursday is less than 8 hours away, so it can't be skipped", "2 skips left this month · your streak is frozen, not broken". | §4.3 |
| (prototype only) | — | Proposal states pending / waiting ("Waiting for Ali to accept") / accepted / declined / replaced; typing indicator; system messages "You joined Ali's saff", "You're skipping Friday · streak frozen"; empty chat "Say salaam"; Chats empty state. | §4.2, §10 |

### 7 · Learn
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 7a | `learn-home` | "Learn it tonight. Get quizzed on it in the morning." Focus card per next saff ("Fajr · tomorrow 04:50 · Al-Fil 105:1–2 · Surah · Ali has learned it"), "Coming up" per other saff, "Learned so far" list. | §9 (**C-6**: per saff) |
| 7h | `learn-cards` | Card lesson (vocabulary pack "Five words for the essay", for the Exam prep saff): word, definition, example, Mark learned. | **Not in PRODUCT** (C-6) |
| 7i / 7f | `learn-path` light / dark | "Short surahs · Fajr saff", 2 of 20 surahs, "Daily goal, agreed with Ali · 2 ayahs a day · Edit", "Ali learned today's ayahs", surah list (done / current / locked). | §9 path, goal, progress (C-6 for "agreed with Ali") |
| 7b | `learn-surah` | Al-Fil: summary, lessons 1–3 (Today / Locked). | §9, CONTENT §5 |
| 7c | `learn-lesson` | Lesson page per ayah: tappable words, translation, ref, Play recitation, New words chips (tap = audio), Review word, Next ayah. | §9 lesson screen |
| 7d / 7g | `learn-word` light / dark | Word popover: meaning + root ("Root ر ب ب" or "Particle"). | §9 word meaning and root |
| 7e | `learn-done` | Marked learned: "These will show up in your mornings." | §9 |
| (prototype only) | — | Learn empty state: "Each saff picks what it learns together. Start one to choose yours." | C-6 |

### 8 · Stats
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 8a / 8g | `stats` light / dark | Chips You / each saff. You: tiles (Days in a row, Best streak, Avg time to wake, "Alarms you made 93%"), 30-day time-to-wake trend, Badges grid with progress rings. | §11 personal stats, badges |
| 8b | `stats-badges` | Badges grid scrolled into view (12 badges). | §11 badges (**C-9**) |
| 8c | `stats-badge` | Badge sheet, not earned: "Flawless · 1 to go · 7 of 8" with progress. | §11 |
| 8d | `stats-me` | Pair saff: tiles (Day streak, Longest, Everyone up 86%, Rounds played), month calendar with legend, Standings (wins, draws), "Ali rang you again 4 times this month". | §11 calendar, head-to-head, nudges |
| 8e / 8h | `stats-group` light / dark | Group saff of 3: same, standings for 3. | §11 |
| 8f | `stats-day` | Day sheet: alarm, mode, each member "Up at 04:51 · 54 pts" or "Didn't wake up", winner, streak. | §11 calendar day sheet |
| (prototype only) | — | Stats empty state; pending saff "Exam prep starts once Zara accepts the alarm…"; skipped day "Ali · Skipped this morning · Streak frozen, not broken". | §11 |

### 9 · Leave a card (planting)
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 9a | `plant-1` | "Leave Ali a card · 2 left tonight": question (200 chars), answer type Text, answer field "The answer you'll check against". | §5.2 (**C-8**) |
| 9b / 9d | `plant-2` light / dark | Same, answer type Multiple choice: 4 options, tap a circle to mark the right one. | C-8 |
| 9c | `plant-3` | Preview "How Ali will see it · Somewhere in tomorrow's Card Duel", "From Umer", hidden answer, Send to Ali / Edit. | §5.2 (C-8 for placement) |

### 10 · Start or join a saff
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 10a | `saff-choose` | "Stand in a row · up to four people, one alarm, one round each morning." Start a saff / I have an invite. | §3 (C-4, C-11) |
| 10b | `saff-code` | Invite code H7K2QD, "It works for three more people", Share invite, "Waiting for someone to join…". | §3 inviting |
| 10c | `saff-join` | Enter a 6-character code; "Invite links open this screen with the code filled in." | §3 joining |
| 10d | `saff-paired` | "You and Ali are a saff" + "Propose your first alarm" (or "Go to chat" when joining). | §3, §4.2 |
| (prototype only) | `ns.confirm` | "Join Ali's saff? You'll be able to see when Ali is up…" Join / Not now. | §3 confirmation screen |

### 11 · Settings
| Frame | Preset | Screen and state | Implements |
|---|---|---|---|
| 11a / 11b | `settings` light / dark | Profile row (name, WhatsApp). Groups: You (name, WhatsApp, default sound, theme) · Saffs (each saff, Join with a code, Start a saff) · Mornings (Mode order, Card mix, Add a pack by link, Translation, General knowledge toggle) · Alarm reliability (permission walkthrough, test alarm) · Notifications (one toggle) · Feedback · Account (sign out, delete). "Support Saff" tips Rs 200 / 500 / 1,000. | §13 (**C-2** for tips) |

---

## 2. Clickable flows (which screen leads to which)

From the prototype's flow list and handlers:

- **Night before (several / one / no saffs):** Today → Next-alarm card → Chat · Today → "Leave Ali a card" → Plant (write → preview → send → Today, toast "Ali will get this tomorrow") · Today → "Learn tomorrow's material" → Lesson · Today avatar → Settings · Empty Today → Start a saff / I have an invite.
- **Morning, both wake:** Ringing → swipe the sun up → Today's setup → Start → Card Duel (3 cards) → Waiting (Ali playing) → Reveal → See the cards → Review → Go to chat (result card posted, Ali replies).
- **Morning, Ali sleeps in:** Ringing → setup → Climber → game over → Continue → Waiting (asleep, Ring again ×3, 2 min apart) → [time passes to 05:20] → Reveal missed → Go to chat.
- **Morning, Ali offline:** Ringing (Ali offline) → setup → Card Duel → Waiting (offline, WhatsApp primary).
- **Morning, saff of 3:** Ringing group → drag yourself into your spot → setup (group) → Card Duel → …
- **Change an alarm:** Chat → + → Change an alarm → steppers → Send → Ali counter-proposes → Accept / Suggest / No.
- **Join by invite:** Start or join → Enter code → Join Ali's saff? → Paired → Go to chat → Ali's first proposal → Accept → Today.
- **Start a saff:** Start or join → Invite code → (Ali joins) → Paired → Propose your first alarm sheet.
- **Learn:** Learn home → focus card → Lesson (or card lesson) → Mark learned → Back to Learn · "See the whole short-surah path" → Path → Surah → Lesson.
- **Stats:** You / saff chips → calendar day → day sheet · badge → badge sheet.
- **Settings:** rows toast "opens here in the full app" except Saffs → chat, Join/Start → saff setup, test alarm → ringing.

Tabs (both docs and mockups): **Today · Chat · Learn · Stats**. Settings is pushed from the avatar.

---

## 3. In PRODUCT.md but with no mockup

| # | Screen or state (PRODUCT §) | Needed by |
|---|---|---|
| G-1 | Onboarding: welcome, sign-in (Google, email link incl. "check your email" and link-expired states), name + WhatsApp (+92 default), permissions walkthrough with OEM steps, test alarm (§13) | Stage 3 (sign-in, profile), Stage 13 (rest) |
| G-2 | Join errors: `SAFF_FULL` ("the owner can raise the limit"), `ALREADY_MEMBER`, `SAFF_LIMIT` (offer Plus or leaving), invalid code (§3) | Stage 3 |
| G-3 | Saff management: member list, owner rename, regenerate invite, remove member + confirm, leave saff, ownership transfer, ended saff (read-only history), saff with one member, inactive-member banner (§3) | Stage 3 |
| G-4 | The "saff switcher" that `ARCHITECTURE.md` §5a and `OPEN_QUESTIONS.md` say the mockups include (see C-15) | Stage 3 |
| G-5 | More than one alarm in a saff (up to 3), alarm details (join / leave a group alarm), group alarm "Waiting for someone to join", delete-alarm proposal, per-alarm sound outside a proposal (§4.1, §4.2) | Stage 4 |
| G-6 | Alarm conflict: disabled Accept with reason "Too close to your Fajr in Family at 04:50"; `ALARM_CONFLICT` on propose (§4.1) | Stage 4 |
| G-7 | Proposal expired state; group proposal showing who has joined (§4.2) | Stage 4 |
| G-8 | Chat: reply (swipe), delete within 1 h → "Message deleted", long-press "seen by", system cards for member joined / left / removed, proposal outcome, missed morning, planted-card teaser; group header WhatsApp (group link or member picker); setting the WhatsApp group link (§10, §13) | Stage 4 |
| G-9 | Ringing screen with **Hold to start** (if C-1 keeps it); idle guard "Still with us?" overlay + Continue (§6.1, §6.3) | Stage 6 |
| G-10 | Group waiting screen (per-member ring again / WhatsApp call, "Open WhatsApp group") (§6.4) | Stage 7 |
| G-11 | Nudge received: the re-ring with "Ali rang you again" (§6.4) | Stage 7 |
| G-12 | Group reveal: ranked list of 3–10, shared ranks on ties, first waker; group card review with every member's answer (§6.5) | Stage 6 |
| G-13 | Solo morning reveal (no ranking) (§6.5) | Stage 7 |
| G-14 | Fallbacks: "played offline" unranked arcade, Arabic-only card, skipped unresolvable card, the one-line note at the reveal (§6.6, ERRORS §7) | Stage 7 |
| G-15 | Report a card (what happens after the link) (§6.5) | Stage 6 |
| G-16 | Card types: blank (`{{blank}}`), self-graded ("I knew it" / "I didn't"), planted bonus cards "From Ali" in the round, ask-me grading by the planter after the round (§8.1, §5.2) | Stage 6 (blank), 10 (planted, ask-me), 12 (self) |
| G-17 | Modes: Word, Rapid Roll, Selfie (camera, capture, upload progress, reveal grid with times, Save to gallery, "Selfies expired", camera-denied fallback), Learning Duel (own cards, accuracy ranking) (§7) | Stage 8, Stage 9 |
| G-18 | Mode schedule and card-mix screens (Surprise / My order / One mode; pair = proposal, group = owner) (§7.1, §8.2) | Stage 8, Stage 12 |
| G-19 | Learning: choose a path, set daily goal (1–10), Learn-tab "Review now" session, daily review cap reached, "lower your goal" suggestion (§9) | Stage 9 |
| G-20 | Stats: personal calendar across saffs with saff / just me toggle, head-to-head per mode, first-waker weekly tally, the 30-day free window and its Plus prompt (§11) | Stage 11, Stage 13 |
| G-21 | Anki import: pick file, upload progress, parsing, preview (title, counts, warnings, 5 samples), Add to my saff, chat card, delete imported pack; pack by link (CONTENT §6) | Stage 12 |
| G-22 | Saff Plus: plans with Play prices, status, renewal, manage, restore, full-saff owner notification, over-limit notice, claim ownership, feature-point prompts, extra themes and tones, Supporter badge (§15) | Stage 13 |
| G-23 | Settings sub-screens: per-category notification toggles (critical ones locked), translation picker, theme, delete-account confirmation, About with content attributions, feedback with "copy details" (§13, ERRORS §7) | Stage 13 |
| G-24 | Shared states: `ErrorView`, `DeviceFixBanner` (readiness), offline banner, loading, "Something broke on this screen", app update required (ERRORS §7–8) | Stage 2 |
| G-25 | The design-system page (`docs/design/system/`) and the exported per-screen PNGs that `docs/design/README.md` asks for | Stage 2 |
| G-26 | Native fallback screen (time, alarm name, hold "Stop alarm", "Open Saff") (ALARM §3) | Stage 1 |

---

## 4. In the mockups but not described in PRODUCT.md

| # | Behaviour | Frames |
|---|---|---|
| G-M1 | A **"Today's setup"** screen between dismissing the alarm and playing: date, mode, "From last night" material, a goal ("30 mornings in a row", "Everyone up, 5 mornings running"), who is up, and a Start button. Nothing starts until you tap. | 1Ha–1Hc |
| G-M2 | **Text on the ringing screen**: the waking dua (Bukhari), Ad-Duha 93:1–2, or none (a setting in the prototype's Tweaks). Also affects CLAUDE.md's "never hard-code Quran or hadith text" and ALARM's "nothing in the ring path may depend on the network". | 1a–1c, 1h |
| G-M3 | **Nudge and "Ring louder" from the ringing screen** (before you've played). PRODUCT only has "Ring again" from the waiting screen; "Ring louder" doesn't exist anywhere. | 1a, 1e, 1G* |
| G-M4 | **Profile photos** (Ali's photo in the peek). PRODUCT has only an avatar colour. | 1i |
| G-M5 | **A message from the person who's up shown on your ringing screen** ("Uth 🐶, lrr duniya sai · Ali · just now"). | 1d |
| G-M6 | "Ahead / behind" race framing while ringing ("He's 0:12 ahead of you"). | 1d, 1g |
| G-M7 | Goals with progress ("Morning 13 of 30", "Morning 4 of 5"). | 1Ha, 1Hb |
| G-M8 | Learning material that isn't Quran: general-knowledge and vocabulary "card lessons" with Mark learned, feeding a saff's next round. | 7a, 7h |
| G-M9 | Stats extras: "Alarms you made 93%", 30-day time-to-wake trend, "Personal Best" badge. | 8a |
| G-M10 | Two WhatsApp buttons in every chat header (chat and call), and a pinned alarm bar in the chat. | 6b |
| G-M11 | "You win by default" when the other member missed. | 4b |
| G-M12 | Tips ("Support Saff", Rs 200 / 500 / 1,000). | 11a |

---

## 5. Contradictions

### Between the mockups and the docs
| # | Docs say | Mockups show | Needed by |
|---|---|---|---|
| C-1 | **Hold to start** (0.6 s) starts the round and stops the sound (PRODUCT §6.1, ALARM §5, `HOLD_TO_START`). | Pair: swipe the sun up to wake. Group: drag yourself into your spot. Then a setup screen and a Start tap (G-M1). | Stage 1 (wake entry stub), Stage 6 |
| C-2 | Business model is **Saff Plus** (PRODUCT §15, decided 2026-10-28): paid capacity, imports, history, cosmetics. | Settings: "Nothing in Saff is ever locked behind payment. Tips keep it running." No Plus anywhere; "Add a pack by link" is free. | Stage 3 (limits copy), Stage 13 |
| C-3 | A saff has at most 10 members (`MAX_SAFF_SIZE_PLUS`). | 1Gf shows a saff of 12. | Stage 2 |
| C-4 | Saffs hold 2–4 (free) or up to 10 (owner's Plus); up to 3 alarms per saff; a saff has its own name. | "up to four people, one alarm"; every saff has exactly one alarm, and the saff name is the alarm name ("Fajr", "Morning run"); pair chats are named after the other person. | Stage 3, Stage 4 |
| C-5 | Card Duel = **8** cards from the pack lineup (Quran, Story, Hadith, Deen, Wildcard); score 10 + 0–5 speed bonus (max 15). | 3 cards ("1 of 3"); setup says "8 cards" (pair) and "4 cards" (group) "from what you learned"; prototype scoring is 10 + up to 15 (max 25); 4a totals 54–47. | Stage 6 |
| C-6 | **Learning is personal** (§9, decided 2026-10-28): own path, own goal, shared across saffs; Learning Duel serves each member their own cards. | Learn is **per saff**: "Each saff picks what it learns together", "Daily goal, agreed with Ali", "Changing the goal sends Ali a request in chat", "Short surahs · Fajr saff", badge "learn every ayah of a surah with your saff". | Stage 9 (and Stage 2 for the Learn layout) |
| C-7 | Learned material feeds only Learning Duel; Card Duel comes from packs. | Card Duel is "8 cards from what you learned"; "Learn tomorrow's material" on Home. | Stage 6, Stage 9 |
| C-8 | Planting has **4 templates** (ask me — graded by the planter; quiz them — typed; library card; ayah challenge); planted cards come **after** the scored cards. | One kind of card: your question with a text or multiple-choice answer that is checked automatically; "Somewhere in tomorrow's Card Duel". | Stage 10 |
| C-9 | Badges (§11): First Waker of the Week · Streak 7/30/100/365 (saff) · Lightning (≤15 s, 5 times) · Never Snoozed (30) · Surah Complete · Scholar (100 correct) · Comeback (won after losing 3 in a row) · Supporter. | First Light · One Week Strong · The Wake-up Call · Lightning (≤10 s, once) · Personal Best · Comeback (new streak the next morning) · Flawless · No One Left Behind · Zero Snooze (2 weeks) · A Month of Mornings · Surah by Heart · 100 Sunrises. Same names, different rules. | Stage 11 |
| C-10 | Missed members are `missed`; head-to-head counts ranked rounds; nothing about a default win. | "You win by default." | Stage 11 |
| C-11 | Group alarms are **opt-in**: active at 2 participants; non-responders simply aren't participants. | Group propose sheet: "Sara and Bilal need to accept before this starts." | Stage 4 |
| C-12 | "Night lock" = 60 min **before** the alarm; deadline = 30 min after. | "Rounds lock at 06:30" for a 06:15 alarm (a different meaning of "lock", and not the 06:45 deadline). | Stage 6 |
| C-13 | Climber: "Tilt to steer". | "Hold left or right to steer" (touch halves). | Stage 8 |
| C-14 | Stage 2 builds `saff_ui` "from the mockups". | Two visual systems: the prototype's own tokens (Geist, gold `#F2B33D`, navy dark) used by every frame, and an unused "Organic" system (Caprasimo/Figtree, terracotta, sage) in `_ds/`. | Stage 2 |
| C-15 | `ARCHITECTURE.md` §5a and `OPEN_QUESTIONS.md`: "mockups include a switcher"; tab screens work in the context of one selected saff. | No switcher. Home lists all saffs, Chat opens a chats list, Stats uses chips, Learn lists material per saff. | Stage 3 |
| C-16 | Calendar grey = cancelled **or you skipped**. | Grey day sheet = "Ali · Skipped this morning". | Stage 11 |
| C-17 | Ringing screen shows each participant's status, today's mode and the **saff name**. | Saff name is not shown separately (title is "Fajr · Thursday"; see C-4). | Stage 6 |

### Between documents
| # | Contradiction | Needed by |
|---|---|---|
| D-1 | `ARCHITECTURE.md` §4.1 lists the package `mode_selfie`; `REPOSITORY.md` §1 layout and §3 dependency graph don't. Stage 0 creates "all packages". | **Resolved 2026-10-28:** `mode_selfie` added to `REPOSITORY.md` |
| D-2 | `saff_core` "depends on nothing (pure Dart)" (ARCHITECTURE §4.1, REPOSITORY §3), but Stage 0 puts "`FailureMapper` + all mappers" there, and the mappers need `cloud_functions`, `cloud_firestore`, `firebase_auth`, `firebase_storage`, `package:http`, Flutter's `PlatformException` and `sqlite3`/`drift` types. | **Stage 0** |
| D-3 | `ERRORS.md` §10 maps invalid callable input to `INVALID_ARGUMENT`, which isn't in the initial catalog (§5). | **Resolved 2026-10-28:** added to the Generic codes |
| D-4 | `TESTING.md` §5: performance budgets "checked in Stage 12"; `STAGES.md` checks them in Stage 14. | Stage 14 |
| D-5 | `README.md` terms: an alarm is "agreed by all members of a saff"; PRODUCT §4.2: group alarms are opt-in. | Stage 4 |
| D-6 | PRODUCT §3: the owner can rename the saff; `SECURITY.md` rules let members update only `whatsappGroupLink`, and `BACKEND.md` has no rename callable. | Stage 3 |
| D-7 | `DATA_MODEL.md` plants: created by members directly (rules + counter doc) **or** "callable preferred: `plantCard`"; `SECURITY.md` §1 says rule-heavy actions go through callables. | Stage 10 |
| D-8 | `ARCHITECTURE.md` §5a / `OPEN_QUESTIONS.md` refer to a saff switcher in the mockups (see C-15). | Stage 3 |
| D-9 | Naming: the app is Saff, but the prototype files, CSS keyframes and the packs repository are "Duha" (`duha-packs`). Only the packs base URL matters to code. | Stage 5 |
