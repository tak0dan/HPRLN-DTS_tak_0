#!/usr/bin/env bash
# /* ---- 💫 https://github.com/LinuxBeginnings 💫 ---- */  ##
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
