#!/usr/bin/env bash

PRODUCT_NAME="986 VPS Engine"
PRODUCT_VERSION="0.4.0-alpha.1"
INSTALL_ROOT="/usr/local/lib/986-vps"
CONFIG_DIR="/etc/986-vps"
CONFIG_FILE="$CONFIG_DIR/986.conf"
STATE_DIR="/var/lib/986-vps"
BACKUP_DIR="/var/backups/986-vps"
USERS_DB="$STATE_DIR/users.tsv"
WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/wg0.conf"
export PRODUCT_NAME PRODUCT_VERSION INSTALL_ROOT CONFIG_DIR CONFIG_FILE STATE_DIR BACKUP_DIR USERS_DB WG_DIR WG_CONF

c_red='\033[0;31m'
c_green='\033[0;32m'
c_yellow='\033[0;33m'
c_blue='\033[0;34m'
c_reset='\033[0m'

info() { printf "%b[INFO]%b %s\n" "$c_blue" "$c_reset" "$*"; }
ok() { printf "%b[ OK ]%b %s\n" "$c_green" "$c_reset" "$*"; }
warn() { printf "%b[WARN]%b %s\n" "$c_yellow" "$c_reset" "$*" >&2; }
fail() { printf "%b[FAIL]%b %s\n" "$c_red" "$c_reset" "$*" >&2; }
die() { fail "$*"; exit 1; }

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "This command requires root. Re-run with sudo."
}

load_config() {
  PUBLIC_ENDPOINT=""
  XRAY_CHANNEL="stable"
  WG_PORT="51820"
  WG_SUBNET="10.86.0.0/24"
  WG_SERVER_ADDRESS="10.86.0.1/24"
  WG_DNS="1.1.1.1,1.0.0.1"
  CONTROL_PLANE_URL=""
  TELEMETRY_ENABLED="false"
  LICENSE_MODE="early_access"

  if [[ -r "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi
  export PUBLIC_ENDPOINT XRAY_CHANNEL WG_PORT WG_SUBNET WG_SERVER_ADDRESS WG_DNS CONTROL_PLANE_URL TELEMETRY_ENABLED LICENSE_MODE
}

ensure_state() {
  install -d -m 0755 "$STATE_DIR" "$BACKUP_DIR"
  install -d -m 0700 "$CONFIG_DIR/clients" "$STATE_DIR/keys"
  if [[ ! -f "$USERS_DB" ]]; then
    printf 'username\tstatus\texpires_at\tip_address\tpublic_key\tconfig_path\n' > "$USERS_DB"
    chmod 0600 "$USERS_DB"
  fi
}

installation_id() {
  if [[ -r "$STATE_DIR/installation-id" ]]; then
    cat "$STATE_DIR/installation-id"
  else
    printf 'unregistered\n'
  fi
}

backup_file() {
  local src="$1" label="${2:-file}"
  [[ -f "$src" ]] || return 0
  install -d -m 0755 "$BACKUP_DIR"
  cp -a "$src" "$BACKUP_DIR/${label}-$(date -u +%Y%m%dT%H%M%SZ).bak"
}

validate_username() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,31}$ ]] || die "Invalid username. Use 1-32 letters, numbers, dot, underscore or hyphen."
}

validate_positive_int() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "Expected a positive integer, got: $1"
}

config_value() {
  local key="$1" fallback="${2:-}"
  load_config
  case "$key" in
    public_endpoint) printf '%s\n' "${PUBLIC_ENDPOINT:-$fallback}" ;;
    xray_channel) printf '%s\n' "${XRAY_CHANNEL:-$fallback}" ;;
    wg_port) printf '%s\n' "${WG_PORT:-$fallback}" ;;
    wg_dns) printf '%s\n' "${WG_DNS:-$fallback}" ;;
    *) printf '%s\n' "$fallback" ;;
  esac
}
