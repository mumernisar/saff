# Two-phone demo

How to run a real morning on two (or three) physical Android phones while `saff-dev` is on the Spark plan
and the backend runs in the Firebase emulators on a laptop. Everything here that bends a rule is listed in
`DEV_RELAXATIONS.md`; this file only explains how to use it.

Parts become available as stages land; the "From" column says which stage enables each step.

---

## 1. What you need

- A laptop (macOS) with the toolchain from `REPOSITORY.md` and the Firebase CLI. It runs the emulators.
- Two Android phones (a third for the group demo), with automatic date and time on, on the **same Wi-Fi**
  as the laptop (no guest network or client isolation), or connected over USB.
- The `saff-dev` Firebase project (Spark is fine). The phones use it for real FCM tokens and Crashlytics;
  everything else goes to the emulators.
- A dev build of the app installed on each phone.

## 2. One-time setup

1. **FCM key for the emulator** (R-5). In Google Cloud for `saff-dev`, create a service account with only
   the *Firebase Cloud Messaging API Admin* role and a JSON key. Save it as `env/saff-dev-fcm-key.json`
   (gitignored). Never commit it; delete it in IAM when you no longer need it.
2. **`functions/.env.local`** (read only by the Functions emulator):
   ```
   DEMO_TIMING=true
   GOOGLE_APPLICATION_CREDENTIALS=../env/saff-dev-fcm-key.json
   ```
   Quran Foundation credentials, if you need real content, go in `functions/.secret.local` (R-6).
3. **`env/dev.json`** (copy from `env/example.json`):
   ```json
   { "USE_EMULATORS": true, "EMULATOR_HOST": "192.168.1.20", "DEMO_TIMING": true }
   ```
   `EMULATOR_HOST` is the laptop's LAN IP (`ipconfig getifaddr en0`), or `127.0.0.1` when using USB.
4. **macOS firewall:** allow incoming connections for `java` and `node` (the emulators), or the phones
   can't reach them.
5. **On each phone:** allow notifications, alarms and full-screen alerts, and exempt Saff from battery
   optimisation (`ALARM.md` §7), or the alarm and the pushes may be delayed.

## 3. Each session

| Step | Command | From |
|---|---|---|
| Find the LAN IP and update `env/dev.json` if it changed | `ipconfig getifaddr en0` | Stage 0 |
| Start the emulators (bound to `0.0.0.0`, data kept between sessions) | `cd firebase && firebase emulators:start --import ../.emulator-data --export-on-exit` | Stage 0 |
| USB instead of Wi-Fi: forward the ports to every connected phone | `tools/demo/adb_reverse.sh` | Stage 0 |
| Seed the test users, and a pair saff (or a group with Sara) | `tools/demo/seed --with-saff` / `--with-group` | Stage 3 |
| Install and run on each phone | `cd app && flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=../env/dev.json -d <device-id>` | Stage 0 |
| Sign in: phone A "Hamza", phone B "Ali" (phone C "Sara") | "Sign in as test user" (R-2) | Stage 3 |

**Ports** the phones use: Auth 9099, Firestore 8080, Functions 5001, Storage 9199, Hosting (content
gateway) 5002. The laptop also uses the Emulator UI 4000, Pub/Sub 8085 and Cloud Tasks 9499. Hosting is
moved off 5000 because macOS uses that port for AirPlay.

## 4. Demo script

Demo timing is on (R-1): night lock 1 min before the alarm, offline check 30 s after, reveal deadline
5 min after, nudges every 20 s. T = the alarm time.

| When | Phone A (Hamza) | Phone B (Ali) | From |
|---|---|---|---|
| T − 5 min | In the pair chat: **+ → Propose an alarm** a few minutes ahead (name "Demo", today). | Accepts the proposal card. The alarm becomes active on both phones. | Stage 4 |
| T − 1 min | Round locks; the "round locked" push arrives (real FCM from the emulator) and the round downloads. Lock the phone. | Same. Lock the phone. | Stage 5 |
| T | Rings full screen over the lock screen. Starts and plays the round. | Rings. Leave it ringing. | Stage 1, 6 |
| T + ~1 min | Waiting screen: **Ring Ali again**. | Re-rings with "Hamza rang you again" (real FCM nudge). | Stage 7 |
| T + ~1.5 min | Rings again after 20 s (up to 3 times). | | Stage 7 |
| T + 2–5 min | | Plays the round. | Stage 6 |
| Reveal | Both results reveal together; card review; the chat opens with the result card. | Same. | Stage 6 |

**Variants**
- **Missed:** phone B never plays. At T + 5 min the deadline reveal shows Ali as missed. (Stage 7)
- **Offline:** put phone B in airplane mode before T. It still rings and plays the arcade fallback; at
  T + 30 s phone A shows "Ali's phone seems to be offline" with WhatsApp as the main action. When phone B
  reconnects, its result uploads. (Stage 7)
- **Group:** seed with `--with-group`, sign phone C in as Sara. A group alarm starts once 2 people accept;
  it rings only for those who accepted. (Stage 4, 6)
- **Another round:** propose a new alarm a few minutes ahead; there is no "ring now" button.

## 5. Troubleshooting

| Symptom | Check |
|---|---|
| App can't reach the backend | Same Wi-Fi? `EMULATOR_HOST` still the laptop's current IP? Firewall allows `java`/`node`? Emulators show `0.0.0.0` in the startup table? Or use USB + `adb reverse`. |
| No pushes | `GOOGLE_APPLICATION_CREDENTIALS` set in `functions/.env.local`? The phone registered a token (Emulator UI → Firestore → `users/{uid}/devices`)? Notifications allowed? |
| Alarm late or silent | Battery optimisation exemption, full-screen permission, phone time on automatic (the laptop's clock decides `ringAt`). |
| Old data in the way | Stop the emulators, delete `.emulator-data/`, start again and re-seed. |

## 6. Limits of this setup

- Nothing is deployed: Functions, task queues and Storage run only on the laptop. If the laptop sleeps,
  locks, reveals and nudges stop (alarms already scheduled on the phones still ring).
- App Check isn't enforced (R-7), and there's no billing cap to test while on Spark (R-8).
