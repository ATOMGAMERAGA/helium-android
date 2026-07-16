#!/bin/bash
set -euxo pipefail

_base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd ../.. && pwd)"
_cache_tar="${_base_dir}/.github/cache/build-cache-$ARCH.tar.zst"

cd "$_base_dir"

[ -d "build" ] || exit 1

mkdir -p "$(dirname "$_cache_tar")"
rm -rf "build/download_cache"

# depot_tools and the .gclient config are re-created on demand and the
# .git dirs of the checkout are the bulk of its size; keep the cache
# as small as possible so it fits in artifact storage
tar --exclude='build/src/.git' \
    --exclude='build/depot_tools' \
    -cf - "build" | zstd -f -T0 -3 -o "${_cache_tar}"
