#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_ROOT="/usr/local/lib/986-vps"
BIN_LINK="/usr/local/bin/986"
CONFIG_DIR="/etc/986-vps"
STATE_DIR="/var/lib/986-vps"
BACKUP_DIR="/var/backups/986-vps"
XRAY_RUNTIME_DIR="/opt/986-vps/xray"
XRAY_CONFIG_DIR="$CONFIG_DIR/xray"
XRAY_UNIT="/etc/systemd/system/986-xray.service"
EXPIRY_SERVICE="/etc/systemd/system/986-user-expiry.service"
EXPIRY_TIMER="/etc/systemd/system/986-user-expiry.timer"
PURGE="false"

if [[ "${1:-}" == "--purge" ]]; then
  PURGE="true"
fi

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }

# The expiry timer calls the 986 CLI. Disable it before removing the CLI so
# uninstall never leaves a permanently failing systemd timer behind.
systemctl disable --now 986-user-expiry.timer >/dev/null 2>&1 || true
rm -f "$EXPIRY_SERVICE" "$EXPIRY_TIMER"
systemctl daemon-reload >/dev/null 2>&1 || true

printf '[986] Removing CLI/orchestration runtime only...\n'
rm -f "$BIN_LINK"
rm -rf "$INSTALL_ROOT"

if [[ "$PURGE" == "true" ]]; then
  printf '[986] Purge requested: removing non-runtime 986 application state where safe.\n'

  # Preserve Xray's live config because the managed systemd service may still
  # depend on it after the 986 CLI is removed. Removing it would violate the
  # project's no-surprise-outage rule.
  if [[ -d "$CONFIG_DIR" ]]; then
    find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 \
      ! -name xray \
      -exec rm -rf -- {} +
  fi

  rm -rf "$STATE_DIR"
  printf '[986] WireGuard configuration in /etc/wireguard is intentionally preserved.\n'
  if [[ -d "$XRAY_CONFIG_DIR" ]]; then
    printf '[986] Xray live configuration preserved in %s.\n' "$XRAY_CONFIG_DIR"
  fi
else
  printf '[986] Preserving %s and %s.\n' "$CONFIG_DIR" "$STATE_DIR"
fi

if [[ -d "$XRAY_RUNTIME_DIR" ]]; then
  printf '[986] Xray protocol runtime preserved in %s.\n' "$XRAY_RUNTIME_DIR"
fi
if [[ -f "$XRAY_UNIT" ]]; then
  printf '[986] Xray systemd service definition preserved: %s.\n' "$XRAY_UNIT"
fi

printf '[986] Seller expiry automation removed with the management CLI.\n'
printf '[986] Backups remain in %s.\n' "$BACKUP_DIR"
printf '[986] Existing VPN/proxy services were not stopped or deleted.\n'
printf '[986] Reinstalling 986 later will rediscover/preserve supported runtime state.\n'
