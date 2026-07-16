#!/usr/bin/env bash
# installs the built APK on a connected device/emulator and launches it
set -euo pipefail

# shellcheck source=scripts/shared.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/shared.sh"

setup_environment

_apk="${_out_dir}/apks/ChromePublic.apk"

if [ ! -f "$_apk" ]; then
    echo "no APK at $_apk -- run scripts/build.sh first" >&2
    exit 1
fi

_adb="${_src_dir}/third_party/android_sdk/public/platform-tools/adb"
command -v adb >/dev/null 2>&1 && _adb=adb

"$_adb" install -r "$_apk"
"$_adb" shell am start -n "net.imput.helium/org.chromium.chrome.browser.ChromeTabbedActivity"
