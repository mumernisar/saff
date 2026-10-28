# Architecture

This document fixes how Saff is built. Each major choice ends with a decision record (§11) listing
the alternatives that were considered. Changing a decision requires the owner's approval and an
update here.

---

## 1. Principles

1. **The alarm is sacred.** Ringing depends on nothing but the phone: no network, no Firebase, no
   Flutter engine. Everything else may degrade; the alarm may not.
2. **Server-authoritative game.** One implementation of every rule that affects more than one person
   (round assembly, grading, reveal, streaks, stats, learning schedule) lives on the server. Clients
   capture input and display results. No logic is duplicated across Dart and TypeScript.
3. **Offline-first client.** The phone reads from local stores and syncs in the background. A locked
   round plays with no connection; writes queue and replay.
4. **Separation of concerns** (Flutter's official architecture guide): a UI layer (views and view
   models) and a data layer (repositories and services), with one-way data flow.
5. **Modularity by stability.** Code that changes rarely and is reused (core types, design system,
   alarm, game modes) lives in packages with explicit dependencies. Fast-changing feature code lives in
   the app with lint-enforced boundaries.
6. **Explicit failure.** Errors are values (`Result<T>`), classified by a catalog shared between client
   and server (`ERRORS.md`).
7. **Contracts over conventions.** Anything both sides must agree on (constants, error codes, push
   payloads, callable function shapes) is defined once in `contracts/` with shared test fixtures.

---

## 2. System overview

```
┌──────────────────────── Android phone ────────────────────────┐
│  Flutter app (saff_app)                                        │
│   UI layer ─ views + view models (Riverpod)                    │
│   Data layer ─ repositories ─ services                         │
│      Firestore SDK (offline cache)   Drift (SQLite)            │
│      Content gateway client          Pack client               │
│      saff_alarm (Pigeon) ───────────────┐                      │
│                                         ▼                      │
│  Native alarm module (Kotlin): AlarmManager.setAlarmClock,     │
│  ringing foreground service, full-screen alarm activity,       │
│  boot/time-change rescheduling, native fallback screen         │
└───────────────┬───────────────────────────────┬────────────────┘
                │ Firestore / FCM / Storage      │ HTTPS (cached)
┌───────────────▼───────────────┐  ┌────────────▼───────────────┐
│ Firebase                       │  │ Firebase Hosting + CDN      │
│  Auth · Firestore · Storage    │  │  /api/content/** → content  │
│  Cloud Functions (TypeScript)  │  │  gateway function           │
│   triggers · task queues ·     │  └────────────┬───────────────┘
│   callables · scheduled sweep  │               │
│  FCM · App Check · Crashlytics │   Quran Foundation API (OAuth2,
└───────────────┬───────────────┘   secret on server) · hadith data
                │
     GitHub Pages: packs repo dist/ (index.json + pack JSON)
```

---

## 3. Client layers

```
View (widget)  →  ViewModel  →  Repository  →  Service
renders state     UI state +     source of truth,   wraps exactly one
                  actions        caching, mapping,  external system
                                 retries, Result
```

### 3.1 Views
- `ConsumerWidget`/`ConsumerStatefulWidget`. Render a ViewModel's state; call its methods on gestures.
- No business logic beyond layout decisions. No `await` on anything except ViewModel actions.
- One view ↔ one ViewModel (Flutter guide). Reusable widgets take plain values and callbacks.

### 3.2 ViewModels
- Riverpod `Notifier` / `AsyncNotifier` classes, one per screen (or per self-contained component).
- State is an immutable `freezed` class: data + `ActionStatus` for in-flight actions
  (`idle | running | success | failure(AppFailure)`).
- Actions are methods returning `Future<void>`; they call repositories, receive `Result`, and update state.
- ViewModels may combine several repositories. They never call services.

### 3.3 Repositories
- One per data type: `AuthRepository`, `ProfileRepository`, `SaffRepository`, `AlarmRepository`,
  `ProposalRepository`, `ChatRepository`, `RoundRepository`, `ContentRepository`, `PackRepository`,
  `LearningRepository`, `StatsRepository`, `ImportRepository`, `SettingsRepository`,
  `EntitlementRepository` (the user's plan and limits, read from the server), `PurchaseRepository`.
- Responsibilities: single source of truth, combining services (e.g. Firestore + Drift cache),
  mapping DTOs → domain models, caching, retry policy, converting exceptions to failures.
- Public API returns `Result<T>`, `Stream<T>`, or `Stream<Result<T>>`. Never throws.
- Defined as an abstract interface + implementation, so tests and previews can use fakes.

### 3.4 Services
- Thin wrappers, one per external system: `FirestoreService` (typed collection refs), `AuthService`,
  `MessagingService` (FCM), `StorageService`, `FunctionsService` (callables), `ContentGatewayService`
  (HTTP), `PackService` (HTTP), `LocalDb` (Drift), `AlarmService` (saff_alarm), `BillingService`,
  `DeviceService` (battery optimisation, OEM, app info), `ClockService`.
- No business logic, no caching policy. They may throw; repositories catch and map.

### 3.5 Domain models
- Pure Dart immutable classes in `saff_domain` (no Flutter, no Firebase imports).
- DTOs (Firestore/JSON shapes) live next to the service that reads them and are mapped explicitly;
  domain models never contain `Timestamp` or `DocumentReference`.

### 3.5a Entitlements on the client
- `EntitlementRepository` streams the user's `Entitlement` (`plan`, `status`, `expiresAt`, `limits`) from
  `users/{uid}/entitlement` (server-written). The client never derives limits itself.
- ViewModels check `limits` only to decide what to show (e.g. disable "Invite" with a Plus hint when the
  saff is full). Enforcement is on the server; the client check is for UX only.
- Constants for limits are generated from `contracts/constants.json`.

### 3.6 Use cases (optional layer)
Only when logic spans several repositories and is reused by several ViewModels
(e.g. `ScheduleAlarmsForSaff` combining AlarmRepository + AlarmService + SettingsRepository).
Plain classes with one `call()` method in `app/lib/domain/`. Don't create them by default.

---

## 4. Modularity

### 4.1 Packages
| Package | Contents | May depend on |
|---|---|---|
| `saff_core` | `Result`, `AppFailure` hierarchy, failure codes (generated), `Log` interface, `Clock`, id helpers, extensions | nothing (pure Dart) |
| `saff_domain` | Domain models (`Saff`, `Member`, `Alarm`, `Occurrence`, `Proposal`, `Round`, `Card`, `Lesson`, `Stats`...), generated constants | `saff_core` |
| `saff_ui` | Design tokens, theme (light/dark/wake palette), components from the mockups, icons, motion tokens, l10n of shared strings | `saff_core`, Flutter |
| `saff_alarm` | Alarm plugin: Dart API, Pigeon definitions, Kotlin implementation, (later) Swift/AlarmKit | `saff_core`, Flutter |
| `saff_modes` | The `GameMode` contract, `RoundContent`/`ModeResult` types, mode registry, shared mode chrome | `saff_core`, `saff_domain`, `saff_ui` |
| `mode_card_duel` | Card Duel and Learning Duel play UI (card types, timers) | `saff_modes`, `saff_ui` |
| `mode_word` | Word mode | `saff_modes`, `saff_ui` |
| `mode_arcade` | Climber and Rapid Roll (Flame) | `saff_modes`, `saff_ui`, `flame` |
| `mode_selfie` | Selfie mode: in-app front camera capture, compression, upload queue | `saff_modes`, `saff_ui`, `camera` |
| `saff_app` | Features, repositories, services, DI, routing, entrypoints | all of the above |

Flame is confined to `mode_arcade` and the camera plugin to `mode_selfie`, so upgrading either can never
break the rest of the app.

### 4.2 Features inside the app
`app/lib/features/<feature>/` with `views/`, `view_models/`, `widgets/`. Features:
`onboarding`, `auth`, `saff`, `alarms`, `wake` (ringing, play host, waiting, reveal, review), `chat`,
`plant`, `learn`, `stats`, `settings`, `imports`, `support`.

Rules (enforced by the import-boundary check in CI, `REPOSITORY.md` §4):
- A feature may import packages, `app/lib/data/**`, `app/lib/domain/**`, `app/lib/shared/**`.
- A feature may not import another feature. Navigation between features uses route names only.

### 4.3 The game mode contract
```dart
abstract interface class GameMode {
  ModeId get id;                                    // cardDuel, learningDuel, word, climber, rapidRoll, selfie
  /// Builds playable content from the locked round payload. Must not do I/O.
  RoundContent prepare(LockedRound round, ResolvedContent content);
  /// The play UI. Calls [onEvent] for each answer/progress event and [onDone] exactly once.
  Widget build(RoundContent content, ModeCallbacks callbacks);
  /// Local, offline-capable seed generation for the arcade fallback (arcade modes only).
  RoundContent? offlineFallback(int seed) => null;
}
```
The wake feature hosts any mode through this contract; reveal, stats and scheduling never know which
mode ran. Adding a mode = one package + registration in `ModeRegistry` + a server-side grader.

### 4.4 Factories in the design
Factories are used where the concrete type depends on runtime data, never as ceremony:
- `FailureMapper` chain: turns any exception into an `AppFailure` (`ERRORS.md` §4).
- `ModeRegistry.create(ModeId)`: returns the `GameMode` for a round.
- `CardViewFactory`: picks the widget for a card type (choice/typed/self/ayah/blank).
- `SystemMessageFactory`: maps a chat system message type to its card widget.
- `EnvironmentConfig.fromDefines()`: builds the dev/prod configuration at startup.

---

## 5. State management and dependency injection

- **Riverpod 3.x (stable APIs only).** Providers are the DI container: services and repositories are
  `Provider`s overridden per environment and in tests; ViewModels are `NotifierProvider`s.
- **No experimental features**: don't use Riverpod's experimental offline persistence or mutations.
- **Automatic retry:** Riverpod 3 retries failing providers by default. Configure the global retry at
  the `ProviderScope` to follow our policy: retry only failures whose `retryable` flag is true, with
  our backoff (`ERRORS.md` §6); never retry domain failures.
- Use `riverpod_generator` annotations for providers to keep declarations uniform.
- `ref.watch` in build methods, `ref.read` in callbacks, `ref.listen` for one-off effects (navigation,
  snackbars). Never store `ref` in models.
- Long-lived streams (saff, chat, round status) use `StreamProvider`s scoped to the screen
  (auto-dispose) so Firestore listeners close when not visible.

---

## 5a. Multiple saffs per user

A user can be in several saffs, so "which saff" is explicit everywhere:
- Every route that shows saff data carries the saff id (`/saff/:saffId/chat`, `/saff/:saffId/stats`, ...).
- `SaffContextController` (Riverpod) holds the **selected saff** for the tab screens; the saff switcher
  (per mockups) changes it; it's persisted locally and restored on launch.
- Repositories take `SaffId` as a parameter; they never read a global "current saff".
- Cross-saff views (Today's next alarm, personal stats, personal learning) are built by repositories that
  query the user's memberships (`users/{uid}.saffIds`) and merge results.
- The native alarm schedule contains occurrences from **all** saffs (each tagged with `saffId`); the
  wake entrypoint opens the round of the saff the ringing occurrence belongs to.
- Pushes carry `saffId`; tapping one switches the selected saff before navigating.

## 6. Navigation

- `go_router` with typed routes (`go_router_builder`).
- Top-level shell with 4 tabs: Today, Chat, Learn, Stats. Settings is a pushed route.
- Full-screen flows (wake, plant, onboarding, import) are outside the shell.
- Deep links: `saff.app/join/<code>` (Android App Links, verified), `saff://wake/<occurrenceId>`
  (internal, from the alarm activity), push notification taps (route encoded in the payload).
- Redirect logic: no session → onboarding; session but no profile → profile setup; no saff → saff setup.

---

## 7. Two entrypoints

| Entrypoint | Started by | Contains |
|---|---|---|
| `main_<flavor>.dart` | Launcher, links, notification taps | Full app |
| `wake_main.dart` (`@pragma('vm:entry-point') wakeMain`) | The native alarm activity | Only the wake flow (ringing → play → waiting → reveal), minimal providers, reads the locked round from Drift |

The native module pre-warms a `FlutterEngine` for `wakeMain` when the ringing service starts, so the
wake UI appears within ~1 s while the sound has already started natively. If the engine fails to
start within 5 s or crashes, the native fallback screen (dismiss + "Open Saff") takes over.

---

## 8. Offline and sync

| Data | Store on phone | Sync |
|---|---|---|
| Saff, members, alarms, proposals, chat, rounds, results, stats | Firestore offline cache (persistence on, cache 100 MB) | Firestore listeners; writes queue offline |
| Locked round + resolved content for upcoming occurrences | Drift (`locked_rounds`, `resolved_content`) | Downloaded on the "round locked" push and on app open |
| Alarm schedule for the native module | Native SharedPreferences (written via Pigeon) | Rewritten from Firestore alarms whenever they change |
| Packs index, library cards, lessons, paths | Drift | On app open if `index.json` changed (checksums) |
| Pending results (answers in progress) | Drift (`pending_results`) | Written as Firestore docs when done; Firestore queues if offline |
| Learning progress (own) | Firestore + Drift mirror | Listener |

- Firestore listeners are attached only while the relevant screen (or the wake flow) is visible.
- Content resolution (placeholders → text) happens right after a round locks, so the morning needs no network.
- Writes that must happen exactly once use deterministic document ids (e.g. `results/{uid}`), so a
  retried write overwrites rather than duplicates.

---

## 9. Server responsibilities

| Responsibility | Mechanism |
|---|---|
| Plan occurrences 48 h ahead; enqueue lock / offline-check / deadline tasks | Daily scheduled function + on alarm change |
| Night lock: assemble round (mode, cards, seed, planted cards) | Task-queue function |
| Offline check at +2 min | Task-queue function |
| Grade results; reveal when all submitted | Firestore trigger on result write |
| Deadline at +30 min: mark missed, reveal | Task-queue function |
| Stats, streaks, badges, head-to-head | Trigger on reveal |
| Learning schedule per user (FSRS via `ts-fsrs`) | Trigger on graded learning answers |
| Proposals: pair = both accept; group = opt-in participants (see `PRODUCT.md` §4.2); expiry | Trigger + lock task |
| Nudges, notifications | Callable (nudge) + triggers → FCM |
| Content gateway (Quran text, translations, word-by-word, audio, hadith) | HTTPS function behind Hosting CDN |
| Anki import | Storage trigger |
| Saff Plus: purchase verification, entitlements, saff limits, lapse handling | Callable + Play real-time developer notifications (Pub/Sub trigger) + daily check |
| Account deletion | Callable |
| Safety-net sweep (missed tasks) | Scheduled every 15 min |

Details in `BACKEND.md`.

---

## 9a. Cost model: target is $0 per month

Firebase requires the pay-as-you-go (Blaze) plan for Cloud Functions, Cloud Tasks and new Storage buckets,
but each product has a monthly no-cost allowance that this app stays far inside at the scale of friends
and early users. **Set a budget alert at $1 and $5 on day one.**

| Product | No-cost allowance (check current numbers) | Our expected use |
|---|---|---|
| Firestore | 50k reads, 20k writes, 20k deletes per day; 1 GiB stored | A few hundred reads/writes per saff per day |
| Cloud Functions | 2M invocations, 400k GB-seconds, 200k CPU-seconds per month | Thousands of short invocations |
| Cloud Tasks | 1M operations per month | 3 tasks per occurrence |
| Cloud Scheduler | 3 jobs per billing account | 3 jobs (`planOccurrences`, `sweeper`, `cleanup`; the hourly reminder is folded into `sweeper`) |
| Cloud Storage | 5 GB stored, 100 GB/month download in US regions | Import files (deleted after parsing) and selfies (~150 KB each, deleted after the retention period) |
| FCM, Auth (email/Google), Crashlytics, App Check (Play Integrity standard requests) | Free | |
| Hosting (CDN for the content gateway) | 10 GB stored, 360 MB/day transfer | Cached text responses |
| Secret Manager | 6 secret versions, 10k accesses per month | 1 secret, token cached in memory |

**Rules that keep it at $0:**
- `maxInstances` on every function (e.g. 3–10), `minInstances: 0` (cold starts are acceptable).
- Presence and typing writes are throttled (typing at most every 3 s, presence every 60 s while open).
- Listeners attach only while a screen is visible; chat pages load 50 messages at a time.
- Content gateway responses are cached at the CDN for 30 days (content is immutable), so upstream
  calls and function invocations happen once per item, not once per user.
- TTL policies delete short-lived docs (presence, idempotency records).
- Play real-time developer notifications arrive on Pub/Sub (free allowance: 10 GiB/month), a few
  messages per subscriber per month.
- Selfies are resized on the phone (1080 px long edge, JPEG quality 80) before upload and deleted after
  the retention period, so storage stays far below the allowance.
- All products run in `us-central1`, where every no-cost allowance applies.
- The Anki import function runs with 1 GiB memory only when a file arrives; a 50 MB deck costs roughly
  tens of GB-seconds, so thousands of imports fit in the monthly allowance.

**Render or Heroku instead?** Not needed. They would add a second platform to deploy, monitor and secure,
and the free tiers sleep or expire; the Firebase allowances already cover every server job here. They
remain a fallback for the content gateway if Firebase pricing ever changes (the gateway is a plain HTTP
service behind an interface, so it can move).

---

## 10. Chosen packages

| Need | Package | Notes |
|---|---|---|
| State / DI | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` | 3.x stable APIs |
| Models | `freezed`, `json_serializable` | Codegen for models only |
| Navigation | `go_router`, `go_router_builder` | Typed routes |
| Local DB | `drift`, `drift_flutter` | Schema versioning + migration tests |
| Firebase | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `firebase_storage`, `cloud_functions`, `firebase_app_check`, `firebase_crashlytics` | FlutterFire |
| Native bridge | `pigeon` | Type-safe platform channels |
| Chat UI | `flutter_chat_ui` (Flyer Chat) | Backend-agnostic |
| Games | `flame` | Only in `mode_arcade` |
| Camera | `camera` | Only in `mode_selfie` |
| HTTP | `http` (+ our retry wrapper) | Simple, testable |
| Billing | `in_app_purchase` | Saff Plus subscriptions (Google Play Billing) |
| Audio (recitation, word audio) | `just_audio` | |
| Lints | `very_good_analysis` | Strict lint set |
| Testing | `mocktail`, `fake_cloud_firestore` (unit only), Firebase Emulator Suite (integration) | |
| Server | `firebase-functions` v2, `firebase-admin`, `zod`, `ts-fsrs`, `fflate`, `fzstd`, `sql.js` | TypeScript, Node LTS |

Verify each package's current version, licence and maintenance at the start of the stage that adds it.

---

## 11. Decision log

### D1. Flutter for the client
- **Chosen:** Flutter (Dart).
- **Alternatives:** native Kotlin (best alarm control, but iOS means a second app); React Native
  (weaker for games and heavy native work); Kotlin Multiplatform (shared logic, but UI twice).
- **Why:** one UI codebase, strong game support (Flame), first-class native bridging for the alarm.

### D2. Firebase as the backend
- **Chosen:** Firebase (Auth, Firestore, Functions, FCM, Storage, Hosting, App Check, Crashlytics).
- **Alternatives:** Supabase (SQL, realtime; weaker offline client story on Flutter, no FCM-equivalent
  bundle); a custom Go/Node backend (full control; far more to operate).
- **Why:** offline-capable client SDK, push, scheduled/task functions and security rules in one
  platform; near-zero cost at this scale.

### D3. Riverpod for state and DI
- **Chosen:** Riverpod 3 (stable APIs).
- **Alternatives:** Bloc (explicit, more boilerplate); `ChangeNotifier` + provider as in the official
  case study (simple, but manual disposal and DI); signals.
- **Why:** DI and state in one tool, auto-dispose of listeners, excellent testing overrides, consistent
  output when code is written by AI.

### D4. Drift for local storage
- **Chosen:** Drift (SQLite).
- **Alternatives:** Isar/Hive (original maintainer stepped back; community forks); ObjectBox (licensing
  and codegen weight); raw sqflite (no type safety).
- **Why:** typed queries, reactive streams, mature migrations with schema tests.

### D5. Own native alarm module
- **Chosen:** `saff_alarm`, our own Kotlin module behind Pigeon.
- **Alternatives:** community alarm plugins.
- **Why:** the alarm is the product. We need control over exact scheduling, rescheduling triggers,
  the ringing service, full-screen activity, engine pre-warm and the native fallback. See `ALARM.md`.

### D6. Monorepo with pub workspaces and Melos
- **Chosen:** one repo; Dart pub workspaces (single lockfile) + Melos 7 scripts.
- **Alternatives:** polyrepo (versioning overhead); single package (no enforced boundaries).
- **Why:** atomic changes across app, packages, functions and rules; one resolve; enforced dependencies.

### D7. Server-authoritative game logic
- **Chosen:** rounds, grading, reveal, stats, learning schedule on the server only.
- **Alternatives:** compute on clients with a shared seed (works offline, but logic duplicated in Dart
  and TypeScript and trivially cheatable).
- **Why:** one implementation, fair results, simpler clients. Offline is covered by locking rounds the
  night before and the arcade fallback.

### D8. Cloud Tasks for timed work
- **Chosen:** task-queue functions enqueued per occurrence (lock, offline check, deadline), plus a
  15-minute sweeper as a safety net.
- **Alternatives:** a 1–5 minute cron scanning everything (simple, imprecise, wasteful).
- **Why:** precise timing, built-in retries, idempotent handlers; the sweeper catches anything missed.

### D9. Own `Result` type
- **Chosen:** a small sealed `Result<T>` (`Ok`/`Err`) in `saff_core`, as in Flutter's architecture guide.
- **Alternatives:** exceptions everywhere (invisible failure paths); `fpdart` `Either` (heavier
  functional style, extra dependency).
- **Why:** failures visible in signatures, exhaustive `switch`, zero dependencies.

### D10. Content gateway on the server
- **Chosen:** an HTTPS function behind Firebase Hosting's CDN that calls the Quran Foundation API with
  client credentials kept in Secret Manager, plus hadith data, and returns cache-friendly responses.
- **Alternatives:** calling content APIs from the app (would expose the OAuth client secret); bundling
  translations into the packs repo (redistribution licensing).
- **Why:** secrets stay server-side, responses are cached at the edge, one place to switch providers.

### D11. Anki import on the server
- **Chosen:** upload the file to Storage; a function parses it (pure-JS zip, zstd and SQLite) and
  writes an imported pack for the saff.
- **Alternatives:** parsing on the phone (zero server use, but adds a native zstd library and reading of
  arbitrary SQLite files to the app, and sanitising must ship with every app version).
- **Why:** one implementation, central sanitising and limits, lighter app. Cost stays inside the free
  allowance (§9a). If the owner ever wants zero server involvement, the parser is pure logic in
  `functions/src/domain/anki/` and can be ported to a Dart package used on the phone.

### D13. Stay on Firebase only (no Render/Heroku)
- **Chosen:** every server job on Firebase within its no-cost allowances.
- **Alternatives:** host the gateway or import worker on Render (free tier) or Heroku (credits).
- **Why:** one platform, one auth/App Check story, no sleeping instances in the morning path. Revisit only
  if Firebase usage leaves the free allowances.

### D12. Contracts folder
- **Chosen:** `contracts/` holds `constants.json`, `errors.json`, push payload and callable schemas, and
  JSON fixtures; a generator writes Dart and TypeScript from them; both sides test against the fixtures.
- **Alternatives:** keep definitions in each codebase (they drift apart).
- **Why:** client and server can't disagree about a limit, an error code or a payload.

### D14. Subscriptions verified on our own server
- **Chosen:** `in_app_purchase` on the client; a Cloud Function verifies every purchase token with the
  Google Play Developer API and listens to Play real-time developer notifications (Pub/Sub). Entitlements
  are written by the server only; clients read them.
- **Alternatives:** RevenueCat (free at this scale, simpler, but a third-party dependency holding
  purchase data); trusting the client's purchase state (trivially bypassed).
- **Why:** no extra service, stays within free allowances, the server is already authoritative for limits.
