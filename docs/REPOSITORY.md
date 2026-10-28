# Repository

## 1. Layout

```
saff/
├── CLAUDE.md
├── README.md
├── pubspec.yaml                 # pub workspace root + Melos config (scripts)
├── analysis_options.yaml        # includes very_good_analysis + project rules
├── app/                         # saff_app (Flutter application)
│   ├── lib/
│   │   ├── main_dev.dart  main_prod.dart  wake_main.dart
│   │   ├── bootstrap.dart               # shared startup: env, Firebase, error handlers, ProviderScope
│   │   ├── app.dart  router.dart
│   │   ├── config/                      # EnvironmentConfig, flavors
│   │   ├── di/                          # service + repository providers
│   │   ├── data/
│   │   │   ├── services/                # one folder per external system
│   │   │   ├── repositories/            # interface + implementation per data type
│   │   │   ├── dto/                     # Firestore/JSON shapes + mappers
│   │   │   └── local/                   # Drift database, tables, DAOs, migrations
│   │   ├── domain/                      # optional use cases
│   │   ├── features/<feature>/{views,view_models,widgets}/
│   │   ├── shared/                      # app-wide widgets that aren't design-system components
│   │   └── l10n/                        # ARB files (English first)
│   ├── android/                         # flavors, App Links, Firebase config per flavor
│   ├── ios/
│   ├── test/                            # mirrors lib/
│   └── integration_test/
├── packages/
│   ├── saff_core/
│   ├── saff_domain/
│   ├── saff_ui/
│   ├── saff_alarm/                      # plugin: lib/, pigeons/, android/, ios/
│   ├── saff_modes/
│   ├── mode_card_duel/
│   ├── mode_word/
│   ├── mode_arcade/
│   └── mode_selfie/
├── functions/                           # Cloud Functions (TypeScript)
│   ├── src/
│   │   ├── index.ts                     # exports only
│   │   ├── core/                        # errors, logging, config, firestore helpers, idempotency
│   │   ├── contracts/                   # generated from /contracts
│   │   ├── domain/                      # pure logic: round assembly, grading, stats, fsrs, normalisation
│   │   ├── features/                    # one folder per area: alarms, rounds, nudges, content, imports, account
│   │   └── triggers/                    # thin wrappers binding domain logic to triggers/tasks/callables
│   └── test/
├── firebase/
│   ├── firebase.json  .firebaserc
│   ├── firestore.rules  firestore.indexes.json  storage.rules
│   └── rules-tests/                     # @firebase/rules-unit-testing
├── contracts/
│   ├── constants.json  errors.json
│   ├── payloads/                        # JSON Schemas: push payloads, callable requests/responses
│   └── fixtures/                        # shared test vectors (grading, normalisation, rounds, imports)
├── tools/
│   ├── gen_contracts/                   # Dart script: contracts → Dart + TS
│   └── check_imports/                   # Dart script: import-boundary enforcement
├── docs/                                # this documentation, stages/, design/
└── .github/workflows/                   # ci.yml, release.yml
```

## 2. Workspace

- Root `pubspec.yaml` declares `workspace:` listing `app` and every package (no globs). Every member has
  `resolution: workspace` and `publish_to: none`. One lockfile for the whole repo.
- Melos 7 scripts live under `melos:` in the root pubspec:

| Script | Does |
|---|---|
| `generate` | `gen_contracts`, then `build_runner build -d` in packages that depend on it, then Pigeon |
| `analyze` | `dart analyze --fatal-infos` everywhere + `check_imports` |
| `format` / `format:check` | `dart format` |
| `test` | `flutter test --coverage` per package, then coverage gate |
| `test:integration` | integration tests on an emulator |
| `ci` | format:check → analyze → test → functions lint/test → rules tests |

## 3. Package dependency graph

```
saff_app ──► mode_card_duel ─┐
         ──► mode_word ──────┤
         ──► mode_arcade ────┼─► saff_modes ─► saff_ui ─► saff_core
         ──► mode_selfie ────┘        │                     ▲
         ──► saff_alarm ──────────────┼─────────────────────┤
         ──► saff_domain ─────────────┴─────────────────────┘
```
- Arrows point to allowed dependencies. Nothing points back to `saff_app`.
- `saff_core` and `saff_domain` are pure Dart (no Flutter): fast tests, reusable on the server side if
  ever needed.

## 4. Import boundaries (enforced)

`tools/check_imports` runs in CI and fails on:
- a package importing a package not listed in its allowed set (table in `ARCHITECTURE.md` §4.1);
- `app/lib/features/A/**` importing `app/lib/features/B/**`;
- a view importing anything under `data/services/`, `cloud_firestore`, `firebase_*`, `drift` or
  `saff_alarm` directly;
- `src/` code of a package importing another package's `src/` (only public library files).

## 5. Naming and code conventions

- Files `snake_case.dart`; one public class per file where practical.
- Suffixes: `...View`, `...ViewModel`, `...State`, `...Repository` (interface), `...RepositoryImpl`,
  `...Service`, `...Dto`, `...Mapper`, `...Failure`.
- Packages export through one library file (`lib/saff_ui.dart`); implementation in `lib/src/`.
- Prefer `final` and immutable data; `freezed` for models and states; sealed classes for closed sets.
- Async: never ignore a `Future` (`unawaited` with a comment if intentional).
- Strings shown to users come from ARB files. No inline user-facing strings.
- Time: always via `Clock` (injectable). Store UTC; convert at the edges.
- Ids: Firestore auto-ids unless the doc must be idempotent (then deterministic, see `DATA_MODEL.md`).

## 6. Environments

| Flavor | Firebase project | Use |
|---|---|---|
| `dev` | `saff-dev` | Development, emulators optional |
| `prod` | `saff-prod` | Play Store builds |

- Config via `--dart-define-from-file=env/<flavor>.json` (gitignored; `env/example.json` committed).
- `EnvironmentConfig` exposes: flavor, content gateway base URL, packs index URL, emulator flag, log level.
- Emulator mode (`USE_EMULATORS=true`) points Auth/Firestore/Functions/Storage at local emulators on
  `EMULATOR_HOST` (default `127.0.0.1`; the laptop's LAN IP for physical phones). Dev-only switches such as
  `DEMO_TIMING` are listed in `DEV_RELAXATIONS.md`; the prod entrypoint ignores them.

## 7. Git workflow

- `main` is always releasable. Work happens on `stage/NN-name` branches (`CLAUDE.md` §2), merged by PR.
- Conventional Commits. Squash-merge per stage, or merge commits for long stages with clean history.
- PR template: stage file link, exit criteria checklist, screenshots, test evidence, docs updated.

## 8. CI (`.github/workflows/ci.yml`)

On every PR and push to `main`:
1. Setup Flutter (pinned version in `.fvmrc` or workflow), Node LTS, Java for emulators.
2. `melos bootstrap`, `melos run generate`, fail if generated files differ from committed ones.
3. `melos run format:check`, `melos run analyze`.
4. `melos run test` with coverage gates (`TESTING.md` §6).
5. `functions`: `npm ci`, lint, typecheck, unit tests, emulator integration tests.
6. Rules tests against the emulator.
7. Build a debug APK for `dev`.

`release.yml` (manual or tag): build signed `prod` app bundle, upload Crashlytics symbols, upload to
Play internal testing; deploy functions/rules/indexes to `saff-prod` after approval.

## 9. Dependency hygiene

- Renovate (or Dependabot) weekly, grouped by ecosystem.
- New dependencies recorded in the stage file with reason, alternatives, licence and maintenance status.
- Pin the Flutter SDK version for the whole team and CI.
