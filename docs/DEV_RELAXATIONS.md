# Dev relaxations

Rules from the other docs that are **relaxed for development and demos** (Spark plan, Firebase emulators,
physical phones). This is the revert list: before a prod build, every row here is reverted or proven
absent from the prod build (Stage 14). Add a row **before** relaxing anything else; a relaxation that
isn't listed here is a bug.

There is deliberately **no debug menu**. The shortcuts a menu would give (lock a round now, ring now,
force a reveal, send a test nudge) come from the timings below: a demo alarm proposed a few minutes ahead
locks 1 minute before, rings on time, reveals 5 minutes after, and nudges can be resent every 20 seconds.

## How relaxations are gated

Each one is switched on by at least one of:
- **dev flavor**: code that exists only behind `EnvironmentConfig.flavor == dev` (the `prod` entrypoint
  never reads the switch);
- **emulators**: `USE_EMULATORS=true` in `env/dev.json`, or an emulator-only file (`functions/.env.local`
  and `functions/.secret.local` are read only by the Functions emulator);
- **local files**: gitignored files on the developer's laptop (`env/*.json`, `.emulator-data/`).

## The list

| # | Relaxed rule (where the real rule lives) | Dev / demo behaviour | Gate | Revert for prod |
|---|---|---|---|---|
| R-1 | Timing constants (`PRODUCT.md` §14): `NIGHT_LOCK_LEAD` 60 min, `REVEAL_DEADLINE` 30 min, `NUDGE_INTERVAL` 2 min, `OFFLINE_CHECK_DELAY` 2 min | **Demo timing:** night lock 1 min before, reveal deadline 5 min after, nudge interval 20 s, offline check 30 s. Values in `contracts/constants.demo.json`, generated next to the real constants. The server applies them only when `DEMO_TIMING=true` in `functions/.env.local`; the app shows matching countdowns only in the dev flavor with `DEMO_TIMING=true` in `env/dev.json`. | emulators + dev flavor | Delete `constants.demo.json` and the overlay code, or prove `prod` ignores it (test: prod config with `DEMO_TIMING=true` still yields 60 min / 30 min / 2 min / 2 min). |
| R-2 | Sign-in is Google or email link only (`PRODUCT.md` §2) | **"Sign in as test user"** on the sign-in screen: seeded email/password accounts Hamza, Ali and Sara in the Auth emulator. | dev flavor + emulators | Remove the button and the email/password provider use; check the prod APK has no test-account strings. |
| R-3 | Saffs, members and users are created only through callables (`BACKEND.md` §2, `SECURITY.md` §1) | **Seed script** `tools/demo/seed` writes users and, with `--with-saff` / `--with-group`, a pair saff (Hamza + Ali) or a group (+ Sara) straight into the emulator with the Admin SDK. Refuses to run unless `FIRESTORE_EMULATOR_HOST` is set. | emulators | Nothing ships; keep the emulator-only guard and its test. |
| R-4 | All traffic is TLS to Google endpoints | Phones talk plain HTTP to the laptop's emulators at `EMULATOR_HOST` (the laptop's LAN IP, or `127.0.0.1` with `adb reverse` over USB). Emulators bind to `0.0.0.0`. The dev flavor's Android network security config allows cleartext. | dev flavor + emulators | Prod flavor has no cleartext permission (checked in the merged manifest) and no `EMULATOR_HOST`. |
| R-5 | Server code runs as the deployed function's service account; no key files (`SECURITY.md` §4) | The Functions emulator sends **real FCM pushes** (`roundLocked`, `nudge`) to the phones using a local service-account key for `saff-dev` with only the Firebase Cloud Messaging API Admin role, stored at `env/saff-dev-fcm-key.json` (gitignored) and pointed to by `GOOGLE_APPLICATION_CREDENTIALS` in `functions/.env.local`. | local files + emulators | Delete the key file **and** the key in Google Cloud IAM; prod never uses key files. |
| R-6 | Quran Foundation credentials come from Secret Manager (`BACKEND.md` §1) | The content gateway in the emulator reads them from `functions/.secret.local` (gitignored). | emulators | Nothing ships; prod uses `defineSecret`. |
| R-7 | App Check enforced on Firestore, Storage, Functions (`SECURITY.md` §3) | Not enforced by the emulators; the dev flavor uses the debug provider. | emulators + dev flavor | Prod uses Play Integrity and enforcement is on in the console. |
| R-8 | Functions, task queues, Storage and the billing cap run on Blaze (`ARCHITECTURE.md` §9a) | While `saff-dev` is on **Spark**, they run only in the emulators; nothing is deployed and there's no billing to cap. FCM, Auth and Crashlytics use the real `saff-dev` project. | project plan | Move to Blaze, deploy, set up the budget and `capBilling`. |
| R-9 | Data lives in Firestore | Emulator data persists between sessions in `.emulator-data/` (`--import` / `--export-on-exit`), gitignored. | local files | Nothing ships. |
| R-10 | Crash reports are sent from release builds only (`ERRORS.md` §8) | The dev flavor reports to Crashlytics in every build mode, and has a **"Trigger test crash"** tile in Settings that throws a `StateError` (Stage 0 exit criterion E3). | dev flavor | `prod` has no tile and reports only in release (test: the prod router/settings contain no crash tile; `reportToCrashlytics` is false in debug for prod). |
| R-11 | Timed server work runs from Cloud Tasks and a Scheduler sweeper on Blaze (`ARCHITECTURE.md` D8) | The Scheduler does not run in the emulator; `tools/demo/ticker.sh` calls the `tick` function every 10 s. `tick` returns 404 outside the Functions emulator. | emulators | Nothing ships; the deployed `sweeper` (every minute) does the same work. |
| R-12 | Anki import and packs by link need Saff Plus (`PRODUCT.md` §15) | `DEV_PLUS=true` in `functions/.env.local` lets any user import in the Functions emulator (ignored when deployed). | emulators | Delete the flag; entitlement `limits.imports` decides. |
| R-P1 | `ALARM_CONFLICT_WINDOW` 30 min (`PRODUCT.md` §14) | **2 min** in the demo-timing profile, so several demo alarms fit within half an hour. | emulators + dev flavor (`DEMO_TIMING`) | Same as R-1: value only in `constants.demo.json`; the prod test asserts 30 min. |
| R-P2 | `SKIP_MIN_NOTICE` 8 h | **2 min**, to demo skipping a morning. | emulators + dev flavor (`DEMO_TIMING`) | Same as R-1 (prod test asserts 8 h). |
| R-P3 | `SNOOZE_DURATION` 5 min | **1 min**, to demo a snooze without a 5-minute wait. | emulators + dev flavor (`DEMO_TIMING`) | Same as R-1 (prod test asserts 5 min). |
| R-P4 | Alarm time picker steps by 5 min (mockup 6h) | **Steps by 1 min**, to propose an alarm 3–4 minutes ahead. | dev flavor (`DEMO_TIMING`) | The prod build keeps the 5-minute step (test on the picker config). |

## Not relaxations (dev tooling only)
- `tools/demo/adb_reverse.sh`: forwards the emulator ports over USB for every connected phone.
- `docs/DEMO.md`: the two-phone setup and demo script.
