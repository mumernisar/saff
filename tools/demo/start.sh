#!/usr/bin/env bash
# One-command demo setup: emulators (data persists), sweeper ticker, install on every attached phone.
set -e
cd "$(dirname "$0")/../.."
IP=$(ipconfig getifaddr en0)
sed -i '' "s/\"EMULATOR_HOST\": \"[^\"]*\"/\"EMULATOR_HOST\": \"$IP\"/" env/dev.json
echo "Mac IP $IP (phones must be on the same Wi-Fi/hotspot)"
pgrep -f "firebase emulators" >/dev/null || (npm run emulators > /tmp/saff-emu.log 2>&1 &)
pgrep -f ticker.sh >/dev/null || (nohup tools/demo/ticker.sh >/dev/null 2>&1 &)
sleep 35
cd app
flutter build apk --debug --flavor dev -t lib/main_dev.dart --dart-define-from-file=../env/dev.json
for D in $(adb devices | awk 'NR>1 && $2=="device"{print $1}'); do
  adb -s "$D" install -r build/app/outputs/flutter-apk/app-dev-debug.apk
  adb -s "$D" shell pm grant app.saff.dev android.permission.POST_NOTIFICATIONS || true
  adb -s "$D" shell pm grant app.saff.dev android.permission.CAMERA || true
  adb -s "$D" shell am start -n app.saff.dev/app.saff.saff_app.MainActivity
done
