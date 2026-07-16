# shellcheck shell=bash
# shared build functions used by local and CI scripts
# (Android port of helium-linux's scripts/shared.sh)

if [ -n "${BASH_VERSION:-}" ]; then
    __helium_shared_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then
    __helium_shared_dir="${0:a:h}"
else
    echo "shared.sh only supports bash and zsh" >&2
    return 1 2>/dev/null || exit 1
fi

# resolve repo root directory regardless of caller location
repo_root() {
    cd "${__helium_shared_dir}/.." >/dev/null 2>&1 && pwd
}

setup_arch() {
    # Android target CPU. arm64 covers the overwhelming majority of
    # devices; arm (32-bit), x64 and x86 are also valid.
    _build_arch="${ARCH:-arm64}"

    case "$_build_arch" in
        arm64|arm|x64|x86) ;;
        aarch64) _build_arch=arm64;;
        armv7|armeabi-v7a) _build_arch=arm;;
        x86_64|amd64) _build_arch=x64;;
        *)
            echo "unsupported Android target arch: $_build_arch" >&2
            echo "supported: arm64, arm, x64, x86" >&2
            exit 1;;
    esac
}

setup_paths() {
    _root_dir="$(repo_root)"
    _main_repo="${_root_dir}/helium-chromium"
    _build_dir="${_root_dir}/build"
    _dl_cache="${_build_dir}/download_cache"
    _depot_tools="${_build_dir}/depot_tools"
    _src_dir="${_build_dir}/src"
    _out_dir="${_src_dir}/out/Default"

    _namesubs_cache="${_build_dir}/namesubs.tar"

    _chromium_version="$(cat "${_main_repo}/chromium_version.txt")"

    mkdir -p "${_dl_cache}"
}

setup_environment() {
    setup_paths
    setup_arch

    export PATH="${_depot_tools}:${PATH}"
    export DEPOT_TOOLS_UPDATE=0
    export DEPOT_TOOLS_METRICS=0
}

ensure_depot_tools() {
    if [ ! -d "${_depot_tools}" ]; then
        git clone --depth 1 \
            https://chromium.googlesource.com/chromium/tools/depot_tools.git \
            "${_depot_tools}"
    fi

    # depot_tools' wrappers (gn, python3, ...) run out of a CIPD-managed
    # python whose location is recorded in python3_bin_reldir.txt. That file
    # is written by the one-time bootstrap, which gclient sync skips while
    # DEPOT_TOOLS_UPDATE=0 (set in setup_environment to avoid a self-update
    # on every invocation) -- so the gn wrapper otherwise fails with
    # "python3_bin_reldir.txt not found". ensure_bootstrap fetches those
    # programs for the current checkout without updating depot_tools itself;
    # run it when that marker is missing. (python-bin/python3 is a checked-in
    # wrapper, so it can't be used to detect whether the bootstrap has run.)
    if [ ! -f "${_depot_tools}/python3_bin_reldir.txt" ] \
        && [ -x "${_depot_tools}/ensure_bootstrap" ]; then
        "${_depot_tools}/ensure_bootstrap"
    fi
}

# Android needs a gclient checkout: the SDK, NDK and several
# android-only third_party dependencies are delivered through DEPS
# hooks and aren't part of the release tarball that the desktop
# platforms build from.
fetch_sources() {
    local stamp="${_src_dir}/.downloaded.stamp"

    if [ -f "${stamp}" ]; then
        echo "Sources already present, skipping fetch"
        return 0
    fi

    ensure_depot_tools

    cat > "${_build_dir}/.gclient" <<EOF
solutions = [
  {
    "name": "src",
    "url": "https://chromium.googlesource.com/chromium/src.git",
    "managed": False,
    "custom_deps": {},
    "custom_vars": {
      "checkout_pgo_profiles": True,
    },
  },
]
target_os = ["android"]
target_os_only = True
EOF

    (
        cd "${_build_dir}" || exit 1
        if [ ! -d "${_src_dir}/.git" ]; then
            git clone --depth 1 --no-tags \
                --branch "${_chromium_version}" \
                https://chromium.googlesource.com/chromium/src.git \
                "${_src_dir}"
        fi
        gclient sync --no-history --shallow --nohooks \
            --revision "src@refs/tags/${_chromium_version}" \
            -j"$(nproc)"
        gclient runhooks
    )

    # Helium components: uBlock Origin fork, onboarding page,
    # search engine data (same as the desktop platforms)
    "${_main_repo}/utils/downloads.py" retrieve -i "${_main_repo}/deps.ini" -c "${_dl_cache}"
    "${_main_repo}/utils/downloads.py" unpack -i "${_main_repo}/deps.ini" -c "${_dl_cache}" "${_src_dir}"

    touch "${stamp}"
}

# install distro + android packages needed for building
# (only works on debian-likes; the docker image takes care of this)
install_build_deps() {
    if [ -f "${_src_dir}/.deps.stamp" ]; then
        return 0
    fi

    "${_src_dir}/build/install-build-deps.py" --android --no-prompt
    touch "${_src_dir}/.deps.stamp"
}

apply_patches() {
    if [ ! -f "${_src_dir}/.patched.stamp" ]; then
        # NOTE: unlike the desktop platforms, binary pruning is skipped
        # here: a gclient checkout relies on prebuilts (clang, rust, JDK,
        # SDK/NDK tooling) that pruning.list would delete, and deps.ini
        # only restores the subset needed by tarball builds.
        "${_main_repo}/utils/patches.py" apply "${_src_dir}" "${_main_repo}/patches" "${_root_dir}/patches"
        touch "${_src_dir}/.patched.stamp"
    fi
}

apply_domsub() {
    if [ ! -f "${_src_dir}/.domsub.stamp" ]; then
        "${_main_repo}/utils/domain_substitution.py" apply -r "${_main_repo}/domain_regex.list" -f "${_main_repo}/domain_substitution.list" "${_src_dir}"
        touch "${_src_dir}/.domsub.stamp"
    fi
}

helium_substitution() {
    python3 "$_main_repo/utils/name_substitution.py" --sub \
        -t "$_src_dir" --backup-path "$_namesubs_cache"
}

helium_apply_translations() {
    python3 "$_main_repo/utils/i18n_apply.py" -t "$_src_dir"
}

helium_version() {
    python3 "$_main_repo/utils/helium_version.py" \
        --tree "$_main_repo" \
        --platform-tree "$_root_dir" \
        --chromium-tree "$_src_dir"
}

helium_resources() {
    python3 "$_main_repo/utils/generate_resources.py" "$_main_repo/resources/generate_resources.txt" "$_main_repo/resources"
    python3 "$_main_repo/utils/replace_resources.py" "$_main_repo/resources/helium_resources.txt" "$_main_repo/resources" "$_src_dir"

    # android launcher icons and adaptive icon layers
    python3 "$_main_repo/utils/replace_resources.py" "$_root_dir/resources/android_resources.txt" "$_root_dir/resources" "$_src_dir"
}

write_gn_args() {
    mkdir -p "${_out_dir}"

    cat "${_main_repo}/flags.gn" "${_root_dir}/flags.android.gn" | tee "${_out_dir}/args.gn"
    echo "target_cpu = \"$_build_arch\"" | tee -a "${_out_dir}/args.gn"

    if command -v sccache >/dev/null 2>&1 && env | grep -q ^SCCACHE; then
        echo 'cc_wrapper = "sccache"' | tee -a "${_out_dir}/args.gn"
    elif command -v ccache >/dev/null; then
        echo 'cc_wrapper = "ccache"' | tee -a "${_out_dir}/args.gn"
    fi
}

# domain substitution rewrites the download hosts used by toolchain
# update scripts; point them back at the real endpoints in case any
# hook needs to re-run after domsub
# (https://github.com/ungoogled-software/ungoogled-chromium/issues/1846)
fix_tool_downloading() {
    sed -i 's/commondatastorage.9oo91eapis.qjz9zk/commondatastorage.googleapis.com/g' \
        "${_src_dir}/tools/clang/scripts/update.py" \
        "${_src_dir}/tools/clang/scripts/build.py" || true

    sed -i 's/chromium.9oo91esource.qjz9zk/chromium.googlesource.com/g' \
        "${_src_dir}/tools/clang/scripts/build.py" \
        "${_src_dir}/tools/rust/build_rust.py" \
        "${_src_dir}/tools/rust/build_bindgen.py" || true
}

gn_gen() {
    ensure_depot_tools
    cd "${_src_dir}" || return 1
    gn gen out/Default --fail-on-unused-args
}

build() {
    ensure_depot_tools
    cd "${_src_dir}" || return 1
    autoninja -C out/Default chrome_public_apk
}
