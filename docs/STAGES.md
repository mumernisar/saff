# Build stages

Follow the stage protocol in `CLAUDE.md` §2 for every stage: start a stage file from
`stages/_TEMPLATE.md` (starting point + plan), get approval, build, then record what was done and why.

Order is risk-first: the alarm before features, the design system before screens, the server timing
before the morning loop.

---

## Stage 0: Foundations
**Starts from:** these docs, the mockups, an empty repo.
**Builds:** workspace + Melos scripts; all packages as empty shells with lints; `contracts/` with
`constants.json` and `errors.json` + `tools/gen_contracts` generating Dart and TS; `tools/check_imports`;
`saff_core` (`Result`, `AppFailure` hierarchy, `FailureMapper` + all mappers, `Log`, `Clock`, retry
helper); flavors dev/prod; Firebase projects wired (Auth, Firestore, Functions, Storage, FCM, App Check,
Crashlytics); `bootstrap.dart` with global error handlers; empty app shell with the 4 tabs; functions
skeleton (`core/errors`, logger, zod, idempotency helper); rules skeleton (deny all) + rules test harness;
CI workflow; cost protection on both Firebase projects (`ARCHITECTURE.md` §9a): budget alerts at $1 and $5,
plus a billing cap, `capBilling`, a function subscribed to the budget's Pub/Sub notifications that disables
billing on the project when spend passes $10 (Google's documented "cap costs" pattern); physical-phone
dev setup (`DEMO.md`, `DEV_RELAXATIONS.md`): `EMULATOR_HOST` in `env/dev.json` (the laptop's LAN IP),
emulators bound to `0.0.0.0`, `tools/demo/adb_reverse.sh` for USB, and the demo-timing overlay
`contracts/constants.demo.json` generated next to the real constants.
**Exit criteria:**
- `melos run ci` green in GitHub Actions.
- Generated contracts identical in Dart and TS (a test compares both against `contracts/`).
- A deliberate thrown `StateError` reaches Crashlytics in a dev build; a mapped `SocketException`
  becomes `NetworkFailure(NETWORK_OFFLINE)` (unit test).
- Import-boundary check fails on a planted violation.
- A simulated budget message disables billing on `saff-dev`.
- A dev build on a physical phone reaches the laptop's emulators over Wi-Fi (`EMULATOR_HOST`) and over USB
  (`adb reverse`).

## Stage 1: Alarm module
**Starts from:** Stage 0 shell.
**Builds:** `saff_alarm` per `ALARM.md`: Pigeon API, scheduler, receiver, ringing service, alarm activity
with pre-warmed `wakeMain` engine, native fallback, reschedule receivers, readiness report, ring log; a
temporary debug screen to schedule test alarms; the minimal wake entrypoint showing a placeholder ring screen.
**Exit criteria:** device checklist §9 passes on 3 OEMs + stock; ring log shows sound start < 500 ms and
wake UI < 1.5 s on a mid-range device; Play declarations drafted.

## Stage 2: Design system
**Starts from:** mockups in `docs/design/`.
**Builds:** `saff_ui`: tokens (colours light/dark/wake palette, type scale incl. Quran font, spacing,
radii, motion), theme, every component from the mockups with all states, the brightening wake background,
a component gallery screen (dev only), goldens.
**Exit criteria:** gallery matches mockups (owner review); goldens for every component state, light and
dark; text scale 1.3 doesn't break layouts.

## Stage 3: Identity and saffs
**Builds:** sign-in (Google, email link), profile (name, WhatsApp), `createSaff`, `joinSaff` (code + App
Link), `leaveSaff`, `removeMember`, `regenerateInvite`, members list, owner role, presence (online/last
seen), **multiple saffs per user** (saff switcher, `SaffContextController`, saff-scoped routes), routing
redirects; rules + rules tests for users/saffs/members; device registration for FCM; dev flavor only:
"Sign in as test user" with seeded accounts (Hamza, Ali, Sara) and `tools/demo/seed`, which can also
pre-create a pair or group saff with them (`DEV_RELAXATIONS.md` R-2, R-3).
**Exit criteria:** two emulators: create, join by code and by link, leave, remove; a user in two saffs
switches between them; free limits enforced on the server (group of 4, 2 saffs per user) with an
`EntitlementRepository` that reads a server-written default free entitlement (Plus itself arrives in Stage
13); full-saff and per-user-limit errors; rules tests for every allow/deny; integration test of the join flow;
two physical phones sign in as seeded users and see the same seeded saff (`DEMO.md`).

## Stage 4: Chat, proposals and local alarm scheduling
**Builds:** chat (Flyer Chat on Firestore): text, seen-by-all ticks, typing, reply, delete within 1 h,
system cards via `SystemMessageFactory`; alarm proposals: **pairs** mandatory consent, **groups** opt-in
participants, join/leave an alarm, suggest-another-time, expiry; `voteProposal` + `onVoteWritten`; the
30-minute alarm-conflict rule across saffs; alarms from **all** the
user's saffs → `AlarmService.setSchedule` (next 7 days) on every change; skip a morning; per-member alarm
sound; owner-only `updateSaffSettings` for groups.
**Exit criteria:** pair: alarm active only after both accept; group of 4: alarm starts at 2 participants
and rings only for the members who accepted (verified on devices); a change applies only when every
participant accepts; an alarm left with one participant keeps ringing (solo morning); counter-proposal and expiry per `PRODUCT.md` §4; alarms from two saffs
on one phone can't be within 30 minutes of each other (conflict fixtures incl. different timezones); skip
limits enforced; chat states covered by tests.

## Stage 5: Server timing, packs and content
**Builds:** `planOccurrences`, task queues (`lockRound` with a stub round, `offlineCheck`, `deadline`),
`sweeper`; occurrence fixtures incl. DST; packs sync on the client (`PackService`, Drift tables) and server
pack cache; content gateway (`/ayah`, `/surah`, `/words`, `/hadith`, `/resolve`) with Quran Foundation
adapter, CDN caching, App Check; `roundLocked` push → background download + resolve into Drift; demo timing applied by the server in the
emulator (`DEV_RELAXATIONS.md` R-1); the Functions emulator sends real FCM pushes with a local
service-account key (R-5).
**Exit criteria:** an alarm's occurrences and tasks appear 48 h ahead; killing a task is recovered by the
sweeper; a locked round with placeholders is fully resolved on the phone in airplane mode afterwards; with
demo timing, two physical phones get the real "round locked" push from the emulator 1 min before the alarm.

## Stage 6: The morning loop with Card Duel
**Builds:** round assembly (Card Duel lineup, seeded, seen-cards, difficulty mix); wake flow: ringing
screen with live statuses, hold to start, snooze, Card Duel play (choice/typed/ayah/blank cards, timer,
idle guard), result write, `onResultCreated` grading (normalisation fixtures), reveal (all submitted),
reveal screen, card review with talk questions, report a card, result chat card.
**Exit criteria:** 2- and 3-member mornings end to end on devices; grading fixtures pass in TS; reveal
happens exactly once under concurrent submissions (emulator test); answers survive an app kill mid-round.

## Stage 7: Waiting, nudges, deadline and fallbacks
**Builds:** waiting screen per member; `nudge` callable + high-priority push → re-ring; WhatsApp call/chat
per member and group link; offline alert; deadline reveal with missed members; offline arcade fallback
(unranked); unresolvable card exclusion.
**Exit criteria:** nudge re-rings a locked phone within 10 s (device checklist #9); limits enforced;
deadline reveal verified; airplane-mode morning plays and syncs later; the two-phone demo in `DEMO.md`
runs end to end with demo timing (nudge via real FCM from the emulator, offline alert at 30 s, deadline
reveal at 5 min).

## Stage 8: More modes
**Builds:** `mode_word`, `mode_arcade` (Climber, Rapid Roll with seeded platforms and difficulty ramp),
`mode_selfie` (front camera capture, compression, upload queue that survives going offline, selfie reveal
grid, save to gallery, chat thumbnails, 24 h server deletion), server graders for each, mode schedule setting
(surprise/order/single; pair: both agree; group: owner). Selfie rounds are unranked; selfies have a Save
to gallery button and are deleted from the server 24 h after the reveal.
**Exit criteria:** selfies stay unreadable to others until the reveal (rules test) and are deleted after
retention; a denied camera permission falls back to an arcade game; same seed → identical layouts on two devices; ramp tuned so median test run is
45–90 s; 60 fps on the low-end device; schedule rules (no 3 in a row) verified by fixtures.

## Stage 9: Learning track (personal)
**Builds:** personal path and daily goal; path/surah/lesson screens with word popovers and audio; mark
learned; eligibility by `covers` per user; per-user FSRS (`ts-fsrs`); Learning Duel with per-member cards
ranked by accuracy; Learn-tab "Review now" (`submitReview`); shared daily review cap; 9 pm reminder;
progress visible to saff members.
**Exit criteria:** a user learns Al-Fil lesson 1 and gets only their eligible cards next review; FSRS state
updates per rating rules; lesson screen works offline after first load.

## Stage 10: Planting cards (pairs only)
**Builds:** plant flow (4 templates), `plantCard` (pairs only, 2 per night), teasers after lock, bonus cards
in rounds (never scored), ask-me grading by the planter, library search (FTS5); planting hidden in groups.
**Exit criteria:** planted cards appear only for the other member, after the scored cards; limits enforced;
the option disappears when a pair becomes a group.

## Stage 11: Stats, calendar, badges
**Builds:** `onRevealed` stats pipeline: streaks (saff and personal, skip freeze), success rate,
first waker, head-to-head, nudge counts, monthly calendar docs, badges; Stats tab per mockups.
**Exit criteria:** stats fixtures (including skips, offline fallback, missed) pass; calendar day sheet
matches round data.

## Stage 12: Imports and custom packs
**Builds:** Anki import (all formats in `CONTENT.md` §6), preview, add to saff, card mix with custom
packs, pack by link, delete imported pack. Imports and packs by link are Plus features: gate them on the
entitlement (until Stage 13, a dev-only switch grants Plus for testing).
**Exit criteria:** every fixture deck imports with expected counts and warnings; a 2,000-card deck imports
in < 60 s; custom mix rounds contain imported cards per rules.

## Stage 13: Onboarding, settings and support
**Builds:** full onboarding (permissions walkthrough with OEM guides, test alarm), settings screens, theme,
notification toggles, feedback with failure-code details, account deletion (in-app + web URL), About with
content attributions. **Saff Plus** (`PRODUCT.md` §15): Play subscription products, purchase flow,
`verifyPurchase`, `restorePurchases`, Play real-time notifications (`onPlayNotification`), entitlement
computation, limit recompute for owned saffs, grace and lapse rules, `claimOwnership`, Plus surfaces
(full-saff prompt, Settings page, feature-point prompts), 30-day stats window, extra themes and tones,
Supporter badge.
**Exit criteria:** fresh install to first ring on each OEM following only on-screen steps; deletion
removes everything per `SECURITY.md` §6 (emulator test); with Play test accounts: subscribe, renew, cancel,
grace, expire and refund each produce the right entitlement; a saff of 8 whose owner lapses keeps all 8
members and alarms but blocks joins and new alarms; a Plus member claims ownership and the block lifts.

## Stage 14: Hardening and release
**Builds:** performance budgets, accessibility pass (TalkBack, contrast, text scale), crash-free soak
with a closed beta saff group for 2 weeks, Play Console declarations (exact alarm, full-screen intent,
foreground service type), Data Safety form, store listing, release pipeline; every row of
`DEV_RELAXATIONS.md` reverted or proven absent from the prod build.
**Exit criteria:** every `DEV_RELAXATIONS.md` row has its revert evidence; budgets met; zero open critical bugs; beta crash-free sessions ≥ 99.5%; internal track
release approved.
