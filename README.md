# Night Color Override — KDE Plasma 6 Plasmoid

A minimal system tray plasmoid for KDE Plasma 6 (Wayland) that provides timed overrides of KWin's Night Color colour temperature. Replaces "movie mode" and similar presets that KDE's built-in Night Color widget doesn't offer.

Set a temperature and duration, hit Apply, and Night Color resumes its normal schedule when the timer expires or you cancel manually.

## Why this exists

KDE Plasma 6 on Wayland has no third-party colour temperature tools — Gammastep and Redshift require `wlr-gamma-control-unstable-v1`, which KWin does not implement. KWin manages its own gamma pipeline exclusively via D-Bus. This plasmoid talks directly to that interface.

## Requirements

- KDE Plasma 6 (Wayland)
- `python-dbus` — the keepalive daemon uses it to talk to KWin

```bash
sudo pacman -S python-dbus
```

## Installation

### Clone the repo

```bash
git clone https://github.com/Tealdragon204/flux-kde-plasma.git
cd flux-kde-plasma
```

### Install the plasmoid

```bash
bash install.sh
```

Then right-click the system tray → **Add Widgets** → search **Night Color Override**.

## Usage

1. Click the tray icon to open the popup
2. Drag the **Temperature** slider (1500–6500 K)
3. Drag the **Duration** slider (0 = hold until cancelled, up to 4 hours)
4. Click **Apply Override**
5. Click **Cancel** or wait for the timer to restore your normal Night Color schedule

## How it works

Two components:

- **`nightcolor-mode.py`** — a background daemon that holds a D-Bus connection to `org.kde.KWin /org/kde/KWin/NightLight` and re-calls `preview(temp)` every 8 seconds. KWin drops the preview when the connection closes, so the daemon must stay running. On exit (timeout or SIGTERM) it calls `stopPreview()` to cleanly restore the schedule.

- **`main.qml`** — the Plasma 6 plasmoid. Launches the daemon as a background subprocess, captures its PID, runs a 1-second countdown timer, and polls `currentTemperature` every 5 seconds to display the live KWin state.

## Uninstalling

```bash
rm -rf ~/.local/share/plasma/plasmoids/com.local.nightcoloroverride
```

## License

GPL-3.0 — see [LICENSE](LICENSE)
