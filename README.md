<!--
  - SPDX-FileCopyrightText: 2017 Nextcloud GmbH and Nextcloud contributors
  - SPDX-FileCopyrightText: 2011 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: GPL-2.0-or-later
-->
# CMC Desktop Client

CMC (Cloudmail City) is a desktop sync client for Windows, macOS and Linux, built on a fork of the [Nextcloud Desktop Client](https://github.com/nextcloud/desktop). It syncs files between the CMC server and your computer.

<p align="center">
    <img src="doc/images/main_dialog_christine.png" alt="Desktop Client on Windows" width="450">
</p>

## About this fork

This is a private fork of the Nextcloud Desktop Client, rebranded and locked to our own server (`https://nc.cloudmail.city/`). It is not affiliated with Nextcloud GmbH, is not submitted upstream, and does not follow Nextcloud's contribution process. See `CLAUDE.md` for active branding/UI conventions and `AGENTS.md` for engineering context on the codebase.

It remains licensed GPL-2.0-or-later, same as upstream — see [License](#license-) below.

## Bug fixing and development 🛠️

> [!TIP]
> For contributors on macOS, see the [macOS development guide](./doc/macOS-development.md).

> [!NOTE]
> Find the system requirements and instructions on [how to work with KDE Craft in our desktop client blueprints repository](https://github.com/nextcloud/craft-blueprints-nextcloud/).

### System requirements
- Windows 10, Windows 11, macOS 13 Ventura (or newer) or Linux
- [🔽 Inkscape (to generate icons)](https://inkscape.org/release/)
- Developer tools: cmake, clang/gcc/g++
- Qt6 (Qt 6.10.3 configured in this repo)
- OpenSSL
- [🔽 QtKeychain](https://github.com/frankosterfeld/qtkeychain)
- SQLite
- [Xcode](https://developer.apple.com/xcode/) (only on macOS)

Optional recommendations:

- [Qt Creator IDE](https://www.qt.io/product/development-tools)
- [delta: A viewer for git and diff output](https://github.com/dandavison/delta)

### Build

1. Clone this repository: `git clone git@github-colombians:jorge-colombians/nx-desktop.git`
2. Create build directory: `mkdir <build directory>`
3. Navigate into build directory: `cd <build directory>`
4. Compile: `cmake -S <cloned repo> -B build -DCMAKE_PREFIX_PATH=<dependencies> -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=. -DNEXTCLOUD_DEV=ON`

> [!TIP]
> The cmake variable NEXTCLOUD_DEV allows you to run your own build of the client while developing in parallel with an installed version of the client.

> [!TIP]
> The production server URL is locked via `NEXTCLOUD.cmake`. For local testing against a different server, reconfigure with `-DAPPLICATION_SERVER_URL="http://localhost:8080"` (requires re-running `cmake -S/-B`, not just a rebuild).

For day-to-day local iteration (Debug config already set up for Qt 6.10.3):

```bash
cmake --build "<repo>/build/QT_6_10_3-Debug" --target nextcloud -j$(nproc) && "<repo>/build/QT_6_10_3-Debug/bin/nextcloud"
```

### Building installers

Official installers all go through [KDE Craft](https://community.kde.org/Craft) (config in `craftmaster.ini`), except Linux which uses a dedicated AppImage script. Windows and macOS installers **must** be built on their target OS (Craft targets MSVC / Xcode toolchains — no cross-compile from Linux). Linux AppImage builds fine on Ubuntu.

#### Linux (AppImage) — buildable on Ubuntu

Easiest: `./dev-ubuntu.sh appimage` (menu option "Build installer"). It runs the
command below with a numeric build number and a parallel-job limit that fits
Docker's memory, and puts the result in `dist/`. `./dev-ubuntu.sh appimage-install`
then adds it to your own app menu.

When started, the AppImage adds itself to the user's app menu (a `.desktop` file
and icon in `~/.local/share`, see `installAppImageDesktopEntry()` in
`src/common/utility_unix.cpp`), so users only need to run it once.

Uses the same Docker container upstream CI uses, so deps match exactly:

```bash
docker run --rm -v "$(pwd):/nextcloud-client" \
  ghcr.io/nextcloud/continuous-integration-client-appimage-qt6:client-appimage-el8-6.10.2-4 \
  /bin/bash -c "BUILDNR=0 DESKTOP_CLIENT_ROOT=/nextcloud-client EXECUTABLE_NAME=cmc QT_BASE_DIR=/root/linux-gcc-x86_64 /nextcloud-client/admin/linux/build-appimage.sh"
```

The `.AppImage` lands in the repo root (owned by root, since the container runs as root).

Set `BUILD_UPDATER=ON` to include the built-in updater.

#### Windows (NSIS/MSI installer) — needs a Windows machine

Create an untracked `craftmaster.local.ini` next to `craftmaster.ini` (one-time step) pointing Craft's root at a short path — Craft's own build/cache paths get deep enough to blow past Windows' 260-char `MAX_PATH` if the repo itself is nested (e.g. under `Documents\Projects\...`), which fails downloads with `Failed to open ... (2)` even on HTTP 200, or cascades into unrelated pip/SSL errors when Craft falls back to building from source:

```ini
[Variables]
Root = C:\craft-nc
```

```powershell
git clone -q --depth=1 https://invent.kde.org/packaging/craftmaster.git CraftMaster
python CraftMaster\CraftMaster.py --config craftmaster.ini --config-override craftmaster.local.ini --target windows-msvc2022_64-cl -c --add-blueprint-repository "https://github.com/nextcloud/craft-blueprints-kde.git|stable-34.0|"
python CraftMaster\CraftMaster.py --config craftmaster.ini --config-override craftmaster.local.ini --target windows-msvc2022_64-cl -c --add-blueprint-repository "https://github.com/nextcloud/craft-blueprints-nextcloud.git|stable-34.0|"
python CraftMaster\CraftMaster.py --config craftmaster.ini --config-override craftmaster.local.ini --target windows-msvc2022_64-cl -c craft
python CraftMaster\CraftMaster.py --config craftmaster.ini --config-override craftmaster.local.ini --target windows-msvc2022_64-cl -c --install-deps nextcloud-client
python CraftMaster\CraftMaster.py --config craftmaster.ini --config-override craftmaster.local.ini --target windows-msvc2022_64-cl -c --options "nextcloud-client.srcDir=$PWD" nextcloud-client
python CraftMaster\CraftMaster.py --config craftmaster.ini --config-override craftmaster.local.ini --target windows-msvc2022_64-cl -c --package nextcloud-client
```

`--options nextcloud-client.srcDir=...` (run from the repo root, so `$PWD` resolves correctly) replaces the older `--src-dir .`, which is deprecated, rejects relative paths, and — because it sets the source dir globally rather than scoped to one blueprint — crashes unrelated packages like `libs/python/python.py`.

Requires Python 3.12, Visual Studio 2022 (MSVC toolchain), and Inkscape on PATH. Packaged setup exe/MSI shows up under `C:\craft-nc\windows-msvc2022_64-cl\build\nextcloud-client\work\build` (NSIS via CPack, `CPACK_NSIS_COMPRESSOR` set in `CPackOptions.cmake.in`).

No native or reliable cross-compile path from Ubuntu — Craft's Windows target needs the real MSVC toolchain.

> [!NOTE]
> If the `nextcloud-client` install step fails with `file INSTALL cannot find ".../theme/cmc.VisualElementsManifest.xml": File exists.`, it's a leftover from the Nextcloud→CMC rebrand: `src/gui/CMakeLists.txt` installs `theme/${APPLICATION_EXECUTABLE}.VisualElementsManifest.xml` (`APPLICATION_EXECUTABLE` = `cmc`, set in `NEXTCLOUD.cmake`), but the file itself was never renamed from `theme/nextcloud.VisualElementsManifest.xml`. Already fixed on this branch — mentioned here in case an older checkout still hits it.
>
> `--package nextcloud-client` needs three local patches to `<craft-root>\etc\blueprints\locations\craft-blueprints-nextcloud\nextcloud-client\`, because that repo (an upstream dependency, not part of this codebase — pulled in via `--add-blueprint-repository`) was never updated for the Nextcloud→CMC rebrand and can't be fixed here:
>
> 1. `NameError: name 'os' is not defined` in `createPackage` (`nextcloud-client.py`, `self.blacklist_file.append(os.path.join(...))`) — missing `import os`. Add `import os` at the top of `nextcloud-client.py`, above `import info`.
> 2. The final installer silently ships with **no main executable at all** (only DLLs/`uninstall.exe` — nothing to run after installing). Cause: `blacklist.txt`'s last line, `bin/(?!(nextcloud|nextcloudcmd|QtWebEngineProcess)).*\.exe`, blacklists every `.exe` in `bin/` except an explicit name whitelist — and this build produces `cmc.exe`/`cmccmd.exe`, not `nextcloud.exe`/`nextcloudcmd.exe`, so both get stripped. Change the pattern to `bin/(?!(cmc|cmccmd|QtWebEngineProcess)).*\.exe`.
> 3. No Start Menu shortcut gets created, and the installer/install-dir/company name all still say "Nextcloud". In `nextcloud-client.py`'s `setTargets()` and `createPackage()`, update `self.description`, `self.displayName`, `self.defines["appname"]`, `self.defines["company"]`, and `self.applicationExecutable` to CMC branding, and add `self.defines["executable"] = "bin\\cmc.exe"` so `NullsoftInstallerPackager` generates the shortcut.
>
> The installer/exe icon still defaults to Craft's generic mascot icon (`data/icons/craft.ico`) since no CMC `.ico` exists yet — not fixed, since it needs a real icon asset generated first.

#### macOS (.dmg) — needs a Mac

```bash
git clone --depth=1 https://invent.kde.org/packaging/craftmaster.git CraftMaster
python3 CraftMaster/CraftMaster.py --config craftmaster.ini --target macos-64-clang -c --add-blueprint-repository "https://github.com/nextcloud/craft-blueprints-kde.git|stable-34.0|"
python3 CraftMaster/CraftMaster.py --config craftmaster.ini --target macos-64-clang -c --add-blueprint-repository "https://github.com/nextcloud/craft-blueprints-nextcloud.git|stable-34.0|"
python3 CraftMaster/CraftMaster.py --config craftmaster.ini --target macos-64-clang -c craft
python3 CraftMaster/CraftMaster.py --config craftmaster.ini --target macos-64-clang -c --install-deps nextcloud-client
python3 CraftMaster/CraftMaster.py --config craftmaster.ini --target macos-64-clang -c --options nextcloud-client.srcDir=$(pwd) nextcloud-client
python3 CraftMaster/CraftMaster.py --config craftmaster.ini --target macos-64-clang -c --package nextcloud-client
```

Use target `macos-clang-arm64` for Apple Silicon. Requires Xcode + command line tools and `brew install homebrew/cask/inkscape`. Output DMG uses CPack's DragNDrop generator (`CPACK_DMG_*` in `NextcloudCPack.cmake`). See also [`doc/macOS-development.md`](./doc/macOS-development.md).

> [!NOTE]
> Craftmaster repo URLs/branches (`stable-34.0`) and the AppImage container tag come straight from upstream's `.github/workflows/windows-build-and-test.yml`, `macos-build-and-test.yml` and `linux-appimage.yml` — check those if a build fails, CI config there is the source of truth for the underlying toolchain.

### Test servers

The easiest way to have a local server to develop, debug and test the client against is [the Nextcloud Docker image](https://github.com/nextcloud/docker) (CMC's server is itself Nextcloud-based).
The following example shows how to deploy a container on the local host which will be removed again as soon as the command is interrupted.
Note that this requires Docker to be installed in your developer environment.

```bash
docker run \
    --rm \
    --publish 8080:80 \
    --env SQLITE_DATABASE=nextcloud.sqlite \
    --env NEXTCLOUD_ADMIN_USER=admin \
    --env NEXTCLOUD_ADMIN_PASSWORD=admin \
    nextcloud
```

Remember to build with `-DAPPLICATION_SERVER_URL="http://localhost:8080"` to point the client at this local server instead of the enforced production URL.

#### Ready to use: run current changes against your local Docker server

With the Docker container above running on `localhost:8080` and the `QT_6_10_3-Debug` build already configured, this reconfigures the server URL, rebuilds, and launches in one go:

```bash
cmake -S . -B build/QT_6_10_3-Debug -DAPPLICATION_SERVER_URL="http://localhost:8080" \
  && cmake --build build/QT_6_10_3-Debug --target nextcloud -j$(nproc) \
  && rm -f ~/.config/Nextcloud/nextcloud.cfg \
  && ./build/QT_6_10_3-Debug/bin/cmc
```

The `rm` clears any existing account config so the first-run wizard reappears pointed at the new URL — drop it if you just want to relaunch with an already-configured account. Switch back to production by re-running the `cmake -S -B` reconfigure step with `-DAPPLICATION_SERVER_URL="https://nc.cloudmail.city/"` (or just omit the flag — that's the default in `NEXTCLOUD.cmake`).

## License 📜

This project is a derivative work of the Nextcloud Desktop Client and remains licensed under the GPL:

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
    for more details.
