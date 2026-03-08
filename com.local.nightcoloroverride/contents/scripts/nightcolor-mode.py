#!/usr/bin/env python3
"""
nightcolor-mode.py — Night Color Override daemon for KDE Plasma 6 (Wayland)

Holds a D-Bus session connection to KWin's NightLight interface and
periodically re-calls preview() to keep the colour temperature override alive.
Calls stopPreview() on exit so Night Color resumes its normal schedule.

Usage:
    python3 nightcolor-mode.py --temp 4000 [--duration 45]

    --temp KELVIN       Target colour temperature (1500–6500)
    --duration MINUTES  How long to hold (0 = indefinite, default: 0)

Dependency: python-dbus  (sudo pacman -S python-dbus)
"""

import argparse
import signal
import sys
import time

try:
    import dbus
except ImportError:
    print("ERROR: python-dbus not installed. Run: sudo pacman -S python-dbus", file=sys.stderr)
    sys.exit(1)

DBUS_SERVICE = "org.kde.KWin"
DBUS_PATH = "/org/kde/KWin/NightLight"
DBUS_IFACE = "org.kde.KWin.NightLight"
REFRESH_INTERVAL = 8  # seconds between preview() re-calls


def get_nightlight_iface():
    bus = dbus.SessionBus()
    obj = bus.get_object(DBUS_SERVICE, DBUS_PATH)
    return dbus.Interface(obj, DBUS_IFACE)


def main():
    parser = argparse.ArgumentParser(description="KDE Night Color override daemon")
    parser.add_argument("--temp", type=int, required=True,
                        help="Colour temperature in Kelvin (1500–6500)")
    parser.add_argument("--duration", type=int, default=0,
                        help="Duration in minutes (0 = indefinite)")
    args = parser.parse_args()

    temp = max(1500, min(6500, args.temp))
    duration_secs = args.duration * 60 if args.duration > 0 else 0

    try:
        iface = get_nightlight_iface()
    except dbus.DBusException as e:
        print(f"ERROR: Could not connect to KWin NightLight D-Bus interface: {e}", file=sys.stderr)
        sys.exit(1)

    def cleanup(signum=None, frame=None):
        try:
            iface.stopPreview()
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    # Initial preview call
    try:
        iface.preview(dbus.UInt32(temp))
    except dbus.DBusException as e:
        print(f"ERROR: preview() call failed: {e}", file=sys.stderr)
        sys.exit(1)

    start_time = time.monotonic()

    while True:
        time.sleep(REFRESH_INTERVAL)

        elapsed = time.monotonic() - start_time

        if duration_secs > 0 and elapsed >= duration_secs:
            cleanup()

        try:
            iface.preview(dbus.UInt32(temp))
        except dbus.DBusException as e:
            print(f"WARNING: preview() re-call failed: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
