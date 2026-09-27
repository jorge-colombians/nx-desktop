#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 CMC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Dev helper for Ubuntu: installs every build requirement, then configures,
# builds and runs the CMC desktop client (dev build, "CMCDev").
#
# Interactive:      ./dev-ubuntu.sh
# Non-interactive:  ./dev-ubuntu.sh <install|build|run|build-run|appimage|appimage-install|clean> [--local|--prod] [--reset]
#
#   --local   point the client at LOCAL_SERVER_URL (default http://localhost:8080)
#   --prod    point the client at the production server (default)
#   --reset   delete the client config before running, so the first-run wizard shows again
#
# "appimage" builds the release installer (CMC, production server) inside the
# same Docker image upstream CI uses and puts it in dist/. Needs Docker.
# "appimage-install" copies the AppImage from dist/ to ~/Applications and adds
# it (with its icon) to the app menu.
#
# Every path below can be overridden with an environment variable, e.g.
#   QT_ROOT=/opt/Qt ./dev-ubuntu.sh install
#
# Safe to run repeatedly: anything already installed is skipped, and build
# folders whose CMake cache points to another location (e.g. after copying or
# moving this folder, or coming from another machine/user) are deleted and
# regenerated automatically.

set -euo pipefail

# ---------------------------------------------------------------- settings ---
QT_VERSION="${QT_VERSION:-6.10.3}"
QT_ROOT="${QT_ROOT:-$HOME/Qt}"
QT_DIR="$QT_ROOT/$QT_VERSION/gcc_64"
# Extra Qt modules the client needs on top of the aqt base install
# (Core5Compat, WebSockets: required; HttpServer: used by some tests).
QT_MODULES=(qt5compat qtwebsockets qthttpserver qtimageformats)

DEPS_PREFIX="${DEPS_PREFIX:-$HOME/kde6-deps}"   # where our self-built deps get installed
DEPS_SRC="${DEPS_SRC:-$HOME/kde6-deps-src}"     # where their sources get cloned

# Deps are built from source against our Qt (the Ubuntu packages link against
# the system Qt, which may not match QT_VERSION).
KF_REF="${KF_REF:-v6.24.0}"            # ECM + KArchive
KDSA_REF="${KDSA_REF:-v1.2.0}"         # KDSingleApplication
QTKEYCHAIN_REF="${QTKEYCHAIN_REF:-}"   # empty = default branch

LOCAL_SERVER_URL="${LOCAL_SERVER_URL:-http://localhost:8080}"

# Keep in sync with .github/workflows/linux-appimage.yml
APPIMAGE_DOCKER_IMAGE="${APPIMAGE_DOCKER_IMAGE:-ghcr.io/nextcloud/continuous-integration-client-appimage-qt6:client-appimage-el8-6.10.2-4}"
APPIMAGE_EXE="cmc"   # APPLICATION_EXECUTABLE of the release (non-dev) build
APPIMAGE_INSTALL_DIR="${APPIMAGE_INSTALL_DIR:-$HOME/Applications}"

APT_PACKAGES=(
    build-essential cmake ninja-build gcc g++ clang git pkg-config
    python3 python3-venv pipx inkscape
    libssl-dev libsqlite3-dev zlib1g-dev libsecret-1-dev libp11-dev
    libbz2-dev liblzma-dev libzstd-dev
    libgl-dev libxkbcommon-dev libxcb-cursor0
    libcmocka-dev
)

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PREFIX_PATH="$DEPS_PREFIX;$QT_DIR"
APP_EXE="cmcdev"                                        # APPLICATION_EXECUTABLE with NEXTCLOUD_DEV=ON
APP_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/CMCDev"  # APPLICATION_SHORTNAME
APP_CONFIG_FILE="$APP_CONFIG_DIR/$APP_EXE.cfg"
JOBS="$(nproc)"

# ----------------------------------------------------------------- helpers ---
if [[ -t 1 ]]; then
    C_INFO=$'\e[1;34m' C_OK=$'\e[1;32m' C_WARN=$'\e[1;33m' C_ERR=$'\e[1;31m' C_OFF=$'\e[0m'
else
    C_INFO="" C_OK="" C_WARN="" C_ERR="" C_OFF=""
fi
info() { echo "${C_INFO}==>${C_OFF} $*"; }
ok()   { echo "${C_OK}✔${C_OFF}  $*"; }
warn() { echo "${C_WARN}!${C_OFF}  $*"; }
die()  { echo "${C_ERR}✘  $*${C_OFF}" >&2; exit 1; }

# ask "Question" default(y|n) -> returns 0 for yes
ask() {
    local prompt="$1" default="${2:-n}" reply hint="[y/N]"
    [[ $default == y ]] && hint="[Y/n]"
    read -r -p "$prompt $hint " reply || true
    reply="${reply:-$default}"
    [[ ${reply,,} == y* ]]
}

# choose "Title" option1 option2 ... -> echoes the chosen index (1-based)
choose() {
    local title="$1"; shift
    local i reply
    echo >&2
    echo "$title" >&2
    i=1
    for opt in "$@"; do echo "  $i) $opt" >&2; i=$((i + 1)); done
    while true; do
        read -r -p "Choice [1-$#]: " reply || exit 1
        if [[ $reply =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= $#)); then
            echo "$reply"; return
        fi
        echo "Please type a number between 1 and $#." >&2
    done
}

cache_get() {  # cache_get <build dir> <VAR>
    sed -n "s/^$2:[A-Z]*=//p" "$1/CMakeCache.txt" | head -n1
}

canon() { realpath -m "$1" 2>/dev/null || echo "$1"; }

# Deletes a build folder when its CMake cache was generated somewhere else
# (different source/build path) or with different dependency paths.
ensure_fresh_build_dir() {
    local dir="$1" src="$2" prefix_path="${3:-}"
    [[ -f $dir/CMakeCache.txt ]] || return 0
    local reason=""
    if [[ $(canon "$(cache_get "$dir" CMAKE_HOME_DIRECTORY)") != "$(canon "$src")" ]]; then
        reason="it was generated for source $(cache_get "$dir" CMAKE_HOME_DIRECTORY)"
    elif [[ $(canon "$(cache_get "$dir" CMAKE_CACHEFILE_DIR)") != "$(canon "$dir")" ]]; then
        reason="it was generated in $(cache_get "$dir" CMAKE_CACHEFILE_DIR)"
    elif [[ -n $prefix_path && $(cache_get "$dir" CMAKE_PREFIX_PATH) != "$prefix_path" ]]; then
        reason="it uses CMAKE_PREFIX_PATH=$(cache_get "$dir" CMAKE_PREFIX_PATH)"
    fi
    if [[ -n $reason ]]; then
        warn "Deleting stale build folder $dir ($reason)"
        rm -rf "$dir" 2>/dev/null \
            || die "Could not delete $dir (probably created by a sudo run). Remove it with: sudo rm -rf '$dir'"
    fi
}

has_cmake_package() {  # has_cmake_package <prefix> <ConfigFileName>
    [[ -d $1 ]] && [[ -n $(find "$1" -name "$2" -print -quit 2>/dev/null) ]]
}

# ----------------------------------------------------------------- install ---
install_apt_packages() {
    info "Checking system packages"
    local missing=() pkg
    for pkg in "${APT_PACKAGES[@]}"; do
        dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" || missing+=("$pkg")
    done
    if ((${#missing[@]} == 0)); then
        ok "All system packages installed"
        return
    fi
    info "Installing: ${missing[*]} (needs sudo)"
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
    ok "System packages installed"
}

install_qt() {
    info "Checking Qt $QT_VERSION in $QT_DIR"
    if [[ -d $QT_DIR/lib/cmake/Qt6Core5Compat && -d $QT_DIR/lib/cmake/Qt6WebSockets \
          && -d $QT_DIR/lib/cmake/Qt6HttpServer ]]; then
        ok "Qt $QT_VERSION with required modules already installed"
        return
    fi
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v aqt >/dev/null; then
        info "Installing aqtinstall with pipx"
        pipx install aqtinstall
        pipx ensurepath >/dev/null || true
    fi
    info "Downloading Qt $QT_VERSION + ${QT_MODULES[*]} (this takes a while)"
    aqt install-qt linux desktop "$QT_VERSION" linux_gcc_64 -m "${QT_MODULES[@]}" -O "$QT_ROOT"
    [[ -d $QT_DIR/lib/cmake/Qt6Core ]] || die "Qt install failed: $QT_DIR not found"
    ok "Qt installed in $QT_DIR"
}

# build_dep <name> <git url> <ref> <config file that proves it's installed> [extra cmake args...]
build_dep() {
    local name="$1" url="$2" ref="$3" marker="$4"; shift 4
    if has_cmake_package "$DEPS_PREFIX" "$marker"; then
        ok "$name already installed in $DEPS_PREFIX"
        return
    fi
    info "Building $name ${ref:-(default branch)}"
    local src="$DEPS_SRC/$name"
    rm -rf "$src"
    mkdir -p "$DEPS_SRC"
    if [[ -n $ref ]]; then
        git clone --depth 1 --branch "$ref" "$url" "$src"
    else
        git clone --depth 1 "$url" "$src"
    fi
    cmake -S "$src" -B "$src/build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="$PREFIX_PATH" \
        -DCMAKE_INSTALL_PREFIX="$DEPS_PREFIX" \
        -DBUILD_TESTING=OFF \
        "$@"
    cmake --build "$src/build" -j"$JOBS"
    cmake --install "$src/build"
    ok "$name installed"
}

install_deps() {
    build_dep ECM https://invent.kde.org/frameworks/extra-cmake-modules.git "$KF_REF" \
        ECMConfig.cmake -DBUILD_DOC=OFF -DBUILD_HTML_DOCS=OFF -DBUILD_MAN_DOCS=OFF -DBUILD_QTHELP_DOCS=OFF
    build_dep KArchive https://invent.kde.org/frameworks/karchive.git "$KF_REF" \
        KF6ArchiveConfig.cmake -DBUILD_QCH=OFF
    build_dep KDSingleApplication https://github.com/KDAB/KDSingleApplication.git "$KDSA_REF" \
        KDSingleApplication-qt6Config.cmake -DKDSingleApplication_QT6=ON -DKDSingleApplication_EXAMPLES=OFF
    build_dep QtKeychain https://github.com/frankosterfeld/qtkeychain.git "$QTKEYCHAIN_REF" \
        Qt6KeychainConfig.cmake -DBUILD_WITH_QT6=ON -DBUILD_TRANSLATIONS=OFF
}

do_install() {
    install_apt_packages
    install_qt
    install_deps
    ok "All requirements installed"
}

requirements_ok() {
    [[ -d $QT_DIR/lib/cmake/Qt6Core5Compat ]] \
        && has_cmake_package "$DEPS_PREFIX" ECMConfig.cmake \
        && has_cmake_package "$DEPS_PREFIX" KF6ArchiveConfig.cmake \
        && has_cmake_package "$DEPS_PREFIX" KDSingleApplication-qt6Config.cmake \
        && has_cmake_package "$DEPS_PREFIX" Qt6KeychainConfig.cmake
}

# ------------------------------------------------------------- build / run ---
# Production and local builds live in separate folders because the server URL
# is baked in at configure time; switching between them is then just a rebuild.
build_dir_for() {
    if [[ $1 == local ]]; then
        echo "$SRC_DIR/build/QT_${QT_VERSION//./_}-Debug-local"
    else
        echo "$SRC_DIR/build/QT_${QT_VERSION//./_}-Debug"
    fi
}

do_configure() {
    local target="$1" dir
    dir="$(build_dir_for "$target")"
    ensure_fresh_build_dir "$dir" "$SRC_DIR" "$PREFIX_PATH"

    local args=(
        -S "$SRC_DIR" -B "$dir"
        -DCMAKE_PREFIX_PATH="$PREFIX_PATH"
        -DCMAKE_BUILD_TYPE=Debug
        -DCMAKE_INSTALL_PREFIX=.
        -DNEXTCLOUD_DEV=ON
    )
    # Only pick a generator for new build folders; existing ones keep theirs.
    if [[ ! -f $dir/CMakeCache.txt ]] && command -v ninja >/dev/null; then
        args+=(-G Ninja)
    fi
    if [[ $target == local ]]; then
        args+=(-DAPPLICATION_SERVER_URL="$LOCAL_SERVER_URL")
    else
        args+=(-UAPPLICATION_SERVER_URL)   # fall back to the default in NEXTCLOUD.cmake
    fi
    info "Configuring ($target) in $dir"
    cmake "${args[@]}"
}

do_build() {
    local target="$1"
    if ! requirements_ok; then
        warn "Some requirements are missing."
        if [[ $INTERACTIVE == 1 ]] && ask "Install them now?" y; then
            do_install
        else
            die "Run: $0 install"
        fi
    fi
    do_configure "$target"
    info "Building ($target)"
    cmake --build "$(build_dir_for "$target")" --target nextcloud -j"$JOBS"
    ok "Build finished: $(build_dir_for "$target")/bin/$APP_EXE"
}

reset_config() {
    if [[ -f $APP_CONFIG_FILE ]]; then
        rm -f "$APP_CONFIG_FILE"
        ok "Deleted $APP_CONFIG_FILE (the first-run wizard will show)"
    else
        ok "No config to reset ($APP_CONFIG_FILE does not exist)"
    fi
}

do_run() {
    local target="$1" reset="$2" exe
    exe="$(build_dir_for "$target")/bin/$APP_EXE"
    [[ -x $exe ]] || die "$exe not found, build first"
    # Only one instance can run; close a previous dev instance so the new build is the one that starts.
    if pgrep -x "$APP_EXE" >/dev/null; then
        info "Stopping running $APP_EXE"
        pkill -x "$APP_EXE" || true
        sleep 1
    fi
    [[ $reset == 1 ]] && reset_config
    info "Running $exe ($target)  — logs: $APP_CONFIG_DIR/logs"
    "$exe" || warn "$APP_EXE exited with code $?"
}

do_clean() {
    local dirs=("$SRC_DIR"/build/*/)
    if [[ ! -e ${dirs[0]} ]]; then
        ok "Nothing to clean"
        return
    fi
    echo "Build folders:"
    printf '  %s\n' "${dirs[@]}"
    if [[ $INTERACTIVE == 0 ]] || ask "Delete all of them?" n; then
        rm -rf "${dirs[@]}"
        ok "Deleted"
    fi
}

do_appimage() {
    command -v docker >/dev/null || die "Docker is not installed (https://docs.docker.com/engine/install/ubuntu/)"
    docker info >/dev/null 2>&1 || die "Docker is not running or not accessible by $USER"

    local dist="$SRC_DIR/dist" buildnr
    # MIRALL_VERSION_BUILD must be an integer; the commit count grows with every commit.
    buildnr="$(git -C "$SRC_DIR" rev-list --count HEAD 2>/dev/null || echo 0)"
    # Each (unity) compile job needs up to ~2.5 GB, and Docker Desktop's VM usually has
    # far less RAM than the machine has cores, so cap the jobs to avoid OOM kills.
    local docker_mem jobs
    docker_mem="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
    jobs=$(( docker_mem / (2500 * 1024 * 1024) ))
    ((jobs >= 1)) || jobs=1
    ((jobs <= JOBS)) || jobs=$JOBS
    if docker ps --format '{{.Image}}' | grep -qF "$APPIMAGE_DOCKER_IMAGE"; then
        die "Another AppImage build is already running (docker ps). Wait for it or stop it first."
    fi
    mkdir -p "$dist"
    rm -f "$SRC_DIR"/*.AppImage
    info "Building the AppImage in Docker ($APPIMAGE_DOCKER_IMAGE), $jobs parallel jobs — this takes a while"
    # The build script runs as root inside the container and drops the AppImage
    # in the repo root; hand it back to the current user afterwards.
    docker run --rm \
        -v "$SRC_DIR:/nextcloud-client" \
        -e BUILDNR="$buildnr" \
        -e CMAKE_BUILD_PARALLEL_LEVEL="$jobs" \
        -e DESKTOP_CLIENT_ROOT=/nextcloud-client \
        -e EXECUTABLE_NAME="$APPIMAGE_EXE" \
        -e QT_BASE_DIR=/root/linux-gcc-x86_64 \
        "$APPIMAGE_DOCKER_IMAGE" \
        /bin/bash -c "/nextcloud-client/admin/linux/build-appimage.sh; rc=\$?; chown $(id -u):$(id -g) /nextcloud-client/*.AppImage 2>/dev/null; exit \$rc"

    local img
    img="$(find "$SRC_DIR" -maxdepth 1 -name '*.AppImage' -print -quit)"
    [[ -n $img ]] || die "AppImage build failed (no .AppImage produced)"
    mv -f "$img" "$dist/"
    chmod +x "$dist/$(basename "$img")"
    ok "AppImage ready: $dist/$(basename "$img")"

    if [[ $INTERACTIVE == 1 ]] && ask "Add it to your app menu (install to $APPIMAGE_INSTALL_DIR)?" y; then
        do_appimage_install
    fi
}

# Copies the AppImage to a fixed path (so the menu entry and the client's own
# "launch on startup" entry keep working after reinstalls) and registers it
# with the desktop, using the .desktop file and icon embedded in the AppImage.
# Mirrors installAppImageDesktopEntry() in src/common/utility_unix.cpp, which
# does the same on every start of the AppImage (file names must match so both
# update the same entry).
do_appimage_install() {
    local img
    img="$(ls -t "$SRC_DIR"/dist/*.AppImage 2>/dev/null | head -n1)"
    [[ -n $img ]] || die "No AppImage in $SRC_DIR/dist — build one first: $0 appimage"

    local target="$APPIMAGE_INSTALL_DIR/CMC.AppImage"
    local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    local apps_dir="$data_home/applications"
    local icon_dir="$data_home/icons/hicolor/512x512/apps"
    mkdir -p "$APPIMAGE_INSTALL_DIR" "$apps_dir" "$icon_dir"

    # Copy then rename, so replacing an AppImage that is currently running works.
    cp "$img" "$target.tmp"
    chmod +x "$target.tmp"
    mv -f "$target.tmp" "$target"

    local tmp
    tmp="$(mktemp -d)"
    (cd "$tmp" && "$target" --appimage-extract 'usr/share/applications/*.desktop' >/dev/null \
               && "$target" --appimage-extract 'usr/share/icons/hicolor/512x512/apps/*' >/dev/null)
    local embedded_desktop embedded_icon app_id
    embedded_desktop="$(find "$tmp/squashfs-root/usr/share/applications" -name '*.desktop' -print -quit)"
    embedded_icon="$(find "$tmp/squashfs-root/usr/share/icons/hicolor/512x512/apps" -name '*.png' -print -quit)"
    [[ -n $embedded_desktop && -n $embedded_icon ]] || { rm -rf "$tmp"; die "Could not read the .desktop file/icon from $target"; }
    app_id="$(basename "$embedded_desktop" .desktop)"   # LINUX_APPLICATION_ID

    cp "$embedded_icon" "$icon_dir/$app_id.png"
    # Point every Exec line (main entry + actions like "Quit") at the installed AppImage;
    # TryExec hides the entry if the AppImage is removed.
    sed -E -e "s|^Exec=$APPIMAGE_EXE( \|$)|Exec=\"$target\"\1|" \
        -e "s|^Icon(\[[^]]*\])?=.*|Icon\1=$app_id|" \
        -e "s|^\[Desktop Entry\]$|&\nTryExec=$target|" \
        "$embedded_desktop" > "$apps_dir/$app_id.desktop"
    rm -rf "$tmp"

    # Entry created by earlier versions of this script under a different name.
    rm -f "$apps_dir/cmc-desktop.desktop" "$icon_dir/cmc-desktop.png"

    update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
    gtk-update-icon-cache -q -t "$data_home/icons/hicolor" >/dev/null 2>&1 || true
    ok "Installed $target"
    ok "App menu entry: $apps_dir/$app_id.desktop (search for \"CMC\" in your apps)"
}

# Build and/or run, then (interactively) offer to repeat so code changes can be
# tested again without going through the menu.
build_run_loop() {
    local action="$1" target="$2" reset="$3"
    while true; do
        [[ $action == build || $action == build-run ]] && do_build "$target"
        [[ $action == run || $action == build-run ]] && do_run "$target" "$reset"
        [[ $INTERACTIVE == 1 ]] || return 0
        case "$(choose "What next?" \
                "Rebuild & run again" \
                "Reset config, rebuild & run again (fresh first-run wizard)" \
                "Quit")" in
            1) action=build-run; reset=0 ;;
            2) action=build-run; reset=1 ;;
            3) return 0 ;;
        esac
    done
}

# -------------------------------------------------------------------- main ---
main() {
    local action="" target="prod" reset=0

    # Everything lives under $HOME; under sudo that would be /root. The script
    # calls sudo itself for the apt step.
    ((EUID != 0)) || die "Do not run this script with sudo or as root; run it as your normal user (it asks for sudo when needed)."
    INTERACTIVE=0

    while (($#)); do
        case "$1" in
            install|build|run|build-run|appimage|appimage-install|clean) action="$1" ;;
            --local) target=local ;;
            --prod)  target=prod ;;
            --reset) reset=1 ;;
            -h|--help) sed -n '/^# Dev helper/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
            *) die "Unknown argument: $1 (see --help)" ;;
        esac
        shift
    done

    if [[ -z $action ]]; then
        INTERACTIVE=1
        case "$(choose "CMC desktop client — what do you want to do?" \
                "Install requirements only" \
                "Build" \
                "Build & run" \
                "Run (without building)" \
                "Build installer (AppImage, production server)" \
                "Add the built AppImage to the app menu" \
                "Delete build folders")" in
            1) action=install ;;
            2) action=build ;;
            3) action=build-run ;;
            4) action=run ;;
            5) action=appimage ;;
            6) action=appimage-install ;;
            7) action=clean ;;
        esac
        if [[ $action == build || $action == run || $action == build-run ]]; then
            case "$(choose "Which server should the client use?" \
                    "Production (https://nc.cloudmail.city/)" \
                    "Local test server ($LOCAL_SERVER_URL)")" in
                1) target=prod ;;
                2) target=local ;;
            esac
        fi
        if [[ $action == run || $action == build-run ]]; then
            ask "Reset client config first (shows the first-run wizard again)?" n && reset=1
        fi
    fi

    case "$action" in
        install) do_install ;;
        clean)    do_clean ;;
        appimage) do_appimage ;;
        appimage-install) do_appimage_install ;;
        *)       build_run_loop "$action" "$target" "$reset" ;;
    esac
}

main "$@"
