# Product specification

Behaviour is decided here. Code implements this document; if code and this document disagree, the
code is wrong (or the document must be changed first, with the owner's approval).

All numeric rules are collected in §14 as named constants. Use those names in code.

---

## 1. Concept

Saff is an alarm app for a small group (a **saff**, 2–10 people). Members agree on alarm times. When
an alarm rings, every member wakes into the same short **round**: a card quiz, a word puzzle or an
arcade game. Results stay hidden until everyone has played (or a deadline passes), then reveal
together and the saff's chat opens. Waking becomes something you do with people, not alone.

A saff is named after the rows of worshippers standing shoulder to shoulder; the main audience wakes
for Fajr, but alarms can be for anything.

**Platforms:** Android only for now. The architecture must not block iOS later (AlarmKit, iOS 26+).

**Open items** are marked **OPEN (Q-n)** and listed in `OPEN_QUESTIONS.md`. Do not implement an
OPEN rule until the owner has answered it.

**Pairs and groups.** A saff of exactly 2 is a **pair**; a saff of 3 or more is a **group**. Some rules
differ (alarm consent, planted cards); every such difference is called out.

---

## 2. Identity and accounts

- **Sign-in:** Google, or email magic link (Firebase email link sign-in). No phone-number auth (SMS costs).
- **Identity:** each user has an auto-generated Firebase uid. No usernames.
- **Profile:** display name (required, 1–40 chars), WhatsApp number (**required, never verified**,
  E.164 format, country code defaulting to +92), avatar colour (auto-assigned, changeable).
- Phone numbers are not unique and not used for login or lookup. They exist only to power the
  WhatsApp chat and call buttons, and are visible only to members of the user's saff(s).
- **Account deletion:** in-app, complete (see `SECURITY.md` §6).

---

## 3. Saffs and membership

- A saff has 2 to `MAX_SAFF_SIZE_FREE` (4) members, or up to `MAX_SAFF_SIZE_PLUS` (10) when its **owner**
  has Saff Plus (§15).
- A user can belong to **several saffs at once**: up to `MAX_SAFFS_PER_USER_FREE` (2), or unlimited with
  Saff Plus (a technical safety cap of `MAX_SAFFS_PER_USER_PLUS` (25) prevents abuse). The app has a
  saff switcher (per the mockups); every screen that shows saff data works in the context of one saff,
  and Today shows the next alarm across all of the user's saffs.
- The creator is the **owner**. The owner can rename the saff, regenerate the invite code and remove
  members. Ownership passes to the longest-standing member if the owner leaves. All members are equal
  in everything else (proposals, nudges, rounds).
- **Inviting:** a 6-character code (uppercase letters and digits, excluding 0/O/1/I) plus an invite
  link `https://saff.app/join/<code>` (deep link). The code works until the saff is full or the owner
  regenerates it.
- **Joining:** enter the code or open the link → confirmation screen ("Join Hamza's saff?" with
  member avatars) → joined. Joining a saff that is full fails with `SAFF_FULL` (the screen tells the
  invitee the owner can raise the limit with Saff Plus; the invitee never has to pay to join); joining
  one you're already in fails with `ALREADY_MEMBER`; going over your own saff limit fails with
  `SAFF_LIMIT` (offer Saff Plus, or leaving a saff).
- **Pair → group:** when a third member joins a pair, the existing alarms keep their two participants;
  the newcomer joins alarms by accepting them (§4.2). Planted cards stop. **Group → pair:** planted
  cards become available; alarm consent rules for pairs apply to future proposals.
- **Leaving:** any member can leave. Their future alarm occurrences in that saff stop immediately. If one
  member would remain, the saff ends (alarms cancelled, history kept read-only).
- **Removing:** the owner removes a member with a confirmation; same effects as leaving.
- **A saff with one member** (creator waiting for others) can exist but cannot have alarms.
- **Inactive member:** after `INACTIVE_MISSED_MORNINGS` (5) consecutive missed occurrences with no app
  activity, other members see a banner offering "Message on WhatsApp" and (owner) "Remove from saff".

---

## 4. Alarms and proposals

### 4.1 Alarms
- Up to `MAX_ALARMS_PER_SAFF` (3) alarms per saff.
- An alarm has: name (e.g. Fajr, Gym; 1–24 chars), time of day, days of the week (at least one),
  timezone (IANA, taken from the **creator's** device), active from date, and **participants**: the
  members it rings for.
- **Timezone:** the alarm time is in the creator's timezone. Every participant rings at that same moment,
  shown in their own local time (e.g. 04:50 in Lahore is 03:50 in Dubai). A change proposal keeps the
  alarm's timezone.
- Each member chooses their own **sound** for each alarm (app tones or any phone ringtone). Sound is a
  personal setting and never part of a proposal.
- **No overlapping alarms:** a user can't participate in two alarms (in any of their saffs) that ring
  within `ALARM_CONFLICT_WINDOW` (30 min) of each other on any day they share. The check compares actual
  ring moments, so it works across timezones.
  - Proposing an alarm that conflicts with one of your own is blocked (`ALARM_CONFLICT`).
  - Accepting one that would conflict is blocked: the Accept button is disabled with the reason
    ("Too close to your Fajr in Family at 04:50").
  - In a pair this means the alarm can't start until the conflict is resolved; in a group the member
    simply can't join it. For a change to a group alarm, a participant who can't accept because of a
    conflict counts as not accepting, so the change is dropped.
  - To resolve it, the user changes or leaves the other alarm.

### 4.2 Proposals (live in chat)
- Creating, changing or deleting an alarm is a **proposal**, posted in the saff's chat as a card with
  Accept / Suggest another time / Decline.
- **In a pair:** consent is mandatory. The alarm (or change) becomes active only when both have
  accepted. The proposer counts as accepted. A decline ends the proposal.
- **In a group:** an alarm is **opt-in**. The proposer is a participant; each member who accepts becomes
  a participant; a member who declines or never responds is simply not a participant and the alarm
  doesn't ring for them. Members can join an existing alarm later from the alarm's details (accepting
  it) and can leave it at any time (effective from the next night lock).
  - **Starting:** a new group alarm becomes active once it has **2 participants** (the proposer + one
    acceptance). Until then it shows "Waiting for someone to join".
  - **Continuing alone:** if participants later leave and only one remains, the alarm keeps ringing for
    that person (a solo morning, §6.5).
  - **Changing or deleting** an existing group alarm needs **every current participant** to accept. If
    anyone declines, the change is dropped and the alarm stays as it was. Members who aren't participants
    don't vote; after the change they can join the updated alarm.
- **Suggest another time** ends the proposal and posts a new proposal from that member, linked to the old one.
- While a change is pending, the current alarm stays active unchanged.
- A proposal expires if it isn't resolved before its first occurrence's night lock.
- Only one pending proposal per alarm at a time; a new one supersedes the old.

### 4.3 Skipping a morning
- A participant can skip a single occurrence for themselves, at least `SKIP_MIN_NOTICE` (8 h) before it,
  up to `SKIPS_PER_MONTH` (2) times per calendar month **per saff**.
- Skipped members are excluded from that occurrence entirely (not required for the reveal, not
  counted in streak, not ranked).
- The saff streak is **frozen, not broken**, by a skip.
- A chat system message announces it ("Ali is skipping Thursday's Fajr").
- If every participant skips, the occurrence is cancelled.

---

## 5. The night before

### 5.1 Night lock
- At `NIGHT_LOCK_LEAD` (60 min) before an occurrence the server **locks the round**: picks the mode,
  the cards or game seed, and collects planted cards. After this, nothing about the round changes.
- Each phone downloads the locked round and resolves its content as soon as it's locked (push message),
  so the round plays offline.

### 5.2 Planting cards (pairs only)
- Planting exists only in **pairs**. Groups don't have it.
- Each member can plant up to `PLANTS_PER_NIGHT` (2) cards for the next occurrence, until the night lock.
- A planted card goes to the other member; the planter doesn't play their own card.
- Templates:
  1. **Ask me:** an open question about the planter; the planter grades the answer after the round.
  2. **Quiz them:** question + answer, played as a typed card.
  3. **Send a library card:** search the enabled packs and send any card.
  4. **Ayah challenge:** pick an ayah, ask its meaning (played as an ayah choice card).
- Question max `PLANT_MAX_CHARS` (200).
- Planted cards appear after the scored cards ("From Ali") and **never count toward the score**; their
  answers show in the card review.
- The recipient only sees a teaser at night: "Ali left you something for tomorrow".

---

## 6. The morning (wake flow)

### 6.1 Ringing
- The alarm rings at the occurrence time on each member's phone: full screen, over the lock screen,
  through silent mode and Do Not Disturb (alarm stream).
- Volume ramps from 10% to 100% over `RAMP_DURATION` (30 s). The screen's background brightens in step
  (see design brief, wake palette).
- The ringing screen shows: time, alarm name, saff name, weekday, **each participant's live status**, today's mode,
  a **Hold to start** button (`HOLD_TO_START` 0.6 s) and **Snooze 5 min** (once).
- **Snooze:** once per occurrence, `SNOOZE_DURATION` (5 min). Other members see "Hamza snoozed".
  Snooze time counts toward wake time. After the snooze, the button is gone.
- Starting the round stops the sound.

### 6.2 Member statuses (live)
`asleep` (ringing, not started) · `snoozed` · `playing` · `done` · `skipped` · `offline`
(phone never reported ringing within `OFFLINE_CHECK_DELAY`, 2 min) · `missed` (deadline passed, didn't play).

### 6.3 Playing
- The round lasts 1–3 minutes depending on mode (§7).
- **Idle guard:** if a member is inactive for `IDLE_RERING` (60 s) during play, the alarm rings again
  with a "Still with us?" overlay and a large Continue button.
- Answers are saved locally as they're given; the result uploads when done (or later, if offline).
- No right/wrong is shown during play. Results reveal together.

### 6.4 Waiting
After finishing, a participant sees who is still asleep/playing.
- **Ring again (nudge):** for each member still `asleep`/`snoozed`/`offline`, a "Ring <name> again"
  button. Each sender can nudge each member up to `NUDGES_PER_TARGET` (3) times per occurrence, at
  least `NUDGE_INTERVAL` (2 min) apart. The target's alarm re-rings immediately with "Ali rang you again".
- **Call on WhatsApp:** for each member not done, opens a WhatsApp call or chat with that member's
  number (Android call intent where supported, otherwise the chat). For saffs with a WhatsApp group
  link set, a "Open WhatsApp group" button also appears.
- **Offline alert:** if a member's phone hasn't reported ringing within 2 min of the alarm, others see
  "Ali's phone seems to be offline. You may want to call and check on them." Nudge is hidden for
  that member; WhatsApp call becomes the primary action.

### 6.5 Reveal
- The reveal happens when **every non-skipped participant has submitted**, or at the **deadline**,
  `REVEAL_DEADLINE` (30 min after the occurrence time), whichever comes first.
- Participants who didn't play by the deadline are `missed`.
- **Solo morning** (an alarm with one participant left): the round plays normally and reveals as soon as
  they finish; there's no ranking, only their own result and the card review.
- **Reveal screen:** a ranked list of members with score and detail ("6 of 8 correct" or "1,240 m"),
  the winner highlighted, who woke first, the saff streak. Ties share a rank.
- **Selfie mode reveal:** everyone's selfies appear together in a grid with the time each was taken.
  There's no ranking and no winner; everyone who posted counts as woke. The round result card in chat
  shows the same grid as thumbnails.
  - Each selfie has a **Save** button that stores it in the phone's gallery.
  - Selfies are deleted from the server `SELFIE_RETENTION` (24 h) after the reveal. After that, the reveal
    and chat show "Selfies expired" placeholders, except for selfies the user saved.
- **Card review:** swipe through each card: question, every member's answer (correct/wrong), the
  correct answer, explanation, and the **talk question**. A "Report a problem" link on each card.
- Then the chat opens with a round result card posted automatically.

### 6.6 Fallbacks
- **Phone missed the night lock and is offline at alarm time:** the alarm still rings; the member
  plays an arcade game with a local seed. They count as **woke** (streak) but are **unranked** for that
  round ("played offline").
- **Content can't be resolved** (e.g. a translation missing): show the Arabic only; if nothing can be
  shown, skip that card (it's excluded from everyone's score for fairness).

---

## 7. Modes

All participants play the **same mode with the same content/seed** in a round (Learning Duel: see §9).

| Mode | Rules | Score | Ranking |
|---|---|---|---|
| **Card Duel** | `CARDS_PER_ROUND` (8) cards, `CARD_SECONDS` (25 s) each; then bonus planted cards | Correct = 10, speed bonus 0–5 (linear over the time left); self-graded cards = 10 if "I knew it" | Total points |
| **Learning Duel** | Each participant gets **their own** up to 8 learning cards (due reviews first, then cards from their newest lessons), `CARD_SECONDS` each; anyone with fewer than 8 is topped up with official Quran cards | Correct = 10, speed bonus 0–5 | **Accuracy %**, then total time (different cards, so points aren't compared) |
| **Selfie** | Each participant takes a selfie with the front camera (in-app camera only, no gallery). Selfies stay hidden until the reveal, then appear together | None; posting = woke | **Unranked** (excluded from head-to-head; wake time still counts for First Waker) |
| **Word** | Hidden 5-letter English word, 6 guesses, Wordle rules | Solved in n guesses → (7 − n) × 10; unsolved = 0; time breaks ties | Points, then time |
| **Climber** | Tilt to steer, auto-bounce, same platform seed; no time limit, difficulty ramps every 10 s until you fall | Height in metres | Height |
| **Rapid Roll** | Drag to steer through gaps in rising platforms; same seed; ramps until you fall | Depth in metres | Depth |

- Arcade difficulty is tuned so a typical run lasts 45–90 s and an excellent run rarely exceeds 2–3 min.
- One life, one attempt.

### 7.1 Mode schedule (saff setting; in a pair both must agree; in a group the **owner** decides)
- **Surprise** (default): weighted random, revealed when the alarm rings; never the same mode 3 days running.
- **My order:** a repeating list arranged by the saff (repeats allowed).
- **One mode:** the same mode every morning.
- Learning Duel is only picked when at least 2 participants have a learning track with 4 or more eligible
  cards; otherwise Card Duel is used instead.
- Selfie mode needs the camera permission; a participant who denies it plays an arcade game instead and
  counts as woke but unranked.

---

## 8. Cards

### 8.1 Card types
| Type | Answer | Graded by |
|---|---|---|
| choice | Pick 1 of 4 | Server, exact match |
| typed | Type a short answer | Server, normalised match against `accept` list (§8.4) |
| self | See the answer, mark "I knew it" / "I didn't" | Honour system (imported long-answer cards) |
| ask-me (planted) | Free text | The planter, after the round |

### 8.2 Card Duel lineup (8 scored cards)
| Slot | Category |
|---|---|
| 1–2 | Quran |
| 3–4 | Story |
| 5–6 | Hadith |
| 7 | Deen basics |
| 8 | Wildcard: general knowledge or a revenge card |

- Difficulty mix per round: 2 easy, 4 medium, 2 hard (fallback to any difficulty if a slot can't fill).
- **No repeats:** a saff never gets a card it has already seen, except **revenge cards** (cards any
  member got wrong, eligible again after `REVENGE_DELAY` 7 days).
- **Card mix (saff setting; in a pair both must agree; in a group the owner decides):** which packs feed the round. Official packs on by default. Imported or
  community packs can be enabled; the saff can choose "Custom mix", where enabled custom packs fill
  slots in proportion (any slot whose category no pack covers falls back to official cards).
- General knowledge can be turned off.

### 8.3 Content rules (from the packs)
Knowledge first. Rulings appear rarely and name Hanafi and/or Shafi'i fiqh only. Every Islamic card
has a source. Details: the packs repo `FORMAT.md` and `CONTENT.md`.

### 8.4 Typed answer normalisation (server)
Lower-case; trim; collapse whitespace; strip punctuation except apostrophes inside words; remove
leading "the/a/an"; Arabic diacritics removed; common transliteration folds (aa→a, ee→i, oo→u, ʿ/'
dropped). Match if equal to any normalised `accept` entry, or Damerau-Levenshtein distance ≤ 1 for
answers of 5+ characters (≤ 2 for 10+).

---

## 9. Learning track (individual)

Learning is **personal**: each user has their own path, goal, progress and review schedule, shared
across all their saffs.

- The user chooses a **path** (e.g. Juz Amma 114 → 95) from the packs index; surahs unlock in order.
- **Daily goal:** 1–10 ayahs per day, set by the user.
- **Lesson screen** (from the surah pack's `lessons.json`): the lesson's ayahs (Arabic, translation,
  tap any word for meaning and root), recitation audio, new words, review words, then **Mark learned**.
- A lesson's cards become eligible for that user once every ayah in a card's `covers` range has been
  learned by them.
- **Scheduling:** FSRS (desired retention 0.9, fuzzing off), one schedule per user, computed on the server.
  Correct = Good, wrong = Again (self-graded "I knew it" = Good).
- At most `MAX_REVIEWS_PER_DAY` (10) learning reviews per day.
- **Reviews happen in two places:**
  - **Mornings:** Learning Duel (§7) serves each participant their own due cards.
  - **Learn tab:** a "Review now" session plays the user's due cards solo, any time.
  Both update the same personal schedule, and together they count toward the daily review cap.
- Members of a saff can see each other's learning progress ("Ali learned today's ayahs"), per the mockups.
- A 9 pm reminder if the user hasn't learned today's lesson (once, only if they have a goal).
- If the user scores under 60% on learning cards for 7 days, the app suggests lowering the goal.

---

## 10. Chat

- One chat per saff (Flyer Chat UI on Firestore).
- Included: text messages, sent/seen ticks (seen = seen by all members; long-press shows who),
  typing indicator, online/last seen (always visible, no setting to hide), reply to a message (swipe),
  system cards.
- **System cards:** alarm proposal (with Accept / Suggest / Decline), proposal outcome, member joined,
  member left, skip announcement, planted-card teaser, round result, missed morning.
- Not in v1: reactions, images, voice notes (voice notes are the first v2 feature), editing.
  Deleting own message within 1 hour ("Message deleted").
- Header buttons: WhatsApp (pair: the other member's chat; group: the WhatsApp group link if set,
  otherwise a member picker).

---

## 11. Stats and badges

| Stat | Definition |
|---|---|
| Wake time | First game action − ring start, seconds (monotonic clock), including snooze |
| Woke | Played (any mode, including offline fallback) before the deadline |
| Saff success rate | Occurrences where every non-skipped participant woke ÷ occurrences (cancelled excluded) |
| Saff streak | Consecutive occurrences (any alarm of the saff) where every non-skipped participant woke; skips freeze it |
| Personal streak | Consecutive occurrences the user woke, across all their saffs (their skips freeze it) |
| First waker | Lowest wake time that occurrence; weekly tally |
| Head-to-head | Wins / draws / losses vs each member, per mode and overall (ranked rounds only) |
| Nudges | Ring-again count sent and received |

**Calendar** (per saff, plus a personal view across saffs): green = everyone woke; red = someone missed (day sheet shows who); grey = cancelled or
you skipped; empty = no occurrence; today outlined. Toggle: saff / just me.

**Badges:** First Waker of the Week · Streak 7 / 30 / 100 / 365 (saff) · Lightning (woke within 15 s,
5 times) · Never Snoozed (30 occurrences) · Surah Complete · Scholar (100 correct cards) · Comeback
(won after losing 3 rounds in a row) · Supporter (has Saff Plus).

All stats and badges are computed on the server. All history is always stored; without Saff Plus the
app shows the last `STATS_HISTORY_FREE_DAYS` (30) days of the calendar, trends and head-to-head
(current streaks, longest streaks and badges are always shown). Upgrading reveals the full history.

---

## 12. Notifications

| Event | Who | Channel |
|---|---|---|
| Proposal received / resolved / expired | All members of that saff | Normal push |
| Member joined / left / removed | All members | Normal push |
| Round locked (data) | All members | Data push (no UI; triggers download) |
| Planted-card teaser | Recipients | Normal push, after night lock |
| Member woke / reveal ready | All members | Normal push (suppressed if app open) |
| Nudge | Target | High-priority data push → alarm re-rings |
| Offline alert | Others | Normal push |
| New message | Others | Normal push (suppressed if chat open) |
| 9 pm learning reminder | Users who haven't learned today | Normal push |

Never sent: streak-at-risk nags, promotions, anything non-alarm between 22:00 and the next alarm
except proposals and nudges.

---

## 13. Settings

- **You:** name, WhatsApp number, default alarm sound, theme (system/light/dark).
- **Saffs:** list of your saffs; for each: name (owner), members, invite code/link, WhatsApp group link
  (optional, any member), alarms you participate in, leave. Create or join another saff.
- **Learning:** path, daily goal.
- **Mornings (per saff):** mode schedule, card mix, add a pack by link (Plus), import Anki deck (Plus), general
  knowledge on/off. **Translation** (English / Urdu) is a personal setting.
- **Alarm reliability:** re-run permission walkthrough, test alarm.
- **Notifications:** per category toggles (nudges and alarm-critical items can't be disabled).
- **Saff Plus:** plans, current status, renewal date, manage subscription (opens Google Play), restore
  purchases (§15).
- **Feedback:** send feedback, report a card.
- **Account:** sign out, delete account.

**Onboarding:** welcome → sign in → name + WhatsApp → permissions (notifications, alarms & reminders,
full-screen alerts, battery optimisation with brand-specific steps) → test alarm (rings the real
alarm screen with the phone locked) → start a saff / join with a code.

---

## 14. Constants

| Name | Value |
|---|---|
| `MAX_SAFF_SIZE_FREE` / `_PLUS` | 4 / 10 (decided by the owner's plan) |
| `MAX_SAFFS_PER_USER_FREE` / `_PLUS` | 2 / 25 (Plus is "unlimited"; 25 is an abuse cap) |
| `STATS_HISTORY_FREE_DAYS` | 30 |
| `PLUS_GRACE_DAYS` | 7 |
| `MAX_ALARMS_PER_SAFF` | 3 |
| `NIGHT_LOCK_LEAD` | 60 min |
| `RAMP_DURATION` | 30 s |
| `HOLD_TO_START` | 600 ms |
| `SNOOZE_DURATION` | 5 min (once) |
| `IDLE_RERING` | 60 s |
| `OFFLINE_CHECK_DELAY` | 2 min |
| `REVEAL_DEADLINE` | 30 min after occurrence |
| `NUDGES_PER_TARGET` | 3 per sender per target per occurrence |
| `NUDGE_INTERVAL` | 2 min |
| `SKIP_MIN_NOTICE` | 8 h |
| `SKIPS_PER_MONTH` | 2 |
| `CARDS_PER_ROUND` | 8 |
| `CARD_SECONDS` | 25 s |
| `PLANTS_PER_NIGHT` | 2 (pairs only) |
| `PLANT_MAX_CHARS` | 200 |
| `REVENGE_DELAY` | 7 days |
| `MAX_REVIEWS_PER_DAY` | 10 (morning Learning Duel + Learn tab reviews) |
| `LEARNING_DUEL_MIN_CARDS` | 4 eligible cards for at least 2 participants |
| `MIN_GROUP_ALARM_PARTICIPANTS` | 2 to start (may continue with 1) |
| `SELFIE_MAX_PX` / `SELFIE_JPEG_QUALITY` | 1080 px long edge / 80 |
| `SELFIE_RETENTION` | 24 h after the reveal (users can save to their gallery) |
| `ALARM_CONFLICT_WINDOW` | 30 min |
| `INACTIVE_MISSED_MORNINGS` | 5 |
| `IMPORT_MAX_CARDS` | 2,000 per import |
| `IMPORT_MAX_FILE` | 50 MB |
| `IMPORTS_PER_SAFF` | 10 |

Constants live in `contracts/constants.json` and are generated into Dart and TypeScript so client and
server never disagree.

---

## 15. Business model: Saff Plus

**Principle:** the core loop is free for everyone: waking together in a pair or a small group, every
mode, every alarm feature, all Quran, hadith and learning content. Saff Plus charges for **capacity,
convenience and cosmetics**, never for Islamic content, and there are **no ads anywhere** in the app.

### 15.1 What's free and what's Plus
| | Free | Saff Plus |
|---|---|---|
| Pairs | ✓ | ✓ |
| Groups | Up to 4 members | Up to 10 members (in saffs **you own**) |
| Saffs you can be in | 2 | Unlimited (cap 25) |
| Alarms (3 per saff), all modes, Quran cards, learning track, nudges, chat, stats | ✓ | ✓ |
| Anki import and packs by link | — | ✓ (for saffs you own or are a member of) |
| Stats history (calendar, trends, head-to-head) | Last 30 days | All time |
| Extra themes and alarm tones | — | ✓ |
| Supporter badge | — | ✓ |

### 15.2 Who pays
- **Plus belongs to a person, not a saff.** A saff's member limit comes from its **owner's** plan.
- Members never pay to join or take part. An invitee who finds a saff full is told the owner can raise
  the limit; they're never shown a paywall themselves.
- Each user's own limits (saffs they can join, imports, stats history, cosmetics) come from their own plan.

### 15.3 Plans and prices
- Monthly and yearly auto-renewing subscriptions through Google Play Billing. Product ids:
  `saff_plus_monthly`, `saff_plus_yearly`.
- Prices are set in the Play Console with regional pricing (guide for Pakistan: about Rs 250–300 a month,
  about Rs 2,000 a year). Prices are never hard-coded in the app; the app shows Play's localised prices.
- Optional free trial (Play Console setting, e.g. 7 days on the yearly plan).

### 15.4 When Plus ends (lapse rules)
Losing Plus must never remove anyone from their morning group.
- **Grace:** for `PLUS_GRACE_DAYS` (7) after a failed renewal or cancellation takes effect, everything keeps
  working (Play's grace period plus ours).
- **After grace, a saff over the free member limit is "over limit":**
  - all members, alarms, rounds and chat keep working exactly as before;
  - no new members can join and no new alarms can be created until it's back within the free limit;
  - the owner sees a calm notice with two options: renew Plus, or hand ownership to a member who has Plus;
  - any member with Plus can **take over ownership** of an over-limit saff with one tap (the owner is notified).
- **A user over their own saff limit** keeps all current saffs but can't join or create another.
- **Imported packs and packs by link** stay usable in rounds; new imports need Plus again.
- **Stats** older than 30 days are hidden again (never deleted).
- **Cosmetics** fall back to the defaults.

### 15.5 Where Plus is offered (never pushy)
- The full-saff message when someone tries to join (to the owner via a notification: "Sara tried to join
  your saff. Raise the limit to 10 with Saff Plus").
- Settings → Saff Plus.
- At the moment of using a Plus feature (import, history beyond 30 days, themes).
- Never in the wake flow, never as a pop-up on launch, never more than one suggestion per day.
