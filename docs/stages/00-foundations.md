# Stage 00: Foundations

Branch: `stage/00-foundations` · Started: 2026-10-28 · Finished: YYYY-MM-DD

## 1. Starting point
What exists right now, verified by reading the code and running it (not copied from older notes):
- Packages and their state: **none.** There is no application code and no git repository for the app.
  The working folder `Saff/` holds:
  - `saff-docs/`: `CLAUDE.md` and `docs/` (all docs listed in `docs/README.md`; `docs/stages/` holds only
    `_TEMPLATE.md`; `docs/design/` held only `README.md`, and now `flows.md` from this stage's start). Not a git repo.
  - `saff-mobile-app-prototype/`: the Claude Design handoff bundle (`Duha Prototype.dc.html`,
    `Duha Screens.dc.html`, an unused "Organic" design system under `_ds/`). Not a git repo. No PNG exports.
  - `saff-cards/packs/duha-packs/`: the packs repository (git, 2 commits, `dist/index.json` built
    2026-10-18) plus a zip of it.
- Screens and features working: none.
- Server functions deployed / in emulators: none. No Firebase project ids are recorded anywhere; whether
  `saff-dev` / `saff-prod` exist is unknown (to confirm with the owner).
- Tests and coverage: none.
- Toolchain on this machine (checked 2026-10-28): git 2.50.1, Homebrew, Node v24.18.0 + npm, OpenJDK 25.
  **Not installed:** Flutter, Dart, FVM, Melos, Firebase CLI, FlutterFire CLI, Android SDK (`ANDROID_HOME`
  unset, no `adb`), GitHub CLI. No GitHub remote exists.
- Known issues carried in: the gaps and contradictions in `docs/design/flows.md` §3–5. Three of them
  affect this stage: D-1 (`mode_selfie` missing from `REPOSITORY.md`), D-2 (mappers vs. a pure-Dart
  `saff_core`), D-3 (`INVALID_ARGUMENT` missing from the catalog). The mockup contradictions don't block
  Stage 0 (the shell only needs the four tabs, which docs and mockups agree on: Today, Chat, Learn, Stats).

## 2. Plan
What this stage will build, in order, mapped to the exit criteria in `STAGES.md`.

Exit criteria (from `STAGES.md`):
- **E1** `melos run ci` green in GitHub Actions.
- **E2** Generated contracts identical in Dart and TS (a test compares both against `contracts/`).
- **E3** A deliberate thrown `StateError` reaches Crashlytics in a dev build; a mapped `SocketException`
  becomes `NetworkFailure(NETWORK_OFFLINE)` (unit test).
- **E4** Import-boundary check fails on a planted violation.

Steps:

0. **Prerequisites (need owner approval / action, nothing done yet).**
   - Install: FVM + a pinned Flutter stable (pinned in `.fvmrc`, also used by CI), Melos 7, Node 22 LTS
     for Functions (via `.nvmrc`; the machine has Node 24), JDK 21 for the Firebase emulators, Android
     SDK + an emulator image, Firebase CLI, FlutterFire CLI, GitHub CLI. Each recorded in §5.
   - Owner: Firebase projects `saff-dev` and `saff-prod` on Blaze, region `us-central1`, budget alerts
     at $1 and $5 (ARCHITECTURE §9a); Crashlytics enabled in `saff-dev`; a GitHub repository for CI.
   - `git init` at the repo root, first commit of the docs on `main`, then branch `stage/00-foundations`.
1. **Workspace** (→ E1). Root `pubspec.yaml` with `workspace:` listing `app` and every package, Melos
   scripts (`generate`, `analyze`, `format`, `format:check`, `test`, `test:integration`, `ci`),
   `analysis_options.yaml` on `very_good_analysis`, `.gitignore` (incl. `env/*.json` except
   `env/example.json`), root `README.md`.
2. **Package shells** (→ E1, E4). `saff_core`, `saff_domain` (pure Dart); `saff_ui`, `saff_alarm`
   (plugin shell, Android only, no Pigeon yet), `saff_modes`, `mode_card_duel`, `mode_word`,
   `mode_arcade`, and `mode_selfie` if D-1 is confirmed. Each: one library file + `lib/src/`,
   `resolution: workspace`, `publish_to: none`, dependencies exactly as ARCHITECTURE §4.1, a smoke test.
3. **Contracts and generator** (→ E2). `contracts/constants.json` (every constant in PRODUCT §14, with
   free/plus limit values), `contracts/errors.json` (the full initial catalog in ERRORS §5, plus
   `INVALID_ARGUMENT` if D-3 is confirmed; each code with kind, severity, retryable, httpsCode,
   messageKey, description), empty `contracts/payloads/` and `contracts/fixtures/`.
   `tools/gen_contracts` (Dart) writes `FailureCode` into `saff_core`, the constants into `saff_domain`,
   and `functions/src/contracts/` in TypeScript, plus English ARB entries for every `messageKey`.
   Contract tests on both sides load `contracts/*.json` and assert every code / constant and field
   matches the generated output; CI also regenerates and fails on any diff.
4. **Import-boundary check** (→ E4). `tools/check_imports` (Dart) enforcing REPOSITORY §4: the
   package allow-list from ARCHITECTURE §4.1, feature → feature imports, views importing services /
   `cloud_firestore` / `firebase_*` / `drift` / `saff_alarm`, and `src/` reach-ins. Tests run it on
   fixture trees with one planted violation of each kind and assert a non-zero exit and a clear message.
5. **`saff_core`** (→ E3, coverage ≥ 90%). `Result` (`Ok`/`Err`, `map`, `flatMap`, `fold`, `getOrNull`,
   `Result.guard`), the sealed `AppFailure` hierarchy with `FailureSeverity` and `DeviceFix`,
   `ExceptionMapper` + `FailureMapper`, the mappers that need no plugin types (`AppFailureMapper`,
   `NetworkExceptionMapper`, `FormatExceptionMapper`, `HttpStatusMapper`), `Log` with key redaction,
   `Clock`, and the retry helper (full jitter, base 500 ms, factor 2, cap 30 s, 4 / 6 attempts) tested
   with a fake clock. Unit test: `SocketException` → `NetworkFailure(NETWORK_OFFLINE)`.
   Where the Firebase / Platform / Drift mappers live depends on D-2 (proposal below: in the app's data layer).
6. **App shell** (→ E1, E3). Android flavors `dev` / `prod`, `main_dev.dart` / `main_prod.dart`,
   `EnvironmentConfig.fromDefines()`, `env/example.json`. `bootstrap.dart`: Firebase init per flavor,
   App Check (debug provider in dev, Play Integrity in prod), Crashlytics, `FlutterError.onError`,
   `PlatformDispatcher.instance.onError`, release `ErrorWidget.builder`, a logging `ProviderObserver`,
   `ProviderScope` with retry limited to retryable failures. `go_router` shell with the 4 tabs (Today,
   Chat, Learn, Stats) as placeholder views and a pushed Settings route; ARB l10n set up. A dev-flavor-only
   debug action that throws a `StateError`; evidence = the Crashlytics issue in `saff-dev` (screenshot).
7. **Firebase wiring** (→ E1). `firebase/firebase.json`, `.firebaserc` (dev, prod), `firestore.rules`
   and `storage.rules` that deny everything, empty `firestore.indexes.json`, emulator config.
   `flutterfire configure` per flavor (options files committed, as SECURITY §4 allows). Auth, Firestore,
   Functions, Storage, FCM, App Check, Crashlytics plugins added and initialised (no feature use yet).
   `firebase/rules-tests/` with `@firebase/rules-unit-testing`: deny-all cases for Firestore and Storage;
   `npm run test:rules`.
8. **Functions skeleton** (→ E1, E2). `functions/` TypeScript strict, Node 22, `firebase-functions` v2,
   `firebase-admin`, `zod`; `src/index.ts` exports only; `core/errors` (`AppError` from the generated
   catalog, conversion to `HttpsError` with `details.code`), `core/logger` (structured, with `requestId`),
   `core/idempotency` (`requests/{requestId}`, 24 h `expiresAt`, transaction). Lint, typecheck, `vitest`
   unit tests, and an emulator test that the idempotency helper returns the stored response when run twice.
   No functions deployed in this stage.
9. **CI** (→ E1). `.github/workflows/ci.yml` per REPOSITORY §8: pinned Flutter, Node, Java; bootstrap;
   generate + fail on diff; format check; analyze (+ `check_imports`); tests with the coverage gates of
   TESTING §6; functions lint/typecheck/tests with emulators; rules tests; dev debug APK. Run
   `melos run ci` locally, then push and get a green run (link in §7).
10. **Close the stage.** Fill §3–9, update `REPOSITORY.md` / `ARCHITECTURE.md` for any decision made
    here (D-1, D-2), record every dependency in §5, ask for review.

Approved by owner on: YYYY-MM-DD

## 3. What was done
Summary of the work, by area (client, native, functions, rules, contracts, docs). Link key files.

## 4. Decisions and why
| Decision | Alternatives considered | Why this one |
|---|---|---|

## 5. Dependencies added
| Package | Version | Licence | Why | Alternatives |
|---|---|---|---|---|

## 6. Deviations from the docs
What differs from the documentation and why; which docs were updated to match.

## 7. Evidence of exit criteria
- [ ] E1 `melos run ci` green in GitHub Actions → link to the run
- [ ] E2 Generated contracts identical in Dart and TS → contract test names (Dart + TS), CI diff step
- [ ] E3a `StateError` reaches Crashlytics (dev build) → Crashlytics screenshot, device/emulator note
- [ ] E3b `SocketException` → `NetworkFailure(NETWORK_OFFLINE)` → unit test name
- [ ] E4 Import-boundary check fails on a planted violation → test names + CI log excerpt

## 8. Known issues
## 9. Follow-ups for later stages
