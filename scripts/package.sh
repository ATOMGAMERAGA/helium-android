#!/usr/bin/env bash
set -euo pipefail

_current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
_root_dir="$(cd "$_current_dir/.." && pwd)"
_build_dir="$_root_dir/build"
_release_dir="$_build_dir/release"

_app_name="helium"
_version=$(python3 "$_root_dir/helium-chromium/utils/helium_version.py" \
                   --tree "$_root_dir/helium-chromium" \
                   --platform-tree "$_root_dir" \
                   --print)

_arch=$(cat "$_build_dir/src/out/Default/args.gn" \
                | grep ^target_cpu \
                | tail -1 \
                | sed 's/.*=//' \
                | cut -d'"' -f2)

_apk="$_build_dir/src/out/Default/apks/ChromePublic.apk"

if [ ! -f "$_apk" ]; then
    echo "no APK at $_apk -- run scripts/build.sh first" >&2
    exit 1
fi

_release_name="${_app_name}-${_version}-${_arch}_android"
mkdir -p "$_release_dir"

cp "$_apk" "$_release_dir/$_release_name.apk"

# re-sign with a release key when one is provided; otherwise the APK
# keeps the default (debug) signature from the build
if [ -n "${HELIUM_KEYSTORE_B64:-}" ] && [ -n "${HELIUM_KEYSTORE_PASSWORD:-}" ]; then
    _sdk_build_tools=$(find "$_build_dir/src/third_party/android_sdk/public/build-tools" \
        -maxdepth 1 -mindepth 1 -type d | sort -V | tail -1)

    _keystore="$(mktemp -d)/release.keystore"
    echo "$HELIUM_KEYSTORE_B64" | base64 -d > "$_keystore"

    "$_sdk_build_tools/apksigner" sign \
        --ks "$_keystore" \
        --ks-pass "pass:$HELIUM_KEYSTORE_PASSWORD" \
        ${HELIUM_KEY_ALIAS:+--ks-key-alias "$HELIUM_KEY_ALIAS"} \
        "$_release_dir/$_release_name.apk"

    rm -f "$_keystore"
    echo "signed $_release_name.apk with the provided release key"
else
    echo "HELIUM_KEYSTORE_B64 not set; keeping default signature"
fi

(cd "$_release_dir" && sha256sum "$_release_name.apk" | tee "$_release_name.apk.sha256")

echo "release APK: $_release_dir/$_release_name.apk"
