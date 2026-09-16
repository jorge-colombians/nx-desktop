<!--
  - SPDX-FileCopyrightText: 2017 Nextcloud GmbH and Nextcloud contributors
  - SPDX-FileCopyrightText: 2011 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: GPL-2.0-or-later
-->
# Nextcloud Desktop Client

[![REUSE status](https://api.reuse.software/badge/github.com/nextcloud/desktop)](https://api.reuse.software/info/github.com/nextcloud/desktop)

The Nextcloud Desktop Client is an app to synchronize files from Nextcloud Server with your computer available for Windows, macOS and Linux.

<p align="center">
    <img src="doc/images/main_dialog_christine.png" alt="Desktop Client on Windows" width="450">
</p>

## Downloads 🚀
For the latest stable and recommended version, please refer to [the official download page](https://nextcloud.com/install/#install-clients).

## Help 🛟
You can find [the user, administration and developer manuals for the desktop client](https://docs.nextcloud.com/#desktop) on our central documentation site.

## Contributing 🫴
- Make sure to follow our [guidelines for contributing](https://github.com/nextcloud/desktop/blob/98690b1e9141f2c602c9b4583c1f9ed16b95a309/CONTRIBUTING.md) to this repository.
- Don't forget to read our [Code of Conduct](https://nextcloud.com/community/code-of-conduct/). This document offers some guidance to ensure Nextcloud participants can cooperate effectively in a positive and inspiring atmosphere and to explain how together we can strengthen and support each other.

## Join the team 👪
There are many ways to contribute, of which development is only one! Find out [how to get involved](https://nextcloud.com/contribute/), including as a translator, designer, tester, helping others, and much more! 😍

## Help testing 🔬
Download and install the client:

- [All releases](https://github.com/nextcloud-releases/desktop/releases)<br>
- [Daily builds](https://download.nextcloud.com/desktop/daily)

## Reporting issues 🐛
If you find any bugs or have any suggestion for improvement, please
[open an issue in this repository](https://github.com/nextcloud/desktop/issues).

## Bug fixing and development 🛠️

> [!TIP]
> For contributors on macOS, see the [macOS development guide](./doc/macOS-development.md).

> [!NOTE]  
> Find the system requirements and instructions on [how to work with KDE Craft in our desktop client blueprints repository](https://github.com/nextcloud/craft-blueprints-nextcloud/).

### System requirements
- Windows 10, Windows 11, macOS 13 Ventura (or newer) or Linux
- [🔽 Inkscape (to generate icons)](https://inkscape.org/release/)
- Developer tools: cmake, clang/gcc/g++:
- Qt6 since 3.14, Qt5 for earlier versions
- OpenSSL
- [🔽 QtKeychain](https://github.com/frankosterfeld/qtkeychain)
- SQLite
- [Xcode](https://developer.apple.com/xcode/) (only on macOS)

Optional recommendations:

- [Qt Creator IDE](https://www.qt.io/product/development-tools)
- [delta: A viewer for git and diff output](https://github.com/dandavison/delta)

### Build

Step by step instructions on how to build the client to contribute.

1. Clone the Github repository: `git clone https://github.com/nextcloud/desktop.git`
2. Create build directory: `mkdir <build directory>`
3. Navigate into build directory: `cd <build directory>`
4. Compile: `cmake -S <cloned desktop repo> -B build -DCMAKE_PREFIX_PATH=<dependencies> -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=. -DNEXTCLOUD_DEV=ON`

> [!TIP]
> The cmake variable NEXTCLOUD_DEV allows you to run your own build of the client while developing in parallel with an installed version of the client.

Then you might continue with these steps:
	
1. 🐛 [Pick a good first issue](https://github.com/nextcloud/desktop/labels/good%20first%20issue)
2. 👩‍🔧 Create a branch and make your changes. Remember to sign off your commits using `git commit -sm "Your commit message"`
3. ⬆ Create a [pull request](https://opensource.guide/how-to-contribute/#opening-a-pull-request) and `@mention` the people from the issue to eview
4. 👍 Fix things that come up during a review
5. 🎉 Wait for it to get merged!

### Building installers

Official installers all go through [KDE Craft](https://community.kde.org/Craft) (config in `craftmaster.ini`), except Linux which uses a dedicated AppImage script. Windows and macOS installers **must** be built on their target OS (Craft targets MSVC / Xcode toolchains — no cross-compile from Linux). Linux AppImage builds fine on Ubuntu.

#### Linux (AppImage) — buildable on Ubuntu

Uses the same Docker container CI uses, so deps match exactly:

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
> Craftmaster repo URLs/branches (`stable-34.0`) and the AppImage container tag come straight from `.github/workflows/windows-build-and-test.yml`, `macos-build-and-test.yml` and `linux-appimage.yml` — check those if a build fails, CI config is the source of truth.

### Test servers

The easiest way to have a local Nextcloud server to develop, debug and test the client against is [the Nextcloud Docker image](https://github.com/nextcloud/docker).
The following example shows how to deploy a Nextcloud Docker container on the local host which will be removed again as soon as the command is interrupted.
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

This simple test server already suffices in the most cases. For more advanced server test deployments we also recommend [Nextcloud development environment on Docker Compose](https://juliusknorr.github.io/nextcloud-docker-dev/).

## Get in touch 💬
* [📋 Forum](https://help.nextcloud.com)
* [🐘 Mastodon](https://mastodon.xyz/@nextcloud)
* [🔗 LinkedIn](https://www.linkedin.com/company/nextcloud-gmbh/)
* [🦋 Bluesky](https://bsky.app/profile/nextcloud.bsky.social)
* [👥 Facebook](https://www.facebook.com/nextclouders)

You can also [get professional support for Nextcloud and the desktop client](https://nextcloud.com/support)!

## License 📜

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
    for more details.
