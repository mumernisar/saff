# Backend (Cloud Functions, TypeScript)

## 1. Structure and rules

- Firebase Functions v2, TypeScript strict, Node LTS runtime, region **`us-central1`** for every product
  (Functions, Firestore, Storage, Hosting rewrites): all no-cost allowances apply there. The added latency
  from Pakistan is fine because rounds are downloaded the night before and the client is offline-first.
- `src/domain/` holds pure functions (no Firebase imports): round assembly, grading, normalisation,
  stats, streaks, FSRS wrapper, occurrence planning, Anki parsing. 100% unit-testable with fixtures.
- `src/triggers/` binds domain logic to triggers/tasks/callables; handlers are thin.
- Every handler is **idempotent**: it reads current state and exits if the work is already done.
- Every callable validates input with zod (generated from `contracts/payloads`), requires auth and
  App Check, and supports `requestId` idempotency (`requests/{requestId}`).
- Writes that change several documents use transactions or batched writes.
- Structured logs via `firebase-functions/logger` with `{event, saffId, occurrenceId, requestId}`.
- Secrets (Quran Foundation client credentials) in Secret Manager via `defineSecret`.
- Errors follow `ERRORS.md` §10.

## 2. Inventory

### Callables
| Name | Input | Does | Errors |
|---|---|---|---|
| `createSaff` | `{name?}` | Creates saff, invite code, owner member; adds to `users.saffIds` | `SAFF_LIMIT` |
| `joinSaff` | `{code}` | Validates code, adds member, copies whatsapp, adds to `users.saffIds`; in a pair becoming a group, keeps existing alarm participants; posts system message | `INVITE_INVALID`, `SAFF_FULL`, `ALREADY_MEMBER`, `SAFF_LIMIT` |
| `leaveSaff` | `{saffId}` | Removes member, removes them from alarm participants, transfers ownership, ends saff if 1 left | |
| `leaveAlarm` | `{saffId, alarmId}` | Group only: removes the caller from participants from the next lock; updates alarm status | `NOT_PARTICIPANT` |
| `removeMember` | `{saffId, uid}` | Owner only; same as leave for target | `NOT_SAFF_OWNER` |
| `regenerateInvite` | `{saffId}` | Owner only | `NOT_SAFF_OWNER` |
| `voteProposal` | `{saffId, proposalId, vote}` | Validates membership/participation and pending status; for an accept, checks the voter's alarm conflicts across all their saffs; writes the vote | `ALARM_CONFLICT`, `PROPOSAL_NOT_PENDING`, `NOT_PARTICIPANT` |
| `createProposal` | `{saffId, type, payload, targetId?, supersedes?}` | Validates (limits, alarm rules), creates proposal + chat card, auto-accept for proposer | `ALARM_LIMIT`, `ALARM_INVALID`, `SAFF_TOO_SMALL` |
| `skipOccurrence` | `{occurrenceId}` | Checks notice and monthly limit; writes skip; posts message; re-evaluates occurrence | `SKIP_TOO_LATE`, `SKIP_LIMIT` |
| `plantCard` | `{saffId, occurrenceId, template, card}` | Pairs only; checks limits and lock time; stores plant | `PLANT_LIMIT`, `PLANT_TOO_LONG`, `ROUND_LOCKED`, `PLANT_PAIRS_ONLY` |
| `nudge` | `{occurrenceId, targetUid}` | Checks limits/interval/target status; sends high-priority data push; records nudge | `NUDGE_TOO_SOON`, `NUDGE_LIMIT`, `NUDGE_TARGET_DONE` |
| `gradeAskMe` | `{occurrenceId, cardId, grades: {uid: bool}}` | Planter grades ask-me answers (bonus, unscored) | |
| `verifyPurchase` | `{productId, purchaseToken}` | Verifies with the Google Play Developer API (`purchases.subscriptionsv2.get`), acknowledges the purchase, writes purchase + entitlement, recomputes limits of saffs the user owns | `PURCHASE_INVALID`, `PURCHASE_PENDING` |
| `restorePurchases` | `{purchaseTokens[]}` | Re-verifies tokens (new device / reinstall) | `PURCHASE_INVALID` |
| `claimOwnership` | `{saffId}` | Caller has active Plus and the saff is `overLimit` → becomes owner; old owner notified | `PLUS_REQUIRED`, `SAFF_NOT_OVER_LIMIT` |
| `submitReview` | `{answers: [{cardId, answer?, choiceIndex?, selfGrade?, msToAnswer}]}` | Learn-tab "Review now": grades with the same normaliser, updates the user's FSRS state, respects the daily review cap | `REVIEW_LIMIT` |
| `updateSaffSettings` | `{saffId, modeSchedule?, cardMix?}` | Group saffs: owner only, applies immediately and posts a system message. Pairs must use proposals. | `NOT_SAFF_OWNER` |
| `deleteAccount` | `{}` | See `SECURITY.md` §6 | |
| `registerDevice` | `{installationId, fcmToken}` | Upserts device doc | |

### Firestore triggers
| Trigger | Does |
|---|---|
| `onVoteWritten` (`proposals/*/votes/*`) | **Pair:** both accepted → apply; a decline → resolve. **Group alarm create:** each accept adds a participant; the alarm becomes `active` at 2 participants. **Group alarm change/delete:** every current participant must accept; any decline drops the change. Post outcome; replan occurrences. |
| `onAlarmWritten` | Replan occurrences for 48 h; cancel/enqueue tasks |
| `onResultCreated` (`rounds/*/results/*`) | Grade this member; update presence `done`; update their personal learning schedule for learning cards; if all required participants done → reveal |
| `onMemberWritten` | Keep `memberIds`, `memberCount` and denormalised names in sync |
| `onMessageCreated` | Push to other members (suppressed for members with the chat open via presence) |
| `onUserContactWritten` | Copy whatsapp into the member doc |
| `onRevealed` (round status → revealed) | Saff stats, streaks, calendar, badges, head-to-head, personal stats, result chat card, push |
| `onLessonLearned` (`users/*/lessons/*`) | Updates `learningSummary` in each of the user's member docs |

### Task-queue functions
| Task | When | Does |
|---|---|---|
| `lockRound` | `ringAt − 60 min` | If occurrence still valid and not cancelled: assemble round (§3), write round, set occurrence `locked`, expire pending proposals for it, send "round locked" data push and planted-card teasers |
| `offlineCheck` | `ringAt + 2 min` | For required members with no `presence` update since `ringAt`: set `offline`, push the offline alert to others |
| `deadline` | `ringAt + 30 min` | Mark missing members `missed`; reveal with whoever submitted |

### Scheduled
| Function | Schedule | Does |
|---|---|---|
| `planOccurrences` | daily 00:15 UTC | For each active alarm, ensure occurrences and tasks exist for the next 48 h |
| `sweeper` | every 15 min | Delete selfies whose round was revealed more than 24 h ago (marks the doc `expired`); find occurrences whose tasks should have run (`lockAt`/`deadlineAt` passed, wrong status) and run the handler directly; after an outage (e.g. billing disabled), reconcile everything missed: ungraded results, overdue reveals, expired proposals; on the first run of each hour, send 9 pm local learning reminders |
| `cleanup` | daily | Purge expired presence/requests; delete orphaned import files; **entitlement check**: move entitlements past `expiresAt` to `grace`, past `graceUntil` to `expired`, recompute owned saffs' `memberLimit`/`overLimit`, notify owners |

### Storage trigger
| Trigger | Does |
|---|---|
| `onImportUploaded` (`imports/{uid}/{importId}`) | Checks the uploader's entitlement (`PLUS_REQUIRED` → failed), then the Anki import pipeline (§6) |

### Pub/Sub
| Trigger | Does |
|---|---|
| `onPlayNotification` (topic for Play real-time developer notifications) | Looks up the user by token hash, re-fetches the subscription from the Play API (never trusts the message body alone), updates purchase + entitlement (renewed, in grace, on hold, cancelled, expired, revoked/refunded), recomputes owned saffs' limits |
| `capBilling` (topic `billing-budget`, Cloud Billing budget messages) | When `costAmount` passes `BILLING_CAP_USD` ($10): writes `config/backend.status = 'billingDisabled'`, then removes the project's billing account (`ARCHITECTURE.md` §9a). Ignores amounts under the cap; no-op if billing is already disabled |

### HTTPS
| Function | Route | Does |
|---|---|---|
| `content` | Hosting rewrite `/api/content/**` | Content gateway (§5) |

## 3. Round assembly (`domain/rounds/assemble.ts`)

Input: saff settings, participants (required = participants not skipped), alarm, date, packs (fetched from the packs
`index.json`/pack JSON and cached in memory/Storage by version), imported packs, `seenCards`, learning
state, plants. Output: the round document.

1. **Seed:** `seed = hash32(occurrenceId)`; all randomness uses a seeded PRNG (deterministic, testable).
2. **Mode:** from `modeSchedule`:
   - `single` → that mode; `order` → index = number of previous occurrences of this saff mod length;
   - `surprise` → weighted pick (Card Duel 30, Learning Duel 15 when eligible, Word 15, Climber 15,
     Rapid Roll 15, Selfie 10), excluding a mode used on both of the previous two occurrences.
   - Learning Duel requires `LEARNING_DUEL_MIN_CARDS` for at least 2 participants, else Card Duel.
3. **Cards (Card Duel):** for each slot in the lineup (`PRODUCT.md` §8.2), choose from eligible cards:
   enabled packs, `status=approved` only, category matches, not in `seenCards`, difficulty target for the
   slot; relax difficulty, then category (to wildcard) if empty. Wildcard order of preference:
   revenge card (≥7 days old), general knowledge (if enabled), any official card.
4. **Learning Duel cards (per participant):** from each participant's personal FSRS state: due reviews
   first (oldest due date), then cards of their most recently learned lessons whose `covers` they've fully
   learned, in lesson order; cap 8 and respect today's remaining `MAX_REVIEWS_PER_DAY`; top up with official
   Quran cards. The round stores `cardsByMember: {uid: card[]}` instead of a shared `cards` list.
   **Selfie:** no cards; just the mode and the deadline.
5. **Custom mix:** if enabled, imported/community packs replace official cards slot by slot in proportion
   to their size, falling back to official cards for categories they don't cover.
6. **Bonus cards (pairs only):** all valid plants, ordered by creation time.
7. Write round with full card JSON (so clients need no pack lookup), add served ids to `seenCards`.

Fixtures in `contracts/fixtures/rounds/` define input → expected output for regression tests.

## 4. Grading and reveal

- `domain/grading/normalise.ts` implements `PRODUCT.md` §8.4; fixtures in
  `contracts/fixtures/normalisation.json` (hundreds of answer → expected cases, including Arabic and
  transliteration variants).
- Points per `PRODUCT.md` §7. Skipped cards (unresolvable content flagged by any client) are excluded
  for everyone.
- Offline-fallback results: `woke = true`, `ranked = false`.
- **Learning Duel:** rank by accuracy % (correct ÷ cards served to that member), ties broken by total
  answer time. Each answer also updates that member's FSRS state.
- **Selfie:** a result counts once its `selfies/{uid}` doc exists; `woke = true`, `ranked = false` for
  everyone (no winner, no head-to-head).
- **Solo morning** (one participant): reveal as soon as their result is graded; `ranked = false`.
- **Reveal** = transaction: set round `revealed`, write `reveal/summary`, set occurrence `revealed`.
  Happens once (status check), triggered by the last result or the deadline task, whichever first.

## 5. Content gateway

Base: `https://<hosting-domain>/api/content/v1/...`. All responses JSON, `Cache-Control: public,
max-age=86400, s-maxage=2592000` (content is immutable per version), ETag.

| Endpoint | Returns |
|---|---|
| `GET /ayah/{s}:{a}?tr={translationId}` | Arabic (Uthmani), translation text, audio URL |
| `GET /surah/{s}?tr=...` | All ayahs of a surah (for lesson screens) |
| `GET /words/{s}:{a}?lang=en` | Word-by-word: position, Arabic, meaning, transliteration, audio URL |
| `GET /hadith/{collection}/{n}?lang=en` | Hadith text |
| `POST /resolve` body `{placeholders: [...], tr}` | Batch resolution for a locked round (≤ 200 items) |

- Upstream: Quran Foundation Content API (OAuth2 client credentials; token cached until expiry) for
  Quran text, translations, word-by-word, audio; hadith from the open hadith dataset used by the packs
  tooling (cached). Provider adapters behind an interface so sources can be swapped.
- Translation ids are mapped to friendly keys in config (`en` → one English translation, `ur` → one Urdu
  translation). Which translations: **OPEN (Q-8)**.
- Show the required attribution for each source in Settings → About.
- Rate-limit by App Check token / uid; reject requests without App Check in prod.

## 6. Anki import pipeline (`features/imports`)

1. Client creates `imports/{id}` (`uploaded`), uploads the file to `imports/{uid}/{id}` (Storage rules:
   owner only, ≤ 50 MB, extensions `.apkg`, `.txt`, `.csv`, `.tsv`).
2. `onImportUploaded` sets `parsing`, then:
   - **`.apkg`** (zip, via `fflate`): pick the real collection: `collection.anki21b` (decompress with
     `fzstd`) → else `collection.anki21` → else `collection.anki2`. Detect the decoy database (a single
     note telling users to update Anki) and skip it.
   - Open with `sql.js`. Read note types: schema v11 → `col.models` JSON; schema v18 → `notetypes` and
     `fields` tables. Read `notes` (`flds` split on `\x1f`, `tags`).
   - **Plain-text exports** (`.txt/.csv/.tsv`): honour Anki header lines (`#separator:`, `#html:`,
     `#tags column:`, `#notetype column:`, `#deck column:`); default tab-separated, first column front,
     second back.
3. **Mapping** (`CONTENT.md` §5 has the full table): Basic-like → front/back; Cloze → one card per cloze
   number with a blank; others → first field = question, second = answer.
4. **Sanitising:** strip HTML to text (keep line breaks), decode entities, remove `[sound:...]`, remove
   images; drop cards whose question becomes empty; trim to length limits; reject control characters.
5. **Card type:** answer ≤ 4 words and ≤ 40 chars → `typed` with accept variants; otherwise `self`.
6. Write `saffs/{saffId}/packs/{packId}` + chunks of 500; cap `IMPORT_MAX_CARDS`; update import doc with
   counts and warnings (`MEDIA_SKIPPED`, `TRUNCATED`, `CARDS_SKIPPED_EMPTY`); delete the uploaded file.
7. Failures set `status=failed` + catalog code; the file is deleted regardless.

## 7. Push payloads (`contracts/payloads/push/*.schema.json`)

All data payloads include `type`, `saffId`, `v` (payload version).

| `type` | Priority | Extra fields | Client action |
|---|---|---|---|
| `roundLocked` | high, data-only | `occurrenceId` | Background: download round + resolve content into Drift |
| `nudge` | high, data-only | `occurrenceId`, `fromName` | Call `saff_alarm.ringNow(reason: nudge)` |
| `presence` | normal, data-only | `occurrenceId` | Refresh status if wake flow open |
| `proposal`, `memberChange`, `message`, `teaser`, `reveal`, `offlineAlert`, `reminder` | normal, notification + data | `route` | Show notification; tap navigates to `route` |

Android notification channels: `alarm-critical` (nudges, offline alerts), `saff` (proposals, members,
reveal), `chat`, `reminders`. Users can mute non-critical channels.

## 8. Saff Plus entitlements and limits

**Computing an entitlement** (`domain/billing/entitlement.ts`, pure, fixture-tested):
- Active subscription (Play state `ACTIVE`, or `IN_GRACE_PERIOD`) → `plan: plus, status: active|grace`.
- Expired or cancelled past expiry → `status: grace` until `expiresAt + PLUS_GRACE_DAYS`, then `expired` → free limits.
- Revoked/refunded → free limits immediately.
- `limits` come from `contracts/constants.json` (free vs plus values).

**Enforcement points (server only):**
| Action | Rule |
|---|---|
| `joinSaff` | Saff `memberCount < memberLimit` and not `overLimit`; joiner's `saffIds.length` < their `maxSaffs` |
| `createSaff` | Creator's `saffIds.length` < their `maxSaffs` |
| `createProposal` (alarm create) | Saff not `overLimit` |
| `onImportUploaded`, pack by link | Requester has `imports: true` |
| Stats reads | Stats are always written in full; the client hides days older than `statsHistoryDays`. Monthly calendar docs older than the window are readable (it's the user's own data); hiding is a UX limit, not a security one |
| Owner leaves / ownership transfer | Recompute `memberLimit` from the new owner's plan; set `overLimit` if needed (members are never removed) |

**Recompute triggers:** `verifyPurchase`, `onPlayNotification`, daily `cleanup` check, ownership change.
Each recompute updates all saffs the user owns in one batched write and posts a quiet system message only
when a saff becomes over limit or recovers.

**Play setup (Stage 13):** subscription products in the Play Console; a Google Cloud service account
with Play Developer API access (key in Secret Manager); real-time developer notifications to a Pub/Sub
topic in the Firebase project.

## 9. Alarm conflicts (`domain/alarms/conflicts.ts`)

A user may not participate in two alarms whose ring moments fall within `ALARM_CONFLICT_WINDOW` (30 min)
of each other.
- Compare the candidate alarm against every alarm the user participates in, across all their saffs.
- For each weekday of the candidate, compute its ring instant (UTC) for the next 14 days in its own
  timezone, and the other alarms' ring instants likewise; a conflict is any pair less than 30 min apart.
  Using actual instants handles different timezones and DST.
- Checked in `createProposal` (for the proposer) and `voteProposal` (for an accept), and again when a
  change proposal is applied (a participant who now conflicts blocks it, which drops the change).
- The client runs the same check for UX (disabled Accept button with the reason), using alarms it already
  has; the server's answer is final. Fixtures in `contracts/fixtures/conflicts/`.
