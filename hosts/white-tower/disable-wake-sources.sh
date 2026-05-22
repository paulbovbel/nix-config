#!/usr/bin/env bash
set -euo pipefail

if [ -r /proc/acpi/wakeup ]; then
  while read -r dev _ state _; do
    if [ "${state}" = "*enabled" ] && [ "${dev}" != "PWRB" ] && [ "${dev}" != "PWRF" ]; then
      printf '%s\n' "${dev}" > /proc/acpi/wakeup
    fi
  done < /proc/acpi/wakeup
fi

for wakeup in /sys/class/wakeup/*/device/power/wakeup; do
  [ -e "${wakeup}" ] || continue
  case "${wakeup}" in
    */PWRB/*|*/PWRF/*) ;;
    *) printf 'disabled\n' > "${wakeup}" ;;
  esac
done

primary_if="$(ip route show default | head -n1 | grep -oE 'dev [^ ]+' | cut -d' ' -f2 || true)"
if [ -n "${primary_if}" ] && [ -e "/sys/class/net/${primary_if}/device/power/wakeup" ]; then
  printf 'enabled\n' > "/sys/class/net/${primary_if}/device/power/wakeup"
  ethtool -s "${primary_if}" wol g || true
fi
