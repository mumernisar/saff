# Data model

Field names are camelCase. Timestamps are Firestore `Timestamp` (UTC) on the server and `DateTime`
(UTC) in domain models. `[S]` = written only by the server (rules deny client writes).

---

## 1. Ids

| Entity | Id |
|---|---|
| User | Firebase uid |
| Saff | auto-id |
| Invite code | 6 chars, alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`; unique via `inviteCodes/{code}` |
| Alarm | auto-id |
| Occurrence | `{alarmId}_{yyyyMMdd}` (local date in the alarm's timezone): deterministic |
| Round | same as occurrence id |
| Result | `{uid}` under the round: one per member, idempotent |
| Proposal | auto-id |
| Message | auto-id; system messages created by functions use `sys_{type}_{refId}` (idempotent) |
| Planted card | `{occurrenceId}_{uid}_{n}` |
| Import | auto-id |
| Callable request | `requestId` UUID v7 from the client |

---

## 2. Firestore collections

### `users/{uid}`
| Field | Type | Notes |
|---|---|---|
| `displayName` | string | 1–40 |
| `avatarColor` | string | token name |
| `saffIds` | string[] `[S]` | all saffs the user belongs to (≤ the user's saff limit) |
| `createdAt` | timestamp `[S]` | |
| `appVersion`, `platform`, `oem`, `androidSdk` | string/int | updated on app start |
| `settings` | map | theme, defaultSoundUri, translation (`en`/`ur`), notification toggles, lastSelectedSaffId |
| `learning` | map | `{pathId, dailyGoal, startedAt}` (personal) |
| `lastActiveAt` | timestamp | throttled to once per 10 min |

Private subcollection `users/{uid}/private/contact`: `whatsapp` (E.164). Readable only by the user;
copied by a function into `saffs/{saffId}/members/{uid}.whatsapp` for each of the user's saffs.

`users/{uid}/entitlement` (single doc `current`) `[S]`: `plan` (`free|plus`), `status`
(`active · grace · expired · none`), `productId?`, `expiresAt?`, `graceUntil?`, `autoRenewing`,
`limits` (`{maxOwnedSaffSize, maxSaffs, statsHistoryDays, imports: bool, cosmetics: bool}`), `updatedAt`.

`users/{uid}/purchases/{orderId}` `[S]`: `productId`, `purchaseTokenHash`, `state`, `startAt`,
`expiresAt`, `lastNotificationType`, `updatedAt`. The raw purchase token is stored only in
`purchaseTokens/{tokenHash}` `[S]` (no client read), which maps tokens back to users for Play notifications.

`users/{uid}/devices/{installationId}`: `fcmToken`, `updatedAt`, `appVersion`. Multiple devices allowed;
pushes go to all.

### `users/{uid}/learning/{itemId}` `[S]`
Personal FSRS state per learning card: `cardId`, `lessonId`, `stability`, `difficulty`, `due`, `state`,
`reps`, `lapses`, `lastReview`.

### `users/{uid}/lessons/{lessonId}`
`learnedAt`. Written by the user. Saff members can see each other's progress through a summary the
server copies into `saffs/{saffId}/members/{uid}.learningSummary` (`{pathId, surah, lesson, todayDone}`).

### `inviteCodes/{code}` `[S]`
`saffId`, `createdAt`. Lookup for joining (callable `joinSaff` reads it; clients can't list).

### `saffs/{saffId}`
| Field | Type | Notes |
|---|---|---|
| `name` | string | default "Hamza's saff" |
| `ownerId` | string `[S]` | |
| `memberIds` | string[] `[S]` | used by rules (`request.auth.uid in resource.data.memberIds`) |
| `memberCount` | int `[S]` | |
| `memberLimit` | int `[S]` | from the owner's entitlement (4 or 10) |
| `overLimit` | bool `[S]` | `memberCount > memberLimit` after the owner's Plus lapsed; blocks joins and new alarms |
| `inviteCode` | string `[S]` | |
| `whatsappGroupLink` | string? | any member; must match `https://chat.whatsapp.com/...` |
| `modeSchedule` | map `[S]` | `{type: surprise|order|single, order: ModeId[], single: ModeId}` (pair: via proposal; group: owner via callable `updateSaffSettings`) |
| `cardMix` | map `[S]` | `{packs: packId[], custom: bool, generalKnowledge: bool}` (pair: via proposal; group: owner via `updateSaffSettings`) |
| `streak` | map `[S]` | `{current, longest, lastOccurrenceId}` |
| `createdAt`, `endedAt?` | timestamp `[S]` | |

#### `saffs/{saffId}/members/{uid}`
`displayName`, `avatarColor` (denormalised), `whatsapp` `[S]`, `role` (`owner|member`) `[S]`,
`joinedAt` `[S]`, `presence` (`online`, `lastSeenAt`, `typingAt`), `stats` `[S]` (streak in this saff,
skips used this month in this saff, badges earned in this saff).

#### `saffs/{saffId}/alarms/{alarmId}` `[S]`
`name`, `time` (`HH:mm`), `days` (int[] ISO 1–7), `timezone` (IANA), `activeFrom` (date), `status`
(`active|waiting|deleted`; `waiting` = fewer than 2 participants before it ever started), `participantIds`
(string[]), `createdBy`, `version` (int, increments on each accepted change).
Membership of an alarm changes through votes (accept = join) and `leaveAlarm`.
Per-member sound is **not** here; it lives in the member's local settings.

#### `saffs/{saffId}/proposals/{proposalId}`
| Field | Notes |
|---|---|
| `type` | `alarmCreate` · `alarmChange` · `alarmDelete` · `modeSchedule` · `cardMix` |
| `payload` | the proposed values (schema per type in `contracts/payloads/proposal.schema.json`) |
| `targetId` | alarm id for change/delete |
| `proposerId` | |
| `status` `[S]` | `pending · accepted · declined · superseded · expired` |
| `requiredIds` `[S]` | pair: both members; group alarm **create**: empty (opt-in); group alarm **change/delete**: every current participant; group settings (`modeSchedule`, `cardMix`): not proposals; the owner changes them directly |
| `acceptedIds` `[S]` | members who accepted (group: they become participants) |
| `supersedes` | previous proposal id (for "suggest another time") |
| `expiresAt` `[S]` | |
| `messageId` `[S]` | the chat card |

`.../proposals/{proposalId}/votes/{uid}` `[S]`: `vote` (`accept|decline`), `at`. Written by the
callable `voteProposal` (not directly by clients) so the server can reject an accept that would create an
alarm conflict. A trigger tallies and resolves.

#### `saffs/{saffId}/messages/{messageId}`
`type` (`text` or a system type), `authorId` (or `system`), `text?`, `replyToId?`, `systemPayload?`,
`createdAt` (server timestamp), `deletedAt?`, `seenBy` (map uid → timestamp; members update their own key).

#### `saffs/{saffId}/occurrences/{occurrenceId}` `[S]`
`alarmId`, `alarmVersion`, `date`, `ringAt` (timestamp), `lockAt`, `deadlineAt`, `status`
(`planned · locked · ringing · revealed · cancelled`), `participantIds` (snapshot at lock),
`skippedIds`, `requiredIds` (= participants − skipped), `taskNames` (for cancellation).

#### `saffs/{saffId}/occurrences/{id}/skips/{uid}`
Created by the member via callable `skipOccurrence` (server validates notice and monthly limit).

#### `saffs/{saffId}/occurrences/{id}/plants/{plantId}` (pairs only)
`authorId`, `template`, `card` (card JSON), `createdAt`. Created by the members of a pair before `lockAt` (rules
check count limit through a server-maintained counter doc `plantCounts/{uid}`; callable preferred:
`plantCard`).

#### `saffs/{saffId}/rounds/{occurrenceId}` `[S]`
| Field | Notes |
|---|---|
| `mode` | ModeId |
| `seed` | int (arcade/word) |
| `cards` | card JSON array (scored), copied from packs at lock time (Card Duel) |
| `cardsByMember` | map uid → card JSON array (Learning Duel only; each member's own cards) |
| `bonusCards` | planted cards (unscored), with `authorId` |
| `packVersions` | map packId → version used |
| `lockedAt` | |
| `status` | `locked · revealed` |
| `revealedAt?` | |

#### `.../rounds/{id}/results/{uid}`
Written by the member's client (create once; rules: `request.time < deadlineAt`, own uid, round locked).
`answers` (list of `{cardId, answer?, choiceIndex?, selfGrade?, msToAnswer}`), `arcadeScore?`,
`wordGuesses?`, `ringStartedAt`, `startedAt`, `finishedAt`, `wakeMs`, `snoozed`, `nudgesReceived`,
`offlineFallback` (bool), `clientVersion`.
**Rules: readable by other members only after the round is revealed.**

#### `.../rounds/{id}/selfies/{uid}`
Selfie mode: `storagePath` (`saffs/{saffId}/rounds/{rid}/{uid}.jpg`), `takenAt`, `msFromRing`, `width`,
`height`. Created by the member's client after the upload finishes (rules: own uid, round locked, mode
`selfie`, before deadline). The image itself is readable by saff members only after the reveal (Storage rules).

#### `.../rounds/{id}/grades/{uid}` `[S]`
`points`, `correct`, `perCard` (`{cardId, correct, points}`), `rank`, `woke`, `ranked`.

#### `.../rounds/{id}/reveal` (single doc `summary`) `[S]`
Ranked list, first waker, streak after, per-card answer summary for the review screen.

#### `.../rounds/{id}/presence/{uid}`
`status` (`asleep · snoozed · playing · done · offline · missed`), `updatedAt`. Written by the member
(own) except `offline`/`missed` (server). Drives live statuses during the morning.

#### `.../rounds/{id}/nudges/{autoId}`
Created via callable `nudge` only (server checks limits): `fromId`, `toId`, `at`.

#### `saffs/{saffId}/packs/{packId}` (imported/custom packs)
`title`, `source` (`anki|link`), `createdBy`, `cardCount`, `createdAt`, `version`.
`.../packs/{packId}/chunks/{n}` `[S]`: up to 500 cards per doc (`cards` array).

#### `saffs/{saffId}/seenCards/{chunk}` `[S]`
Card ids already served to this saff (bitset-like arrays of ids, sharded by pack), used by round assembly.

#### `saffs/{saffId}/stats/summary` `[S]` and `.../stats/days/{yyyyMM}` `[S]`
Success rate, streaks, head-to-head matrix, first-waker tallies, nudge counts; month docs hold the
calendar (per day: status, per-member woke/missed/skipped, winner).

### `imports/{importId}`
`uid`, `saffId`, `fileName`, `status` (`uploaded · parsing · done · failed`), `counts`
(`notes, cards, skipped`), `warnings` (codes), `errorCode?`, `packId?`, timestamps. Client creates it
(status `uploaded`) right before uploading the file to `imports/{uid}/{importId}`.

### `requests/{requestId}` `[S]`
Idempotency records for callables: `uid`, `fn`, `response`, `expiresAt` (TTL policy 24 h).

---

## 3. Indexes (initial)

- `occurrences`: `status ASC, ringAt ASC` (collection group, for the sweeper)
- `messages`: `createdAt DESC`
- `proposals`: `status ASC, expiresAt ASC` (collection group)
- `imports`: `uid ASC, createdAt DESC`

Add composite indexes only with a query that needs them; keep `firestore.indexes.json` in git.

---

## 4. Time

- Alarm times are wall-clock in the alarm's IANA timezone. The server computes `ringAt` (UTC) per
  occurrence; DST and timezone database changes are handled by recomputing occurrences 48 h ahead daily.
- Each phone schedules natively from `ringAt` (absolute instant) for the next 7 days and reschedules on
  any change, on boot, on time/timezone change, and on each ring.
- Wake time uses the monotonic clock on the device (`elapsedRealtime`), never wall time.
- Server-side ordering uses `serverTimestamp()`.

---

## 5. Local database (Drift)

| Table | Purpose |
|---|---|
| `locked_rounds` | Round JSON for upcoming occurrences (keyed by occurrence id) |
| `resolved_content` | Placeholder → resolved text/audio URL, keyed by `(placeholder, translation)` |
| `pending_results` | In-progress answers (crash-safe), cleared after the Firestore write is acknowledged |
| `packs` | Pack metadata + version + sha256 from the index |
| `cards` | Library cards (for search when planting) |
| `paths`, `lessons`, `lesson_words` | Learning track content |
| `ring_log` | Native ring diagnostics mirrored for upload |
| `kv` | Small settings and sync cursors |

- Schema versioned; every migration has a test (Drift schema dumps + `drift_dev` migration testing).
- If the local DB is corrupt or a migration fails: delete and rebuild from the server (all local data is
  a cache), log `LOCAL_DB_CORRUPT`, never block startup.

---

## 6. Data lifecycle

- Messages and rounds are kept while the saff exists. When a saff ends, it becomes read-only.
- Imports: the uploaded file is deleted after parsing (success or failure).
- Selfies: deleted from Storage 24 h after the reveal; the `selfies/{uid}` doc is kept with `expired: true`
  and the times. Saved copies live only in the user's phone gallery.
- `requests/*` expire after 24 h (TTL policy). Presence docs expire 2 days after the occurrence.
- Account deletion: see `SECURITY.md` §6.
