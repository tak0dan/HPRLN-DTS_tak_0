#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Ubuntu 26.04 workaround: start portals manually before waybar.

set -euo pipefail

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "26.04" ]]; then
    if [[ -x "$HOME/.config/hypr/scripts/PortalHyprland.sh" ]]; then
      "$HOME/.config/hypr/scripts/PortalHyprland.sh"
    fi
  fi
fi
