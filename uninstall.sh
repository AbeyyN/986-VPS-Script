#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_ROOT="/usr/local/lib/986-vps"
BIN_LINK="/usr/local/bin/986"
CONFIG_DIR="/etc/986-vps"
STATE_DIR="/var/lib/986-vps"
BACKUP_DIR="/var/backups/986-vps"
PURGE="false"

if [[ "${1:-}" == "--purge" ]]; then
  PURGE="true"
fi

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }

printf '[986] Removing CLI/runtime files...\n'
rm -f "$BIN_LINK"
rm -rf "$INSTALL_ROOT"

if [[ "$PURGE" == "true" ]]; then
  printf '[986] Purge requested: removing 986 application config/state.\n'
  printf '[986] WireGuard configuration in /etc/wireguard is intentionally preserved.\n'
  rm -rf "$CONFIG_DIR" "$STATE_DIR"
else
  printf '[986] Preserving %s and %s.\n' "$CONFIG_DIR" "$STATE_DIR"
fi

printf '[986] Backups remain in %s.\n' "$BACKUP_DIR"
printf '[986] Existing VPN services were not stopped or deleted.\n'
