#!/usr/bin/env bash
set -Eeuo pipefail

REPO_RAW="https://raw.githubusercontent.com/AbeyyN/986-VPS-Script/main"
INSTALL_ROOT="/usr/local/lib/986-vps"
CONFIG_DIR="/etc/986-vps"
STATE_DIR="/var/lib/986-vps"
BACKUP_DIR="/var/backups/986-vps"
BIN_LINK="/usr/local/bin/986"

log() { printf '[986] %s\n' "$*"; }
die() { printf '[986] ERROR: %s\n' "$*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run this installer as root (sudo bash install-986.sh)."
[[ -r /etc/os-release ]] || die "Cannot identify the operating system."
# shellcheck disable=SC1091
source /etc/os-release

case "${ID:-}" in
  debian)
    major="${VERSION_ID%%.*}"
    (( major >= 13 )) || die "Debian 13 or newer is required for Early Access."
    ;;
  ubuntu)
    major="${VERSION_ID%%.*}"
    (( major >= 26 )) || die "Ubuntu Server 26.04 LTS or newer is required for Early Access."
    ;;
  *)
    die "Unsupported distribution: ${ID:-unknown}. Supported: Debian 13+, Ubuntu 26.04+."
    ;;
esac

arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$arch" in
  amd64|x86_64) ;;
  *) die "Early Access currently supports amd64 only (detected: $arch)." ;;
esac

export DEBIAN_FRONTEND=noninteractive
log "Installing baseline dependencies..."
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl jq unzip iproute2 openssl coreutils gawk grep sed util-linux passwd

install -d -m 0755 "$INSTALL_ROOT" "$CONFIG_DIR" "$STATE_DIR" "$BACKUP_DIR"
install -d -m 0700 "$CONFIG_DIR/clients" "$STATE_DIR/keys"

fetch() {
  local remote="$1" dest="$2" mode="${3:-0644}"
  local tmp
  tmp="$(mktemp)"
  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 "$REPO_RAW/$remote" -o "$tmp"
  install -m "$mode" "$tmp" "$dest"
  rm -f "$tmp"
}

log "Installing 986 VPS Engine runtime..."
fetch "bin/986" "$INSTALL_ROOT/986" 0755
fetch "lib/986/common.sh" "$INSTALL_ROOT/common.sh"
fetch "lib/986/registry.sh" "$INSTALL_ROOT/registry.sh"
fetch "lib/986/xray.sh" "$INSTALL_ROOT/xray.sh"
fetch "lib/986/system.sh" "$INSTALL_ROOT/system.sh"
fetch "lib/986/wireguard.sh" "$INSTALL_ROOT/wireguard.sh"
fetch "lib/986/users.sh" "$INSTALL_ROOT/users.sh"
fetch "lib/986/licensing.sh" "$INSTALL_ROOT/licensing.sh"

if [[ ! -f "$CONFIG_DIR/986.conf" ]]; then
  fetch "config/986.conf.example" "$CONFIG_DIR/986.conf" 0600
  log "Created $CONFIG_DIR/986.conf"
else
  log "Preserving existing $CONFIG_DIR/986.conf"
fi

ln -sfn "$INSTALL_ROOT/986" "$BIN_LINK"

if [[ ! -f "$STATE_DIR/installation-id" ]]; then
  umask 077
  printf '986-%s\n' "$(openssl rand -hex 8 | tr '[:lower:]' '[:upper:]')" > "$STATE_DIR/installation-id"
fi

if [[ ! -f "$STATE_DIR/users.tsv" ]]; then
  printf 'username\tstatus\texpires_at\tip_address\tpublic_key\tconfig_path\n' > "$STATE_DIR/users.tsv"
  chmod 0600 "$STATE_DIR/users.tsv"
fi

log "Running post-install diagnostics..."
if "$BIN_LINK" doctor; then
  log "986 VPS Engine installation complete."
else
  log "Installation completed with diagnostic warnings. Run: sudo 986 doctor"
fi

printf '\nRecommended next commands:\n'
printf '  sudo 986\n'
printf '  sudo 986 xray install\n'
printf '  sudo 986 xray bootstrap reality --server-name HOST --target HOST:443\n'
printf '\nOptional conventional VPN module:\n'
printf '  sudo 986 wireguard install\n'
