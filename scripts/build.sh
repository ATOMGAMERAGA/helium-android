#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/shared.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/shared.sh"

setup_environment

# clean out/ directory before build
rm -rf "${_src_dir}/out" || true

fetch_sources

# extra host packages (debian-likes only; skip with INSTALL_BUILD_DEPS=0)
if [ "${INSTALL_BUILD_DEPS:-1}" != 0 ] && command -v apt-get >/dev/null 2>&1; then
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
build
