# Saff

An alarm app where a small group (a *saff*) wakes up together into a short duel and a conversation.
Read `CLAUDE.md` first, then `docs/README.md`.

## Setup (once)
- Flutter via FVM (`.fvmrc`), Node 22 (`.nvmrc`), JDK 21, Android SDK, Firebase CLI, Melos.
- `flutter pub get` at the root (workspace), `cd functions && npm install`,
  `cd firebase/rules-tests && npm install`.
- Copy `env/example.json` to `env/dev.json` and set `EMULATOR_HOST` to your laptop's LAN IP
  (or `127.0.0.1` with `tools/demo/adb_reverse.sh` over USB).

## Everyday commands
```
melos run generate       # contracts -> Dart, TypeScript, ARB
melos run analyze        # analyzer + import boundaries
melos run test           # Dart tests
npm run emulators        # Firebase emulators (bound to 0.0.0.0)
npm run test:rules       # Firestore and Storage rules tests
cd app && flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=../env/dev.json
```
