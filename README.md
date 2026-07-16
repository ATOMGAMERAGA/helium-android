<div align="center">
    <img src="resources/android/mipmap-xxxhdpi/app_icon.png"
        title="Helium" alt="Helium logo" width="120" />
    <h1>Helium for Android</h1>
    <p>
        Android builds, packaging, and development tooling for the
        <a href="https://github.com/imputnet/helium">Helium Browser</a>.
        <br>
        Privacy-first with unbiased ad-blocking. No bloat and no noise.
    </p>
</div>

> [!IMPORTANT]
> This is a **community-maintained port** of Helium to Android. It is not an
> official [imput](https://github.com/imputnet) project. For the official
> desktop browser, see [helium.computer](https://helium.computer/).

> [!NOTE]
> Helium for Android is in an early stage. Chromium's Android UI is an
> entirely different (Java/Kotlin) frontend from the desktop UI, so
> desktop-only Helium UI features arrive progressively. Everything that
> lives in the shared engine — ungoogling, network privacy, Helium
> services, branding, and search defaults — applies tree-wide and is
> included from the start.

## How this repo works
This repo follows the exact same architecture as
[helium-linux](https://github.com/imputnet/helium-linux),
[helium-macos](https://github.com/imputnet/helium-macos), and
[helium-windows](https://github.com/imputnet/helium-windows):

- [`helium-chromium/`](https://github.com/imputnet/helium) (git submodule) —
  the shared Helium patchset, branding resources, translations, uBlock
  Origin/onboarding/search-engine components, and build utilities.
- [`patches/`](patches/) — Android-specific patches applied on top of the
  shared patchset (branding of the Android app name, widgets, etc.).
- [`flags.android.gn`](flags.android.gn) — Android GN build flags, combined
  with the shared [`flags.gn`](https://github.com/imputnet/helium/blob/main/flags.gn).
  The application ID is `net.imput.helium`.
- [`resources/android/`](resources/android/) — launcher icons and adaptive
  icon layers generated from the official Helium logo by
  [`devutils/generate_android_icons.py`](devutils/generate_android_icons.py).
- [`scripts/`](scripts/) — fetch/patch/build/package tooling.
- [`docker/`](docker/) — reproducible Debian-based build environment.

The build pipeline is the same as the desktop platforms:

1. Fetch Chromium (pinned to the version in
   `helium-chromium/chromium_version.txt`) with `target_os = ["android"]`.
2. Fetch Helium components (uBlock Origin fork, onboarding, search engine
   data) from `helium-chromium/deps.ini`.
3. Apply the shared Helium patchset, then the Android patches in this repo.
4. Apply domain substitution, Helium name substitution, translations,
   version stamping, and branding resources (including the Android icons).
5. Generate GN args from `flags.gn` + `flags.android.gn` and build
   `chrome_public_apk`.

## Downloads
APKs are published on the
[releases page](../../releases) when builds are available, for these ABIs:

| ABI | GN `target_cpu` |
| --- | --- |
| `arm64-v8a` (most devices) | `arm64` |
| `armeabi-v7a` | `arm` |
| `x86_64` (emulators) | `x64` |

Verify the `.sha256` checksum after downloading. Helium for Android is not
on the Play Store; sideload the APK or use your favorite APK manager.

## Building

### Requirements
- Linux host (Debian-based recommended; anything with Docker works)
- ~200 GB free disk space
- 16+ GB RAM (more is better; a full Chromium build is heavy)
- Several hours of build time depending on hardware

### With Docker (recommended)
```bash
git clone --recurse-submodules https://github.com/ATOMGAMERAGA/helium-android.git
cd helium-android
ARCH=arm64 ./scripts/docker-build.sh
```

`ARCH` can be `arm64` (default), `arm`, `x64`, or `x86`.

### Without Docker
Only supported on Debian-based distros:

```bash
ARCH=arm64 ./scripts/build.sh
```

The script installs the required host packages via Chromium's
`install-build-deps.py --android` (set `INSTALL_BUILD_DEPS=0` to skip).

### Packaging and signing
```bash
./scripts/package.sh
```

This copies the built `ChromePublic.apk` to
`build/release/helium-<version>-<arch>_android.apk` and writes a SHA-256
checksum. To sign with a release key instead of the default debug
signature, set:

```bash
export HELIUM_KEYSTORE_B64="$(base64 -w0 < release.keystore)"
export HELIUM_KEYSTORE_PASSWORD="..."
export HELIUM_KEY_ALIAS="..."   # optional if the keystore has one key
```

### Installing on a device
```bash
./scripts/dev.sh   # adb install + launch
```

### CI
[`build.yml`](.github/workflows/build.yml) builds APKs for each requested
arch and can create a GitHub release. Note that a full Chromium build
exceeds the limits of free GitHub-hosted runners — use a large self-hosted
runner (upstream Helium uses [Depot](https://depot.dev/)-sponsored
runners for the same reason).

## Updating to a new Helium/Chromium version
1. Update the submodule: `git -C helium-chromium pull origin main`
2. Rebase the patches in [`patches/`](patches/) if they no longer apply.
3. Regenerate icons only if the logo changed:
   `python3 devutils/generate_android_icons.py`
4. Bump [`revision.txt`](revision.txt) if making a new build of the same
   Helium version.

## Known limitations
- Chromium for Android has no extension platform, so the bundled uBlock
  Origin fork — which desktop Helium ships as an extension — cannot be
  loaded the same way yet. Ad-blocking parity is the top item on the
  roadmap.
- Desktop-specific Helium UI patches (toolbar, settings pages, split view)
  target the Views/WebUI desktop frontend and do not affect the Android
  Java UI; Android-native equivalents are added over time in
  `patches/helium/android/`.
- Widevine on Android is provided by Google Play Services; on degoogled
  devices, DRM-protected playback may be unavailable.

## Credits
- [Helium](https://github.com/imputnet/helium) — the browser this repo
  ports, made by [imput](https://imput.net/) with love.
- [The Chromium Project](https://www.chromium.org/) — at the core of
  Helium, making it possible in the first place.
- [ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium) —
  the foundation of Helium's patchset; this repo's structure also borrows
  from [helium-linux](https://github.com/imputnet/helium-linux).

## Contributing
Before contributing, please read the guidelines in the main repo's
[CONTRIBUTING.md](https://github.com/imputnet/helium/blob/main/CONTRIBUTING.md).

## License
All code, patches, modified portions of imported code or patches, and
any other content that is unique to Helium and not imported from other
repositories is licensed under GPL-3.0. See [LICENSE](LICENSE).

Any content imported from other projects retains its original license (for
example, any original unmodified code imported from ungoogled-chromium remains
licensed under their [BSD 3-Clause license](LICENSE.ungoogled_chromium)).
