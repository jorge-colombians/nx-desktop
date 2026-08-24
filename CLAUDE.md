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
- **Buttons** (`WizardButton.qml`): primary buttons get a hover-lightened background (`Qt.lighter(..., 1.12)`), animated shadow lift on hover, `scale: down ? 0.97 : (hovered ? 1.02 : 1.0)`. Never redeclare `hovered` as a custom property — `BasicControls.Button` already exposes it as `FINAL`; just set `hoverEnabled: true` and read `root.hovered`.
- **Text fields**: focus state = border widens to 2px and turns `Style.ncBlue`, both animated (`Behavior on border.color/width`, ~120ms).
- **Always animate state transitions** — every hover, focus, press, and screen-entrance change should have a `Behavior`/`NumberAnimation`/`ColorAnimation`, typically 100-340ms with `Easing.OutCubic` (small UI transitions) or `Easing.OutBack` with `easing.overshoot: 4-6` (entrance pops for cards/badges). Don't ship a static, un-animated screen — this is a deliberate product decision, not optional polish.
- **Screen entrance pattern**: root `Item` fades in (`opacity 0→1`, ~260ms `OutCubic`); hero/badge elements additionally scale in from ~0.4-0.97 with `OutBack` overshoot, staggered a beat after the root fade using `PauseAnimation` inside a `SequentialAnimation`.
- Removed "Self-host" wizard button/docs link (`openSelfHostedServerGuide`) — server is fixed to CMC, so self-hosting instructions don't apply. Don't re-add unless the enforced-URL branding changes.

## Testing changes

Rebuild + run (Debug config already configured for Qt 6.10.3):

```bash
cmake --build "<repo>/build/QT_6_10_3-Debug" --target nextcloud -j$(nproc) && "<repo>/build/QT_6_10_3-Debug/bin/nextcloud"
```

QML load failures are logged as warnings, not crashes — the app silently falls back to tray-only with no console error. Always check `~/.config/Nextcloud/logs/<latest>.log.0` for `Failed to load QML` after any wizard QML change, don't just eyeball that the process is still running.

Delete `~/.config/Nextcloud/nextcloud.cfg` between test runs to re-trigger the first-run wizard instead of going straight to tray.
