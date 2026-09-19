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

Uses the same Docker container upstream CI uses, so deps match exactly:

```bash
docker run --rm -v "$(pwd):/nextcloud-client" \
  ghcr.io/nextcloud/continuous-integration-client-appimage-qt6:client-appimage-el8-6.10.2-4 \
  /bin/bash -c "BUILDNR=local DESKTOP_CLIENT_ROOT=/nextcloud-client EXECUTABLE_NAME=nextcloud QT_BASE_DIR=/root/linux-gcc-x86_64 /nextcloud-client/admin/linux/build-appimage.sh"
```

Output `.AppImage` lands in the container's working dir — mount/copy it out, or add `-w /nextcloud-client/build-appimage-out` and adjust the script's output path if you want it dropped straight into the repo.

Set `BUILD_UPDATER=ON` to include the built-in updater.

#### Windows (NSIS/MSI installer) — needs a Windows machine

```powershell
git clone -q --depth=1 https://invent.kde.org/packaging/craftmaster.git CraftMaster
python CraftMaster\CraftMaster.py --config craftmaster.ini --target windows-msvc2022_64-cl -c --add-blueprint-repository "https://github.com/nextcloud/craft-blueprints-kde.git|stable-34.0|"
python CraftMaster\CraftMaster.py --config craftmaster.ini --target windows-msvc2022_64-cl -c --add-blueprint-repository "https://github.com/nextcloud/craft-blueprints-nextcloud.git|stable-34.0|"
python CraftMaster\CraftMaster.py --config craftmaster.ini --target windows-msvc2022_64-cl -c craft
python CraftMaster\CraftMaster.py --config craftmaster.ini --target windows-msvc2022_64-cl -c --install-deps nextcloud-client
python CraftMaster\CraftMaster.py --config craftmaster.ini --target windows-msvc2022_64-cl -c --src-dir . nextcloud-client
python CraftMaster\CraftMaster.py --config craftmaster.ini --target windows-msvc2022_64-cl -c --package nextcloud-client
```

Requires Python 3.12, Visual Studio 2022 (MSVC toolchain), and Inkscape on PATH. Packaged setup exe/MSI shows up under `windows-msvc2022_64-cl\build\nextcloud-client\work\build` (NSIS via CPack, `CPACK_NSIS_COMPRESSOR` set in `CPackOptions.cmake.in`).

No native or reliable cross-compile path from Ubuntu — Craft's Windows target needs the real MSVC toolchain.

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
