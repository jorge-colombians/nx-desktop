# CLAUDE.md

Project-specific notes for Claude Code. See `AGENTS.md` for contribution policy, licensing, and commit/PR conventions — this file covers active UI work conventions only.

## Branding

- App is branded **CMC** (Cloudmail City), not "Nextcloud", in user-facing wizard strings.
- Production server is locked via `NEXTCLOUD.cmake` (`APPLICATION_SERVER_URL` + `APPLICATION_SERVER_URL_ENFORCE`) to `https://nc.cloudmail.city/`. For local testing, reconfigure with `-DAPPLICATION_SERVER_URL="http://localhost:8080"` (requires re-running `cmake -S/-B`, not just rebuild).
- Company logo lives at `theme/colored/company-logo.jpg`, referenced in QML as `qrc:/client/theme/colored/company-logo.jpg`.

## Wizard QML style guide (`src/gui/wizard/qml/`)

Building a consistent, modern look across the account wizard. Match these conventions in any new/edited wizard screen:

- **Hero/badge gradient**: `Style.ncBlue`-based 3-stop horizontal gradient (`Qt.lighter(..., 1.35)` top → `Qt.lighter(..., 1.15)` mid at 0.55 → `Qt.darker(..., 1.1)` bottom), `radius: 22` for full cards / `15` for the logo tile, drop shadow via `layer.effect: MultiEffect` (`shadowBlur: ~0.6-0.7`, `shadowVerticalOffset: ~5-6`, `shadowColor: Qt.rgba(0,0,0,0.22)`).
- **Logo badge**: white/window-background rounded tile (radius 15) containing the company logo masked to radius 11, inside the gradient badge.
- **Buttons** (`WizardButton.qml`): primary buttons get a vertical `Style.ncBlue` gradient fill (10px radius) with a blue-tinted glow shadow that intensifies on hover; secondary buttons get a lighter matching shadow so the set feels cohesive. `scale: down ? 0.97 : (hovered ? 1.02 : 1.0)`.
- **Gotcha — `hovered` is a `FINAL` property.** Both `BasicControls.Button` and `QtQuick.Controls.Control` (so `WizardButton` *and* `OptionRow`) already expose a readonly `hovered` driven by `hoverEnabled`. Never redeclare `property bool hovered: false` on a subtype of either — QML refuses to load the *entire* file tree that references it (silently, as a warning — see Testing section). Just set `hoverEnabled: true` on the root and read the inherited `root.hovered`. Hit this twice already.
- **Text fields**: focus state = border widens to 2px and turns `Style.ncBlue`, both animated (`Behavior on border.color/width`, ~120ms).
- **Always animate state transitions** — every hover, focus, press, and screen-entrance change should have a `Behavior`/`NumberAnimation`/`ColorAnimation`, typically 100-340ms with `Easing.OutCubic` (small UI transitions) or `Easing.OutBack` with `easing.overshoot: 4-6` (entrance pops for cards/badges). Don't ship a static, un-animated screen — this is a deliberate product decision, not optional polish.
- **Screen entrance pattern**: root `Item` fades in (`opacity 0→1`, ~260ms `OutCubic`); hero/badge elements additionally scale in from ~0.4-0.97 with `OutBack` overshoot, staggered a beat after the root fade using `PauseAnimation` inside a `SequentialAnimation`.
- Removed "Self-host" wizard button/docs link (`openSelfHostedServerGuide`) — server is fixed to CMC, so self-hosting instructions don't apply. Don't re-add unless the enforced-URL branding changes.

## Testing changes

Use `./dev-ubuntu.sh` (interactive menu, or e.g. `./dev-ubuntu.sh build-run --local --reset`). It installs requirements, configures, builds and runs the dev build. Manual equivalent (Debug config for Qt 6.10.3):

```bash
cmake --build "<repo>/build/QT_6_10_3-Debug" --target nextcloud -j$(nproc) && "<repo>/build/QT_6_10_3-Debug/bin/cmcdev"
```

The CMake target is still `nextcloud`, but since the CMC rebrand the dev binary is `cmcdev` and its config lives in `~/.config/CMCDev/`.

QML load failures are logged as warnings, not crashes — the app silently falls back to tray-only with no console error. Always check `~/.config/CMCDev/logs/<latest>.log.0` for `Failed to load QML` after any wizard QML change, don't just eyeball that the process is still running.

Delete `~/.config/CMCDev/cmcdev.cfg` (or pass `--reset` to the script) between test runs to re-trigger the first-run wizard instead of going straight to tray.

### Windows

Use `.\dev-windows.ps1` (interactive menu, or e.g. `.\dev-windows.ps1 build-run -Local -Reset`). Unlike Ubuntu, Windows deps (Qt, KArchive, QtKeychain, ...) must be built with the real MSVC toolset, so the whole flow goes through [KDE Craft](https://community.kde.org/Craft) instead of a manual cmake configure — `install` sets up winget packages (Git, Python, Inkscape, VS2022 Build Tools) plus Craft itself, `build`/`run`/`build-run` produce the dev build (`cmcdev.exe`), `test` runs ctest, and `installer` produces the real NSIS/MSI (`cmc.exe`) into `dist\`.

The script auto-patches the known CMC-rebrand gaps in the upstream `craft-blueprints-nextcloud` repo (missing `import os`, the `cmc`/`cmccmd` exe blacklist pattern, and branding fields) — see `README.md`'s "Windows (NSIS/MSI installer)" section for the underlying issue if a patch ever needs updating for a newer blueprint branch.

Config/logs live under `%APPDATA%\CMCDev\` (dev build) — same `Failed to load QML` caveat as Ubuntu applies here too.
