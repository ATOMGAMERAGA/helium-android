#!/bin/bash
# CI entrypoint, executed inside the docker build image
set -euxo pipefail

. "/repo/scripts/shared.sh"

setup_environment

if [ "${_runner_environment:-github-hosted}" = "github-hosted" ]; then
    export SCCACHE_GHA_ENABLED=on
    export SCCACHE_GHA_VERSION="helium-android-$_build_arch"
else  # self-hosted / depot
    export SCCACHE_WEBDAV_KEY_PREFIX="helium-android-$_build_arch"
fi

if [ "${_prepare_only:-false}" = true ]; then
    fetch_sources

    if command -v apt-get >/dev/null 2>&1; then
        install_build_deps
    fi

    apply_patches
    apply_domsub
    helium_substitution
    helium_apply_translations
    helium_version
    helium_resources
    write_gn_args
    fix_tool_downloading
    gn_gen
else
    _task_timeout=18000
    ensure_depot_tools
    cd "$_src_dir"

    set +e
    timeout -k 5m -s INT "${_task_timeout}"s autoninja -C out/Default chrome_public_apk
    rc=$?
    set -e

    if [ "${_gha_final:-false}" != "true" ] && [ "$rc" -eq 124 ]; then
        echo "Task timed out after ${_task_timeout}s; continuing in next run."
        echo "status=running" >> "$GITHUB_OUTPUT"
        exit 0
    elif [ "$rc" -eq 0 ] && [ -f "${_out_dir}/apks/ChromePublic.apk" ]; then
        echo "status=completed" >> "$GITHUB_OUTPUT"
    fi

    exit "$rc"
fi
