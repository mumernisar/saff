# Testing

## 1. Test kinds per layer

| Layer | Test kind | Tools | What to cover |
|---|---|---|---|
| `saff_core` | Unit | `test` | `Result` helpers, every `ExceptionMapper`, retry/backoff (with fake clock) |
| `saff_domain` | Unit | `test` | Models' JSON round-trips, placeholder parser, constants |
| Services | Unit (thin) | `mocktail` | DTO mapping; exceptions propagate unchanged |
| Repositories | Unit | `mocktail`, fakes | Success, every failure path → correct `AppFailure`, caching, retry, idempotency |
| ViewModels | Unit | `ProviderContainer.test()` with overrides | Initial state, each action's success/failure states, streams |
| Views / components | Widget + golden | `flutter_test`, golden files | Every state (loading, empty, error, data), light/dark, text scale 1.0 and 1.3 |
| `saff_ui` | Golden | | Every component state from the mockups |
| Modes | Widget + unit | Flame test utils for arcade | Deterministic seeds, scoring callbacks, timeouts |
| Navigation | Widget | | Redirects, deep links |
| Drift | Unit | in-memory Drift | DAOs, migrations (schema dumps for every version) |
| Integration (app) | `integration_test` on emulator + Firebase emulators | | Onboarding → saff → proposal → round → reveal, offline round |
| Functions domain | Unit | `vitest`/`jest` | Round assembly, grading, normalisation, stats, FSRS mapping, occurrence planning (DST cases), Anki parsing |
| Functions triggers/callables | Integration | Firebase Emulator Suite | Idempotency (run twice), validation errors, transactions |
| Security rules | Rules tests | `@firebase/rules-unit-testing` | Allow and deny for every collection and role, including selfie images before/after reveal |
| Alarm module | Kotlin unit + instrumented + manual device checklist | JUnit, Robolectric, `ALARM.md` §9 | Scheduler math, reschedule triggers, fallback |

## 2. Shared fixtures (`contracts/fixtures/`)
- `normalisation.json`: answer → accepted? cases (English, transliteration, Arabic diacritics, typos).
- `grading/*.json`: round + results → expected grades and ranks (ties, missed, offline fallback, excluded cards).
- `proposals/*.json`: pair and group votes → expected alarm state and participants.
- `conflicts/*.json`: alarm pairs (same and different timezones, DST) → conflict or not.
- `learning-duel/*.json`: per-member cards and accuracy ranking; `solo/*.json`: one-participant mornings.
- `entitlements/*.json`: Play subscription states and dates → expected entitlement, limits and saff `overLimit`.
- `rounds/*.json`: saff state → expected locked round (seeded).
- `occurrences/*.json`: alarm + timezone + date range → expected `ringAt`s (including DST transitions).
- `imports/`: small `.apkg` files of each format, plain-text exports, a decoy-only file, a cloze deck,
  a media-only deck; with expected output.
- `payloads/`: valid and invalid push payloads and callable bodies.
Both Dart and TypeScript tests load the fixtures that apply to them.

## 3. Firebase emulators
`firebase emulators:exec` runs functions integration tests, rules tests and app integration tests in CI.
Seed scripts create a saff with members, alarms and packs.

## 4. Device matrix (manual, recorded in stage files)
Alarm checklist (`ALARM.md` §9) on Samsung, Xiaomi, Oppo/Realme/Vivo, Pixel/stock. Also: low-end device
(2–3 GB RAM) for wake-flow startup time and game frame rate.

## 5. Performance budgets (checked in Stage 12, monitored after)
| Metric | Budget |
|---|---|
| Sound starts after alarm fires | < 500 ms |
| Wake UI visible after alarm fires | < 1.5 s (mid-range device) |
| Cold start to Today screen | < 2 s |
| Arcade frame rate | 60 fps, no frame > 32 ms in a 60 s run |
| App size (download) | < 40 MB |

## 6. CI gates
| Scope | Line coverage |
|---|---|
| `saff_core`, `saff_domain`, functions `domain/` | ≥ 90% |
| Repositories and ViewModels | ≥ 80% |
| Whole app | ≥ 65% |
Plus: zero analyzer issues, format clean, import boundaries clean, generated files up to date, all
rules tests pass.
