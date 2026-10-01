"""Inhibit fprintd while a USB_Keyboard is connected."""

import argparse
import logging
import subprocess
import sys

import pyudev
from systemd.daemon import notify


logger = logging.getLogger("keyboard-policy")


def has_external_keyboard(devices):
    keyboards = [
        device
        for device in devices
        if device.sys_name.startswith("event")
        and device.get("ID_INPUT_KEYBOARD") == "1"
        and device.get("ID_BUS") == "usb"
        and device.get("ID_MODEL") == "USB_Keyboard"
    ]
    logger.info(
        "USB_Keyboard devices detected (%d): %s",
        len(keyboards),
        ", ".join(device.sys_name for device in keyboards) or "none",
    )
    return bool(keyboards)


def apply_policy(connected):
    if connected:
        logger.info(
            "USB_Keyboard connected: disabling fingerprint authentication; "
            "running systemctl stop fprintd.service"
        )
        subprocess.run(["systemctl", "stop", "fprintd.service"], check=True)
    else:
        # fprintd may be unloaded; its ExecCondition permits the next request.
        logger.info("No USB_Keyboard connected: allowing fingerprint authentication")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit 1 if a USB_Keyboard is connected, otherwise 0",
    )
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    context = pyudev.Context()
    if args.check:
        connected = has_external_keyboard(context.list_devices(subsystem="input"))
        logger.info(
            "Fingerprint startup %s",
            "skipped: external keyboard connected" if connected else "allowed",
        )
        return int(connected)

    monitor = pyudev.Monitor.from_netlink(context)
    monitor.filter_by(subsystem="input")
    # Subscribe before enumerating so hotplug during startup cannot be missed.
    monitor.start()
    connected = has_external_keyboard(context.list_devices(subsystem="input"))
    apply_policy(connected)
    notify("READY=1")
    logger.info("Watching input-device hotplug events")

    for device in iter(monitor.poll, None):
        logger.info("Input device event: %s %s", device.action, device.sys_name)
        current = has_external_keyboard(context.list_devices(subsystem="input"))
        if current != connected:
            apply_policy(current)
            connected = current


if __name__ == "__main__":
    sys.exit(main())
