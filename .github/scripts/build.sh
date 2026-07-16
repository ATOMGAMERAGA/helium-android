#!/bin/bash
# CI entrypoint, executed inside the docker build image
set -euxo pipefail

. "/repo/scripts/shared.sh"

setup_environment

export SCCACHE_GHA_ENABLED=on
export SCCACHE_GHA_VERSION="helium-android-$_build_arch"

bash /repo/scripts/build.sh "$@"

if [ -f "${_out_dir}/apks/ChromePublic.apk" ]; then
    echo "status=completed" >> "${GITHUB_OUTPUT:-/dev/null}"
fi
