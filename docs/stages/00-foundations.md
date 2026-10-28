# Stage 00: Foundations

Branch: `stage/00-foundations` · Started: 2026-10-28 · Finished: YYYY-MM-DD

## 1. Starting point
What exists right now, verified by reading the code and running it (not copied from older notes):
- Packages and their state: **none.** No application code yet.
- Repository: `saff-docs/` (it holds `CLAUDE.md`) is the repo root `REPOSITORY.md` describes. Git was
  initialised on 2026-10-28: `main` has the imported docs; `stage/00-foundations` has the docs work of
  this stage so far (see §3). No remote yet. Next to the repo, outside git: `saff-mobile-app-prototype/`
  (the original Claude Design bundle) and `saff-cards/packs/duha-packs/` (the packs repository, its own
  git repo, `dist/index.json` built 2026-10-18).
- Screens and features working: none.
- Server functions deployed / in emulators: none. `saff-dev` is to stay on the **Spark** plan for now, with
  Functions, task queues and Storage run in the emulators (`DEV_RELAXATIONS.md` R-8). The Firebase projects exist:
  `saff-dev-d9605` and `saff-prod`.
- Tests and coverage: none.
- Toolchain on this machine (checked 2026-10-28, before installs): git 2.50.1, Homebrew, Node v24.18.0 + npm,
  OpenJDK 25. Nothing else; the installs are recorded in §3.
- Known issues carried in: the gaps and contradictions in `docs/design/flows.md` §3–5. For this stage:
  D-1 and D-3 are resolved; D-2 (mappers vs. a pure-Dart `saff_core`) is resolved: mappers outside pure Dart live in the app. The mockup
  contradictions don't block Stage 0 (the shell only needs the four tabs, which docs and mockups agree
  on: Today, Chat, Learn, Stats).

## 2. Plan
What this stage will build, in order, mapped to the exit criteria in `STAGES.md`.

Exit criteria (from `STAGES.md`):
- **E1** `melos run ci` green in GitHub Actions.
- **E2** Generated contracts identical in Dart and TS (a test compares both against `contracts/`).
- **E3** A deliberate thrown `StateError` reaches Crashlytics in a dev build; a mapped `SocketException`
  becomes `NetworkFailure(NETWORK_OFFLINE)` (unit test).
- **E4** Import-boundary check fails on a planted violation.
- **E5** A simulated budget message disables billing on `saff-dev`. *(Needs `saff-dev` on Blaze; see the
  open question in step 10.)*
- **E6** A dev build on a physical phone reaches the laptop's emulators over Wi-Fi and over USB.

Steps:

0. **Prerequisites.**
   - Install (approved; **done first, before any other Stage 0 work**): FVM + a pinned Flutter stable (`.fvmrc`, also used by CI), Melos 7,
     Node 22 LTS for Functions (`.nvmrc`; the machine has Node 24), JDK 21 for the emulators, Android SDK
     + platform tools (`adb`), Firebase CLI, FlutterFire CLI, GitHub CLI. Each recorded in §5.
   - Owner: Firebase projects `saff-dev-d9605` (dev) and `saff-prod` (both Spark for now; Android app IDs `app.saff.dev` / `app.saff`), Crashlytics enabled in
     `saff-dev`, a GitHub repository for CI.
1. **Workspace** (→ E1). Root `pubspec.yaml` with `workspace:` listing `app` and every package, Melos
   scripts (`generate`, `analyze`, `format`, `format:check`, `test`, `test:integration`, `ci`),
   `analysis_options.yaml` on `very_good_analysis`, the rest of `.gitignore`, root `README.md`.
2. **Package shells** (→ E1, E4). `saff_core`, `saff_domain` (pure Dart); `saff_ui`, `saff_alarm`
   (plugin shell, Android only, no Pigeon yet), `saff_modes`, `mode_card_duel`, `mode_word`,
   `mode_arcade`, `mode_selfie`. Each: one library file + `lib/src/`, `resolution: workspace`,
   `publish_to: none`, dependencies exactly as ARCHITECTURE §4.1, a smoke test.
3. **Contracts and generator** (→ E2). `contracts/constants.json` (every constant in PRODUCT §14, with
   free/plus limit values), `contracts/constants.demo.json` (the demo timings only: R-1 and R-P1–R-P3),
   `contracts/errors.json` (the full catalog in ERRORS §5, including `INVALID_ARGUMENT` and
   `BACKEND_DISABLED`; each code with kind, severity, retryable, httpsCode, messageKey, description), empty
   `contracts/payloads/` and `contracts/fixtures/`. `tools/gen_contracts` (Dart) writes `FailureCode` into
   `saff_core`, the constants (and the demo overlay) into `saff_domain`, `functions/src/contracts/` in
   TypeScript, and English ARB entries for every `messageKey`. Contract tests on both sides load
   `contracts/*.json` and assert every code / constant and field matches the generated output; CI also
   regenerates and fails on any diff. A test proves the prod configuration ignores the demo overlay.
4. **Import-boundary check** (→ E4). `tools/check_imports` (Dart) enforcing REPOSITORY §4: the package
   allow-list from ARCHITECTURE §4.1, feature → feature imports, views importing services /
   `cloud_firestore` / `firebase_*` / `drift` / `saff_alarm`, and `src/` reach-ins. Tests run it on
   fixture trees with one planted violation of each kind and assert a non-zero exit and a clear message.
5. **`saff_core`** (→ E3, coverage ≥ 90%). `Result` (`Ok`/`Err`, `map`, `flatMap`, `fold`, `getOrNull`,
   `Result.guard`), the sealed `AppFailure` hierarchy with `FailureSeverity` and `DeviceFix`,
   `ExceptionMapper` + `FailureMapper`, `Log` with key redaction, `Clock`, and the retry helper (full
   jitter, base 500 ms, factor 2, cap 30 s, 4 / 6 attempts) tested with a fake clock. Unit test:
   `SocketException` → `NetworkFailure(NETWORK_OFFLINE)`. Where the Firebase / Platform / Drift / HTTP
   mappers: only the pure-Dart ones (`AppFailure`, `Network`, `HttpStatus`, `Format`) live here; the rest go in `app/lib/data/errors/` and `saff_alarm` exports its own (D-2 resolved).
6. **App shell** (→ E1, E3, E6). Android flavors `dev` / `prod`, `main_dev.dart` / `main_prod.dart`,
   `EnvironmentConfig.fromDefines()` with `USE_EMULATORS`, `EMULATOR_HOST` and `DEMO_TIMING` (dev only),
   `env/example.json`; the dev flavor's network security config allows cleartext to the emulators (R-4),
   prod doesn't. `bootstrap.dart`: Firebase init per flavor, emulator wiring, App Check (debug provider in
   dev, Play Integrity in prod), Crashlytics, `FlutterError.onError`, `PlatformDispatcher.instance.onError`,
   release `ErrorWidget.builder`, a logging `ProviderObserver`, `ProviderScope` with retry limited to
   retryable failures. `go_router` shell with the 4 tabs (Today, Chat, Learn, Stats) as placeholder views
   and a pushed Settings route; ARB l10n set up. For E3, a dev-flavor-only crash trigger that throws a
   `StateError` (listed in `DEV_RELAXATIONS.md` before it's built); evidence = the Crashlytics issue in
   `saff-dev`. For E6, the Today placeholder shows whether the emulators are reachable.
7. **Firebase wiring and emulators** (→ E1, E6). `firebase/firebase.json` with every emulator bound to
   `0.0.0.0` (Hosting on 5002, not 5000), `.firebaserc` (dev, prod), `firestore.rules` and `storage.rules`
   that deny everything, empty `firestore.indexes.json`. `flutterfire configure` per flavor (options files
   committed, as SECURITY §4 allows). Auth, Firestore, Functions, Storage, FCM, App Check and Crashlytics
   plugins added and initialised (no feature use yet). `firebase/rules-tests/` with
   `@firebase/rules-unit-testing`: deny-all cases for Firestore and Storage; `npm run test:rules`.
   `tools/demo/adb_reverse.sh` forwards the emulator ports to every connected phone.
8. **Functions skeleton** (→ E1, E2). `functions/` TypeScript strict, Node 22, `firebase-functions` v2,
   `firebase-admin`, `zod`; `src/index.ts` exports only; `core/errors` (`AppError` from the generated
   catalog, conversion to `HttpsError` with `details.code`), `core/logger` (structured, with `requestId`),
   `core/idempotency` (`requests/{requestId}`, 24 h `expiresAt`, transaction), and a config switch that
   reads `DEMO_TIMING` from `functions/.env.local` (emulator only). Lint, typecheck, `vitest` unit tests,
   an emulator test that the idempotency helper returns the stored response when run twice.
9. **Cost protection** (→ E5). `capBilling` (Pub/Sub, topic `billing-budget`) per ARCHITECTURE §9a: write
   `config/backend.status = 'billingDisabled'`, then unlink billing via the Cloud Billing API; no-op under
   the cap or when already disabled. Unit tests with a fake billing client (under cap, over cap, already
   disabled, repeated message); an emulator test publishing a sample budget message. Rules allow signed-in
   reads of `config/backend`. Console steps (budget with $1 / $5 thresholds, Pub/Sub topic, Billing API,
   service-account role) written into §3 for both projects.
10. **CI and close.** `.github/workflows/ci.yml` per REPOSITORY §8: pinned Flutter, Node, Java;
    bootstrap; generate + fail on diff; format check; analyze (+ `check_imports`); tests with the coverage
    gates of TESTING §6; functions lint/typecheck/tests with emulators; rules tests; dev debug APK. Run
    `melos run ci` locally, push, get a green run (→ E1). Fill §3–9, update docs for decisions made here,
    record every dependency in §5, ask for review.
    **E5 (decided):** on Spark, `saff-dev` has no billing account, so `capBilling` can't be deployed. Stage 0
    proves it with unit and emulator tests; the real simulated-message test runs on `saff-dev` when it moves
    to Blaze at the **start of Stage 5** (STAGES Stage 5).

Approved by owner on: 2026-10-29

## 3. What was done
**Docs (before any code):**
- Repo initialised at `saff-docs/`; `.gitignore` for env files, local credentials and emulator data.
- `docs/design/flows.md`: mockup inventory, clickable flows, gaps, contradictions. The prototype's design
  files copied into `docs/design/source/`.
- D-1: `mode_selfie` added to `REPOSITORY.md`. D-3: `INVALID_ARGUMENT` added to the catalog.
- Flutter recorded as a hard requirement (ARCHITECTURE D1, OPEN_QUESTIONS).
- Cost protection: budget alerts + `capBilling` (STAGES Stage 0, ARCHITECTURE §9a, BACKEND, DATA_MODEL
  `config/backend`, ERRORS §7a and the `BACKEND_DISABLED` code).
- Owner answers applied (2026-10-28): mappers split between `saff_core` and the app (D-2); E5 split into
  Stage 0 tests + a real run at the start of Stage 5; all four demo shortcuts R-P1–R-P4 approved and moved
  into the main table of `DEV_RELAXATIONS.md`; chat stays up when billing is disabled (notifications paused,
  sweeper reconciles).
- Toolchain installed first (owner's instruction): FVM, Flutter 3.47.8, Node 22, GitHub CLI, Firebase CLI,
  JDK 21 (Zulu), Android SDK 36 + licenses. Firebase projects exist: `saff-dev-d9605` (no. 953758325356),
  `saff-prod` (no. 971274012156).
- Two-phone demos: `DEMO.md`, `DEV_RELAXATIONS.md`, demo items folded into Stages 0, 3, 5, 7 and 14,
  plus `README.md`, `REPOSITORY.md` §6, `PRODUCT.md` §14 and a rule in `CLAUDE.md`.

## 4. Decisions and why
| Decision | Alternatives considered | Why this one |
|---|---|---|
| Repo root is `saff-docs/` (not renamed) | Rename to `saff/`; new folder | It already holds `CLAUDE.md`, as `REPOSITORY.md` expects; renaming can happen any time without touching history. |
| Copy only the prototype's HTML + runtime into `docs/design/source/` | Copy the whole bundle; reference it outside the repo | The mockups are the visual source of truth and belong in the repo; the wallpaper images aren't ours to redistribute, and the unused "Organic" system waits on C-14. |
| No debug menu; demo shortcuts come from relaxed timings, listed in `DEV_RELAXATIONS.md` | A dev-only debug menu (lock now, ring now, force reveal, test nudge) | Owner's instruction: relax rules instead and keep a single revert list for prod. |
| `saff_core` stays pure Dart; Firebase / Platform / Drift mappers in `app/lib/data/errors/`, `saff_alarm` exports its own | Keep all mappers in `saff_core` and allow it Firebase deps; a separate `saff_mappers` package | Owner's decision: keeps the core dependency-free and testable; mappers sit next to the services whose exceptions they map. |
| Billing cap writes `config/backend` before unlinking billing; new code `BACKEND_DISABLED` | Let clients infer the outage from failing callables | Firestore stays readable on Spark limits, so one status document tells every client clearly; failing callables look like ordinary network errors. |

## 5. Dependencies added
| Package | Version | Licence | Why | Alternatives |
|---|---|---|---|---|
| *Tooling (machine, not in the repo):* | | | | |
| FVM | 4.3.2 | MIT | Pin Flutter per repo (`.fvmrc`), same in CI | Manual SDK install |
| Flutter / Dart | 3.47.8 / 3.13.7 | BSD-3 | App framework (hard requirement, ARCHITECTURE D1) | none |
| Melos | 8.10.0 (docs said "7"; latest stable installed) | MIT | Workspace scripts | plain scripts |
| FlutterFire CLI | 1.4.1 | BSD-3 | `flutterfire configure` per flavor | manual config |
| Node | 22.23.4 (keg-only `node@22`) | MIT | Functions runtime (`.nvmrc` 22) | Node 24 (not supported by Functions) |
| Firebase CLI | 15.34.1 | MIT | Emulators, deploy | none |
| GitHub CLI | 2.103.3 | MIT | Repo and CI | web UI |
| JDK (Zulu) | 21 | GPLv2+CE | Gradle and Firebase emulators (Temurin 25 too new) | Temurin 21 |
| Android SDK | platform 36, build-tools 36.0.0, platform-tools, emulator, arm64 `google_apis` image | Android SDK terms | Android builds and emulator | Android Studio |
| *Dart (app):* | | | | |
| `firebase_core` / `firebase_auth` / `cloud_firestore` / `cloud_functions` / `firebase_storage` / `firebase_messaging` / `firebase_app_check` / `firebase_crashlytics` | 5.1 / 7.0 / 7.1 / 7.0 / 14.0 / 17.0 / 0.5 / 6.0 | BSD-3 | FlutterFire, chosen in ARCHITECTURE §10 | none |
| `flutter_riverpod` | 3.4 | MIT | State and DI (ARCHITECTURE §10); no codegen in the shell | Provider, Bloc |
| `go_router` | 18.1 | BSD-3 | Navigation | auto_route |
| `intl`, `flutter_localizations` | SDK-pinned | BSD-3 | ARB localisation | slang |
| `very_good_analysis` | 10.x | MIT | Lint set (ARCHITECTURE §10) | flutter_lints |
| `melos` | 8.10 | MIT | Workspace scripts | none |
| *Functions:* | | | | |
| `firebase-functions` / `firebase-admin` | 6 / 13 | MIT / Apache-2 | Functions v2 and Admin SDK | none |
| `@google-cloud/billing` | 5 | Apache-2 | `capBilling` unlinks billing | raw REST call |
| `zod` | 3 | MIT | Input validation (BACKEND §1); not used yet | valibot |
| `typescript`, `eslint`, `typescript-eslint` | 5 / 9 / 8 | Apache-2 / MIT | Typecheck and lint | none |
| *Rules tests:* | | | | |
| `@firebase/rules-unit-testing`, `firebase`, `vitest` | 5 / 12 / 3 | Apache-2 / MIT | Rules tests against the emulator | jest |

## 6. Deviations from the docs
- **No new tests (owner's instruction, 2026-10-29):** "dont write any tests whatsoever, focus on finishing the
  functionality of the whole app, we'll go towards test later." From the end of step 7 on, nothing new is
  tested; tests written before that stay. This breaks `CLAUDE.md` (tests per layer, every bug fix starts with
  a failing test) and leaves these exit criteria unproven until the owner re-enables testing: E1 (coverage
  gates), the Functions unit/emulator tests of steps 8-9 and the E5 tests, and E4 beyond the existing
  import-check tests. Tracked in §8.
## 7. Evidence of exit criteria
- [ ] E1 `melos run ci` green in GitHub Actions → link to the run
- [ ] E2 Generated contracts identical in Dart and TS → contract test names (Dart + TS), CI diff step
- [ ] E3a `StateError` reaches Crashlytics (dev build) → Crashlytics screenshot, device note
- [ ] E3b `SocketException` → `NetworkFailure(NETWORK_OFFLINE)` → unit test name
- [ ] E4 Import-boundary check fails on a planted violation → test names + CI log excerpt
- [ ] E5 Simulated budget message disables billing on `saff-dev` → test names; real run when on Blaze
- [ ] E6 Physical phone reaches the emulators over Wi-Fi and over USB → device notes / screenshots

## 8. Known issues
- Steps 8-10 (Functions skeleton, `capBilling`, CI) have no tests by the owner's instruction (§6); E5 and the
  Functions coverage gates are open until testing resumes.
## 9. Follow-ups for later stages
Demo work folded into later stages (see `STAGES.md`, `DEMO.md`, `DEV_RELAXATIONS.md`); copy these into
each stage file at its start:
- **Stage 3:** "Sign in as test user" (Hamza, Ali, Sara) and `tools/demo/seed` (users; `--with-saff`,
  `--with-group`). Exit: two physical phones sign in as seeded users and see the same saff.
- **Stage 4:** implement the approved relaxations R-P1–R-P4 (conflict window, skip notice, snooze,
  1-minute picker) behind the demo-timing profile; prove prod ignores them.
- **Stage 5:** first, move `saff-dev` to Blaze and run the real E5 budget-message test. Then: server applies demo timing in the emulator; real FCM `roundLocked` pushes from the
  Functions emulator with the local key. Exit: push arrives on two phones 1 min before the alarm.
- **Stage 7:** nudges via real FCM from the emulator, 20 s interval; the full `DEMO.md` script end to end.
- **Stage 14:** revert or prove absent every row of `DEV_RELAXATIONS.md`.
- **Before Stage 1/2:** owner decisions on C-1 (start gesture) and C-14 (visual system), `flows.md`.
