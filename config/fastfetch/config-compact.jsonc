#!/usr/bin/env bash
set -Eeuo pipefail

# Ubuntu setup of common apps and configuration (based on debian-setup.sh)
# - Colors, iconography, robust error handling
# - Checks /mnt/nas and copies configs if available
# - Optional modes: --config-only, --apps-only, --dry-run
# - Uses nala when available, falls back to apt
# - Prompts to run apt update/upgrade before and after

# ------------- Config -------------
NAS_MOUNT="/mnt/nas"
NAS_CONFIG_DIR="$NAS_MOUNT/config.files"
DRY_RUN=0
CONFIG_ONLY=0
APPS_ONLY=0
SKIP_ALL=0
INSTALL_DMS=0
DMS_ONLY=0
DMS_SRC=""
DMS_WORKDIR="$HOME/.local/src/dms"
APT_ONLY=0

# Selective install toggles
WEZTERM_ONLY=0
FONTS_ONLY=0
THEMES_ONLY=0

# ------------- Colors & Icons -------------
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
GRAY="\033[90m"
ICON_INFO="ℹ️"
ICON_OK="✅"
ICON_WARN="⚠️"
ICON_ERR="❌"
ICON_STEP="▶️"

info() { printf "%b%s%b %b%s%b\n" "$BLUE" "$ICON_INFO" "$RESET" "$BOLD" "$*" "$RESET"; }
success() { printf "%b%s%b %s\n" "$GREEN" "$ICON_OK" "$RESET" "$*"; }
warn() { printf "%b%s%b %s\n" "$YELLOW" "$ICON_WARN" "$RESET" "$*"; }
error() { printf "%b%s%b %s\n" "$RED" "$ICON_ERR" "$RESET" "$*" 1>&2; }
step() { printf "%b%s%b %s\n" "$CYAN" "$ICON_STEP" "$RESET" "$*"; }

run() {
  if ((DRY_RUN)); then
    printf "%b+ %s%b\n" "$GRAY" "$(printf '%q ' "$@")" "$RESET"
  else
    "$@"
  fi
}

usage() {
  cat <<'USAGE'
Usage: ubuntu-setup.sh [options]

Options:
  --config-only         Only copy/apply configuration (no package installs)
  --apps-only           Only install/upgrade packages and apps (no config copy)
  --dry-run             Show what would be done without making changes
  --install-dms         Install Dank Material Shell: fonts + dependencies + build Quickshell and required sources; also installs the dms wrapper
  --dms-only            Only install DMS (skip general apps/config); implies --install-dms
  --dms-src PATH        Use existing source tree at PATH for building (auto-detects Meson/CMake/Autotools)
  --wezterm-only        Only install and configure WezTerm (nightly)
  --fonts-only          Only install Nerd Fonts
  --themes-only          Only install GTK and icon themes
  --apt-only            Force using apt (disable nala detection/installation)
  -h, --help            Show this help
USAGE
}

# ------------- Arg parsing -------------
while [[ $# -gt 0 ]]; do
  case "${1}" in
  --config-only)
    CONFIG_ONLY=1
    shift
    ;;
  --apps-only)
    APPS_ONLY=1
    shift
    ;;
  --dry-run)
    DRY_RUN=1
    shift
    ;;
  --install-dms)
    INSTALL_DMS=1
    shift
    ;;
  --dms-only)
    DMS_ONLY=1
    INSTALL_DMS=1
    shift
    ;;
  --dms-src)
    DMS_SRC="${2:-}"
    if [[ -z "$DMS_SRC" ]]; then
      error "--dms-src requires a path"
      exit 2
    fi
    shift 2
    ;;
  --wezterm-only)
    WEZTERM_ONLY=1
    shift
    ;;
  --fonts-only)
    FONTS_ONLY=1
    shift
    ;;
  --themes-only)
    THEMES_ONLY=1
    shift
    ;;
  --apt-only)
    APT_ONLY=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    error "Unknown option: $1"
    usage
    exit 2
    ;;
  esac
done

confirm() {
  local msg=${1:-"Are you sure?"}
  local def=${2:-"y"}
  local prompt="[y/N]"
  [[ "$def" =~ ^[Yy]$ ]] && prompt="[Y/n]"
  local reply
  read -r -p "$msg $prompt " reply || true
  reply=${reply:-$def}
  [[ "$reply" =~ ^[Yy]$ ]]
}

ask_backup_or_skip() {
  local path="$1"
  local reply
  if ((SKIP_ALL)); then
    warn "Skip-All enabled; skipping '$path'"
    return 1
  fi
  while true; do
    read -r -p "'$path' exists. (B)ackup, (S)kip, Skip (A)ll? [B/s/a] " reply || reply="B"
    reply=${reply:-B}
    case "${reply}" in
    B | b) return 0 ;;
    S | s) return 1 ;;
    A | a)
      SKIP_ALL=1
      warn "Skip-All enabled; skipping '$path' and all subsequent conflicts"
      return 1
      ;;
    *) printf "Please answer B, S, or A.\n" ;;
    esac
  done
}

# ------------- /mnt/nas helpers -------------
ensure_nas_available() {
  if [[ -d "$NAS_CONFIG_DIR" ]]; then
    return 0
  fi
  if mountpoint -q "$NAS_MOUNT"; then
    if [[ -d "$NAS_CONFIG_DIR" ]]; then
      return 0
    fi
    warn "$NAS_MOUNT is mounted but $NAS_CONFIG_DIR not found"
  else
    if grep -Eq '^[^#].*\s/mnt/nas\s' /etc/fstab; then
      step "Attempting to mount $NAS_MOUNT from /etc/fstab"
      if run sudo mount "$NAS_MOUNT"; then
        [[ -d "$NAS_CONFIG_DIR" ]] && return 0 || warn "Mounted $NAS_MOUNT but $NAS_CONFIG_DIR not found"
      else
        warn "Failed to mount $NAS_MOUNT"
      fi
    else
      warn "$NAS_MOUNT not mounted and no /etc/fstab entry found"
    fi
  fi
  return 1
}

# ------------- Shell rc helpers -------------
ensure_rc_sources() {
  local bashrc="$HOME/.bashrc" bashrc_personal="$HOME/.bashrc-personal"
  local zshrc="$HOME/.zshrc" zshrc_personal="$HOME/.zshrc-personal"

  if [[ -f "$bashrc_personal" ]]; then
    local line_bash='[ -f "$HOME/.bashrc-personal" ] && source "$HOME/.bashrc-personal"'
    if ! grep -Fq ".bashrc-personal" "$bashrc" 2>/dev/null; then
      step "Adding source of .bashrc-personal to $bashrc"
      if ((DRY_RUN)); then
        printf "Would append to %s: %s\n" "$bashrc" "$line_bash"
      else
        mkdir -p "$(dirname "$bashrc")"
        printf "%s\n" "$line_bash" >>"$bashrc"
      fi
    else
      info "$bashrc already sources .bashrc-personal"
    fi
  fi

  if [[ -f "$zshrc_personal" ]]; then
    local line_zsh='[ -f "$HOME/.zshrc-personal" ] && source "$HOME/.zshrc-personal"'
    if ! grep -Fq ".zshrc-personal" "$zshrc" 2>/dev/null; then
      step "Adding source of .zshrc-personal to $zshrc"
      if ((DRY_RUN)); then
        printf "Would append to %s: %s\n" "$zshrc" "$line_zsh"
      else
        mkdir -p "$(dirname "$zshrc")"
        printf "%s\n" "$line_zsh" >>"$zshrc"
      fi
    else
      info "$zshrc already sources .zshrc-personal"
    fi
  fi
}

backup_then_copy_file() {
  local src="$1" dest="$2"
  if [[ -e "$dest" ]]; then
    if ask_backup_or_skip "$dest"; then
      local ts backup
      ts=$(date +%Y%m%d-%H%M%S)
      backup="${dest}.bak.${ts}"
      step "Backing up $dest -> $backup"
      run mv -v "$dest" "$backup"
    else
      warn "Skipped $dest"
      return 0
    fi
  fi
  run cp -v "$src" "$dest"
}

backup_then_copy_dir() {
  local src="$1" dest="$2"
  if [[ -e "$dest" ]]; then
    if ask_backup_or_skip "$dest"; then
      local ts backup
      ts=$(date +%Y%m%d-%H%M%S)
      backup="${dest}.bak.${ts}"
      step "Backing up $dest -> $backup"
      run mv -v "$dest" "$backup"
    else
      warn "Skipped $dest"
      return 0
    fi
  fi
  run cp -rv "$src" "$dest"
}

copy_config_files() {
  if ! ensure_nas_available; then
    if confirm "Could not access $NAS_CONFIG_DIR. Continue without copying standard config files?" y; then
      warn "Skipping config copy"
      return 0
    else
      error "Aborting per user decision"
      return 1
    fi
  fi

  step "Copying configuration files from $NAS_CONFIG_DIR"

  # Starship
  run mkdir -p "$HOME/.config"
  if [[ -f "$NAS_CONFIG_DIR/Shells/starship/garuda-mokka.starship.toml" ]]; then
    backup_then_copy_file "$NAS_CONFIG_DIR/Shells/starship/garuda-mokka.starship.toml" "$HOME/.config/starship.toml"
  fi

  # Ghostty
  run mkdir -p "$HOME/.config/ghostty"
  if [[ -f "$NAS_CONFIG_DIR/skel/ghostty.config.xerolinux" ]]; then
    backup_then_copy_file "$NAS_CONFIG_DIR/skel/ghostty.config.xerolinux" "$HOME/.config/ghostty/config"
  fi

  # Yazi
  if [[ -d "$NAS_CONFIG_DIR/yazi" ]]; then
    backup_then_copy_dir "$NAS_CONFIG_DIR/yazi" "$HOME/.config/yazi"
    if command -v ya >/dev/null 2>&1; then
      step "Updating Yazi plugins via 'ya pkg upgrade'"
      run ya pkg upgrade || warn "'ya pkg upgrade' failed"
    else
      info "'ya' not found; skipping Yazi plugin upgrade"
    fi
  fi

  # Tmux
  run mkdir -p "$HOME/.config/tmux"
  if [[ -d "$NAS_CONFIG_DIR/skel/tmux/tmux.no.git.folders" ]]; then
    backup_then_copy_dir "$NAS_CONFIG_DIR/skel/tmux/tmux.no.git.folders" "$HOME/.config/tmux"
  elif [[ -f "$NAS_CONFIG_DIR/skel/tmux/tmux.conf.update.tar" ]]; then
    step "Extracting tmux config tar"
    if ((DRY_RUN)); then
      printf "Would extract %s to %s\n" "$NAS_CONFIG_DIR/skel/tmux/tmux.conf.update.tar" "$HOME/.config/tmux"
    else
      tar -xvf "$NAS_CONFIG_DIR/skel/tmux/tmux.conf.update.tar" -C "$HOME/.config/tmux"
    fi
  fi

  # Personal shells
  [[ -f "$NAS_CONFIG_DIR/.bashrc-personal" ]] && backup_then_copy_file "$NAS_CONFIG_DIR/.bashrc-personal" "$HOME/.bashrc-personal"
  [[ -f "$NAS_CONFIG_DIR/.zshrc-personal" ]] && backup_then_copy_file "$NAS_CONFIG_DIR/.zshrc-personal" "$HOME/.zshrc-personal"

  ensure_rc_sources
  success "Config copy complete"
}

# ------------- Fonts (DMS) -------------
ensure_dms_fonts() {
  step "Ensuring fonts required by Dank Material Shell (DMS)"
  run sudo install -d -m 0755 /usr/share/fonts
  local changed=0
  local IFS='|'
  local font
  local FONTS=(
    "Material Symbols Rounded|https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf|/usr/share/fonts/MaterialSymbolsRounded.ttf|Material Symbols Rounded"
    "Inter Variable|https://github.com/rsms/inter/raw/refs/tags/v4.1/docs/font-files/InterVariable.ttf|/usr/share/fonts/InterVariable.ttf|Inter"
    "Fira Code|https://raw.githubusercontent.com/tonsky/FiraCode/main/distr/ttf/FiraCode-Regular.ttf|/usr/share/fonts/FiraCode-Regular.ttf|Fira Code"
  )
  for font in "${FONTS[@]}"; do
    read -r LABEL URL DEST CHECK <<<"$font"
    if fc-list | grep -qi -- "$CHECK"; then
      info "Font '$LABEL' already available"
      continue
    fi
    if [[ -f "$DEST" ]]; then
      info "Font file for '$LABEL' already present at $DEST"
      continue
    fi
    step "Downloading font: $LABEL"
    if run sudo curl -fL "$URL" -o "$DEST"; then
      changed=1
    else
      warn "Failed to download $LABEL"
      if [[ "$LABEL" == "Fira Code" ]]; then
        step "Attempting to install Fira Code via package manager"
        if pkg_install fonts-firacode; then
          changed=1
        else
          warn "fonts-firacode package not available"
        fi
      fi
    fi
  done
  if ((changed)); then
    step "Rebuilding font cache"
    run sudo fc-cache -fv
  else info "No font changes needed"; fi
}

# ------------- DMS install/build (same as debian script) -------------
install_dms_deps() {
  step "Installing DMS build/runtime dependencies"
  pkg_install build-essential gcc make cmake ninja-build git autoconf automake libtool pkg-config
  pkg_install qt6-base-dev qt6-base-dev-tools qt6-declarative-dev qt6-shadertools-dev qt6-declarative-private-dev
  pkg_install qt6-tools-dev qt6-tools-dev-tools qttools5-dev-tools qt6-wayland
  pkg_install libwayland-dev wayland-protocols libxkbcommon-dev libegl1-mesa-dev
  pkg_install libcli11-dev libjemalloc-dev libdbus-1-dev
}

install_dms_binary() {
  step "Installing DMS (prebuilt binary)"
  local arch cmd
  arch=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
  cmd="curl -L https://github.com/AvengeMedia/danklinux/releases/latest/download/dms-${arch}.gz | gunzip | tee /usr/local/bin/dms >/dev/null && chmod +x /usr/local/bin/dms"
  if ((DRY_RUN)); then
    printf "Would run (as root): %s\n" "$cmd"
  else
    sudo sh -c "$cmd"
  fi
}

qs_detect_version() {
  local v
  if command -v quickshell >/dev/null 2>&1; then
    v=$(quickshell --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){1,2}' | head -n1 || true)
    if [[ -z "$v" ]]; then
      v=$(quickshell -v 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){1,2}' | head -n1 || true)
    fi
    printf "%s" "${v}"
  fi
}

version_ge() { dpkg --compare-versions "$1" ge "$2"; }

build_quickshell() {
  local workdir="$DMS_WORKDIR"
  local qs_dir="$workdir/quickshell"
  local qs_url="https://git.outfoxxed.me/quickshell/quickshell.git"
  run mkdir -p "$workdir"
  if [[ -d "$qs_dir/.git" ]]; then
    step "Updating Quickshell in $qs_dir"
    (cd "$qs_dir" && run git fetch --all --prune && run git pull --ff-only)
  else
    step "Cloning Quickshell"
    run git clone "$qs_url" "$qs_dir"
  fi
  step "Configuring Quickshell (CMake + Ninja)"
  run mkdir -p "$qs_dir/build"
  (cd "$qs_dir/build" && run cmake -GNinja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DINSTALL_QMLDIR="$(qtpaths6 -query QT_INSTALL_QML 2>/dev/null || echo /usr/lib/qt6/qml)" ..)
  step "Building Quickshell"
  (cd "$qs_dir/build" && run cmake --build .)
  step "Installing Quickshell"
  (cd "$qs_dir/build" && run sudo cmake --install .)
}

ensure_quickshell_min_version() {
  local min_ver="$1"
  local cur
  cur=$(qs_detect_version || true)
  if [[ -n "$cur" ]] && version_ge "$cur" "$min_ver"; then
    info "Quickshell $cur present (>= $min_ver); skipping build"
    return 0
  fi
  warn "Quickshell not present or < $min_ver; building from source"
  build_quickshell
}

ensure_quickshell_config_dms() {
  local cfg="$HOME/.config/quickshell"
  local dms_dir="$cfg/dms"
  run mkdir -p "$cfg"
  if [[ -d "$dms_dir/.git" ]]; then
    step "Updating DankMaterialShell in $dms_dir"
    (cd "$dms_dir" && run git fetch --all --prune && run git pull --ff-only)
  else
    step "Cloning DankMaterialShell to $dms_dir"
    run git clone https://github.com/AvengeMedia/DankMaterialShell.git "$dms_dir"
  fi
}

ensure_dgop_installed() {
  if command -v dgop >/dev/null 2>&1; then
    info "dgop already installed"
    return 0
  fi
  step "Installing dgop"
  local arch
  arch=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
  local cmd="curl -L https://github.com/AvengeMedia/dgop/releases/latest/download/dgop-linux-${arch}.gz | gunzip | tee /usr/local/bin/dgop > /dev/null && chmod +x /usr/local/bin/dgop"
  if ((DRY_RUN)); then
    printf "Would run (as root): %s\n" "$cmd"
  else
    sudo sh -c "$cmd"
  fi
}

ensure_rustc_cargo() {
  if command -v cargo >/dev/null 2>&1 && command -v rustc >/dev/null 2>&1; then
    return 0
  fi
  step "Installing rust toolchain (rustc, cargo)"
  pkg_install rustc cargo
}

matugen_version() {
  local v
  if command -v matugen >/dev/null 2>&1; then
    v=$(matugen --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){1,2}' | head -n1 || true)
    printf "%s" "$v"
  fi
}

ensure_matugen_min_version() {
  local min_ver="$1"
  local cur
  cur=$(matugen_version || true)
  if [[ -n "$cur" ]] && version_ge "$cur" "$min_ver"; then
    info "matugen $cur present (>= $min_ver)"
    return 0
  fi
  step "Installing matugen via cargo (requires rustc/cargo)"
  ensure_rustc_cargo
  run cargo install matugen
  if [[ -x "$HOME/.cargo/bin/matugen" ]]; then
    if ((DRY_RUN)); then
      printf "Would copy %s to /usr/local/bin\n" "$HOME/.cargo/bin/matugen"
    else
      sudo cp "$HOME/.cargo/bin/matugen" /usr/local/bin/
    fi
  fi
}

build_from_source_generic() {
  local src="$1"
  if [[ -z "$src" || ! -d "$src" ]]; then
    error "Invalid source directory: $src"
    return 1
  fi
  step "Building from source at $src"
  if [[ -f "$src/meson.build" ]]; then
    run meson setup "$src/build" "$src" --buildtype=release
    run meson compile -C "$src/build"
    run sudo meson install -C "$src/build"
  elif [[ -f "$src/CMakeLists.txt" ]]; then
    run cmake -S "$src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release
    run cmake --build "$src/build" -j"$(nproc)"
    run sudo cmake --install "$src/build"
  elif [[ -x "$src/configure" || -f "$src/configure.ac" ]]; then
    (cd "$src" && run ./configure && run make -j"$(nproc)" && run sudo make install)
  else
    warn "Unknown build system in $src; skipping build"
    return 1
  fi
}

git_clone_or_update() {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    step "Updating repo $(basename "$dest")"
    (cd "$dest" && run git fetch --all --prune && run git pull --ff-only)
  else
    step "Cloning $(basename "$dest")"
    run git clone "$url" "$dest"
  fi
  if [[ -f "$dest/.gitmodules" ]]; then
    step "Updating submodules for $(basename "$dest")"
    (cd "$dest" && run git submodule update --init --recursive)
  fi
}

build_breakpad() {
  local workdir="$DMS_WORKDIR"
  local bp_dir="$workdir/breakpad"
  run mkdir -p "$workdir"
  git_clone_or_update https://chromium.googlesource.com/breakpad/breakpad "$bp_dir"
  run mkdir -p "$bp_dir/src/third_party"
  if [[ ! -d "$bp_dir/src/third_party/lss/.git" ]]; then
    run git clone https://chromium.googlesource.com/linux-syscall-support "$bp_dir/src/third_party/lss"
  else
    (cd "$bp_dir/src/third_party/lss" && run git pull --ff-only)
  fi
  (cd "$bp_dir" && run autoreconf -fi && run ./configure && run make -j"$(nproc)")
  run sudo make -C "$bp_dir" install
  run sudo ldconfig || true
}

ensure_breakpad() {
  if pkg-config --exists breakpad 2>/dev/null; then
    info "breakpad already available (pkg-config)"
    return 0
  fi
  step "Installing breakpad development package"
  if pkg_install libbreakpad-dev; then
    if pkg-config --exists breakpad 2>/dev/null; then
      success "breakpad detected via pkg-config after install"
      return 0
    fi
    warn "libbreakpad-dev installed but pkg-config 'breakpad' still not found"
  else
    warn "libbreakpad-dev not available via $PKG_MGR"
  fi
  warn "Falling back to building breakpad from source"
  build_breakpad
  if pkg-config --exists breakpad 2>/dev/null; then
    success "breakpad available after source build"
    return 0
  fi
  error "breakpad still missing; Quickshell build will fail"
  return 1
}

install_dms_sources() {
  ensure_breakpad || true
  ensure_quickshell_min_version "0.2.1"
}

install_dms() {
  install_dms_deps
  install_dms_sources
  ensure_quickshell_config_dms
  ensure_dgop_installed
  ensure_matugen_min_version "2.4.1"
  install_dms_binary || true
  if command -v dms >/dev/null 2>&1; then success "DMS wrapper installed: $(command -v dms)"; fi
}

# ------------- Polkit agent management -------------
ensure_polkit_agent() {
  step "Ensuring a working Polkit authentication agent"
  local gnome_pkg="policykit-1-gnome" mate_pkg="mate-polkit"
  local gnome_paths=(
    "/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1"
  )
  local mate_paths=(
    "/usr/libexec/polkit-mate-authentication-agent-1"
    "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1"
    "/usr/lib/policykit-1-mate/polkit-mate-authentication-agent-1"
  )
  run sudo apt purge -y hyprpolkit hyprpolkit-agent hyprpolkit-git || true
  if pgrep -u "$USER" -f 'hypr.*polkit' >/dev/null 2>&1; then
    warn "Found running hyprpolkit agent; stopping to avoid conflicts"
    run pkill -u "$USER" -f 'hypr.*polkit' || true
  fi
  pkg_install pkexec || true
  local agent=""
  if pkg_install "$gnome_pkg"; then
    for p in "${gnome_paths[@]}"; do
      if [[ -x "$p" ]]; then
        agent="$p"
        break
      fi
    done
  fi
  if [[ -z "$agent" ]]; then
    if pkg_install "$mate_pkg"; then
      for p in "${mate_paths[@]}"; do
        if [[ -x "$p" ]]; then
          agent="$p"
          break
        fi
      done
    fi
  fi
  if [[ -z "$agent" ]]; then
    warn "No polkit authentication agent found after install attempts"
    return 0
  fi
  local autostart="$HOME/.config/autostart/polkit-agent.desktop"
  run mkdir -p "$HOME/.config/autostart"
  if ((DRY_RUN)); then
    printf "Would write autostart for agent: %s -> %s\n" "$agent" "$autostart"
  else
    cat >"$autostart" <<EOF
[Desktop Entry]
Type=Application
Name=Polkit Authentication Agent
Exec=${agent}
X-GNOME-Autostart-enabled=true
OnlyShowIn=GNOME;KDE;LXQt;LXDE;XFCE;Hyprland;Sway;Wayfire;River;qtile;i3;Openbox;
EOF
  fi
  if ! pgrep -u "$USER" -x "$(basename "$agent")" >/dev/null 2>&1; then
    step "Starting polkit agent: $agent"
    if ((DRY_RUN)); then
      printf "Would start: %s\n" "$agent"
    else
      nohup "$agent" >/dev/null 2>&1 &
      disown || true
    fi
  else
    info "Polkit agent already running"
  fi
}

# ------------- Package manager (nala/apt) -------------
PKG_MGR="apt"
PKG_INSTALL_CMD=(sudo apt install -y)
PKG_UPDATE_CMD=(sudo apt update)
PKG_UPGRADE_CMD=(sudo apt upgrade -y)

use_nala_if_available() {
  if command -v nala >/dev/null 2>&1; then
    PKG_MGR="nala"
    PKG_INSTALL_CMD=(sudo nala install -y)
    PKG_UPDATE_CMD=(sudo nala update)
    PKG_UPGRADE_CMD=(sudo nala upgrade -y)
    info "Using nala for package operations"
    return 0
  fi
  return 1
}

try_install_nala() {
  if command -v nala >/dev/null 2>&1; then return 0; fi
  step "Attempting to install nala"
  if run sudo apt update && run sudo apt install -y nala; then
    use_nala_if_available
  else
    warn "nala installation failed; falling back to apt"
  fi
}

pkg_install() { run "${PKG_INSTALL_CMD[@]}" "$@"; }
pkg_update() { run "${PKG_UPDATE_CMD[@]}"; }
pkg_upgrade() { run "${PKG_UPGRADE_CMD[@]}"; }

# ------------- Docker (Ubuntu packages) -------------
install_docker() {
  step "Installing Docker (Ubuntu packages)"
  run sudo apt-get update
  pkg_install ca-certificates curl gnupg || true
  pkg_install docker.io docker-compose-v2
  run sudo usermod -aG docker "$USER"
  run sudo systemctl enable --now docker || run sudo systemctl enable --now dockerd || true
  success "Docker installation complete"
}

# ------------- Flatpak -------------
configure_flatpak() {
  step "Configuring Flatpak"
  run sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

install_flatpak_apps() {
  step "Installing Flatpak apps (flathub)"
  local apps=(
    com.github.tchx84.Flatseal
    com.visualstudio.code
    io.github.dvlv.boxbuddyrs
    io.github.flattool.Warehouse
  )
  run flatpak install -y flathub "${apps[@]}"
}

# ------------- Local .deb installs from NAS -------------
install_deb_if_exists() {
  local deb_path="$1"
  if [[ -f "$deb_path" ]]; then
    step "Installing $(basename "$deb_path")"
    pkg_install "$deb_path" || {
      warn "Install via $PKG_MGR failed for $deb_path; attempting dpkg -i + fix"
      run sudo dpkg -i "$deb_path" || run sudo apt-get -f install -y
    }
  else
    warn "Missing .deb: $deb_path"
  fi
}

install_nas_local_bins() {
  local bin_dir="$NAS_CONFIG_DIR/OS/debian/bin"
  if ! ensure_nas_available; then
    warn "NAS not available; skipping local bin installs"
    return 0
  fi
  if [[ ! -d "$bin_dir" ]]; then
    info "No local bin dir at $bin_dir; skipping"
    return 0
  fi
  step "Installing local binaries from $bin_dir to /usr/local/bin"
  local f base
  for f in "$bin_dir"/*; do
    [[ -f "$f" ]] || continue
    base=$(basename "$f")
    if ((DRY_RUN)); then
      printf "Would install %s -> /usr/local/bin/%s with mode 0755\n" "$f" "$base"
    else
      sudo install -m 0755 -D "$f" "/usr/local/bin/$base"
    fi
  done
}

install_apps() {
  step "Installing standard packages"
  pkg_install git wget curl rsync tmux flatpak sshfs mpv gcc remmina vlc ugrep ripgrep bat fzf ncdu time flex
  pkg_install btop glances zoxide tree ranger cava cmatrix virt-viewer arandr variety feh nitrogen fastfetch
  pkg_install rustc cargo wlr-randr htop ncdu kitty alacritty starship

  configure_flatpak
  install_flatpak_apps

  step "Installing Docker and related components"
  install_docker

  step "Installing additional utilities (distrobox)"
  pkg_install distrobox || warn "distrobox not available in current repositories"

  step "Optional installs from NAS (if present)"
  step "Removing distro Neovim before installing NAS package (avoids conflicts)"
  run sudo apt remove -y neovim neovim-runtime || true
  install_deb_if_exists "$NAS_CONFIG_DIR/OS/debian/Packages/nvim-linux-x86_64.deb"
  install_deb_if_exists "$NAS_CONFIG_DIR/OS/debian/Packages/onefetch_2.25.0_amd64.deb"
  install_deb_if_exists "$NAS_CONFIG_DIR/OS/debian/Packages/discord.deb"
  install_deb_if_exists "$NAS_CONFIG_DIR/OS/debian/Packages/discord-canary.deb"
  install_nas_local_bins

  success "Package installation complete"
}

# ------------- WezTerm / Nerd Fonts / Themes -------------
install_wezterm() {
  step "Installing WezTerm (nightly) from official repository"
  if command -v wezterm >/dev/null 2>&1; then
    info "WezTerm already installed; skipping package install"
  else
    run sudo install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d
    local cmd
    cmd="curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg"
    if ((DRY_RUN)); then
      printf "Would run: %s\n" "$cmd"
    else
      sh -c "$cmd"
    fi
    if ((DRY_RUN)); then
      printf "Would write WezTerm APT source to /etc/apt/sources.list.d/wezterm.list\n"
    else
      echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null || true
    fi
    run sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
    step "Refreshing package metadata for WezTerm"
    pkg_update || run sudo apt update
    step "Installing wezterm-nightly"
    pkg_install wezterm-nightly || warn "Failed to install wezterm-nightly"
  fi

  step "Configuring WezTerm"
  run mkdir -p "$HOME/.config/wezterm"
  local cfg_url="https://codeberg.org/justaguylinux/butterscripts/raw/branch/main/wezterm/wezterm.lua"
  if ((DRY_RUN)); then
    printf "Would download %s -> %s\n" "$cfg_url" "$HOME/.config/wezterm/wezterm.lua"
  else
    curl -fsSL "$cfg_url" -o "$HOME/.config/wezterm/wezterm.lua" || warn "Failed to download WezTerm config"
  fi

  if command -v update-alternatives >/dev/null 2>&1 && command -v wezterm >/dev/null 2>&1; then
    step "Setting wezterm as default terminal emulator"
    run sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/wezterm 50
    run sudo update-alternatives --set x-terminal-emulator /usr/bin/wezterm
  fi
  success "WezTerm installation/configuration complete"
}

install_nerd_fonts() {
  step "Installing Nerd Fonts"
  pkg_install wget unzip || true
  local FONTS_DIR="$HOME/.local/share/fonts"
  local TEMP_DIR
  TEMP_DIR=$(mktemp -d -t nerdfonts.XXXXXX)
  run mkdir -p "$FONTS_DIR"
  local FONT_VERSION="v3.4.0"
  local fonts=(
    JetBrainsMono FiraCode Hack CascadiaCode SourceCodePro RobotoMono Meslo UbuntuMono Inconsolata VictorMono Mononoki Terminus Lilex
  )
  local font
  for font in "${fonts[@]}"; do
    step "Processing $font"
    if [[ -d "$FONTS_DIR/$font" ]] && [[ -n "$(ls -A "$FONTS_DIR/$font" 2>/dev/null)" ]]; then
      info "$font already installed; skipping"
      continue
    fi
    local zip="$TEMP_DIR/${font}.zip"
    local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${font}.zip"
    if ((DRY_RUN)); then
      printf "Would download %s -> %s\n" "$url" "$zip"
      printf "Would extract %s into %s/%s\n" "$zip" "$FONTS_DIR" "$font"
    else
      curl -fL "$url" -o "$zip" || {
        warn "Download failed for $font"
        continue
      }
      run mkdir -p "$FONTS_DIR/$font"
      if unzip -q "$zip" -d "$FONTS_DIR/$font/"; then :; else
        warn "Extraction failed for $font"
        rm -rf "$FONTS_DIR/$font"
      fi
      rm -f "$zip"
    fi
  done
  step "Rebuilding font cache"
  run fc-cache -f
  if ((DRY_RUN)); then
    printf "Would remove temp dir %s\n" "$TEMP_DIR"
  else
    rm -rf "$TEMP_DIR"
  fi
  success "Nerd Fonts installation complete"
}

install_themes() {
  step "Installing GTK and icon themes"
  pkg_install git || true
  local TEMP_DIR
  TEMP_DIR=$(mktemp -d -t themes.XXXXXX)
  if ((DRY_RUN)); then
    printf "Would clone and run theme installers in %s\n" "$TEMP_DIR"
  else
    mkdir -p "$TEMP_DIR"
    (cd "$TEMP_DIR" && git clone -q https://github.com/vinceliuice/Orchis-theme) || { error "Failed to clone GTK theme"; }
    (cd "$TEMP_DIR/Orchis-theme" && yes | ./install.sh -l -c dark -t grey --tweaks black >/dev/null 2>&1) || warn "GTK theme install failed"
    (cd "$TEMP_DIR" && git clone -q https://github.com/vinceliuice/Colloid-icon-theme) || { error "Failed to clone icon theme"; }
    (cd "$TEMP_DIR/Colloid-icon-theme" && ./install.sh -t grey -s dracula >/dev/null 2>&1 || true)
    local ICON_THEME="Colloid-Grey-Dracula-Dark"
    if [[ ! -d "$HOME/.local/share/icons/$ICON_THEME" ]] && [[ ! -d "$HOME/.icons/$ICON_THEME" ]]; then
      warn "Icon theme installation verification failed"
    fi
  fi

  local GTK_THEME="Orchis-Grey-Dark"
  run mkdir -p "$HOME/.config/gtk-3.0"
  if ((DRY_RUN)); then
    printf "Would write GTK settings files and apply via gsettings if available\n"
  else
    cat >"$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=Colloid-Grey-Dracula-Dark
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
EOF
    cat >"$HOME/.gtkrc-2.0" <<EOF
gtk-theme-name="$GTK_THEME"
gtk-icon-theme-name="Colloid-Grey-Dracula-Dark"
gtk-font-name="Sans 10"
gtk-cursor-theme-name="Adwaita"
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintfull"
EOF
    if command -v gsettings >/dev/null 2>&1; then
      gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" || true
      gsettings set org.gnome.desktop.interface icon-theme "Colloid-Grey-Dracula-Dark" || true
    fi
  fi

  if ((DRY_RUN)); then
    printf "Would remove temp dir %s\n" "$TEMP_DIR"
  else
    rm -rf "$TEMP_DIR"
  fi
  success "Themes installed and applied"
}

preflight_updates() {
  if confirm "Recommended: run 'sudo apt update && sudo apt upgrade -y' now before proceeding?" y; then
    step "Updating package metadata"
    pkg_update || run sudo apt update
    step "Upgrading packages"
    pkg_upgrade || run sudo apt upgrade -y
  else
    warn "Proceeding without initial apt update/upgrade"
  fi
}

postflight_updates() {
  if confirm "Run 'sudo apt update && sudo apt upgrade -y' again to pick up any new updates (e.g., from newly added repos)?" y; then
    step "Updating package metadata"
    run sudo apt update
    step "Upgrading packages"
    run sudo apt upgrade -y
  else
    warn "Skipping final apt update/upgrade"
  fi
}

main() {
  info "Starting Ubuntu setup"

  if ((APT_ONLY)); then
    info "Using apt (forced)"
  else
    info "Using apt"
  fi

  preflight_updates

  if ((DMS_ONLY)); then
    info "DMS-only mode"
    ensure_dms_fonts
    install_dms
    ensure_polkit_agent
    success "Done (dms-only)"
    postflight_updates
    return 0
  fi

  if ((WEZTERM_ONLY || FONTS_ONLY || THEMES_ONLY)); then
    info "Selective install mode"
    if ((WEZTERM_ONLY)); then install_wezterm; fi
    if ((FONTS_ONLY)); then install_nerd_fonts; fi
    if ((THEMES_ONLY)); then install_themes; fi
    success "Done (selective installs)"
    postflight_updates
    return 0
  fi

  if ((CONFIG_ONLY)); then
    info "Config-only mode"
    ensure_dms_fonts
    if ((INSTALL_DMS)); then
      install_dms
    fi
    ensure_polkit_agent
    copy_config_files
    success "Done (config-only)"
    postflight_updates
    return 0
  fi

  if ((APPS_ONLY)); then
    info "Apps-only mode"
    install_apps
    if ((INSTALL_DMS)); then
      ensure_dms_fonts
      install_dms
    fi
    ensure_polkit_agent
    success "Done (apps-only)"
    postflight_updates
    return 0
  fi

  install_apps
  ensure_dms_fonts
  if ((INSTALL_DMS)); then
    install_dms
  fi
  ensure_polkit_agent
  copy_config_files

  success "All tasks complete"
  postflight_updates
}

main "$@"
