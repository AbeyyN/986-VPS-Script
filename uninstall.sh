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
HYSTERIA_RUNTIME_DIR="/opt/986-vps/hysteria"
HYSTERIA_CONFIG_DIR="$CONFIG_DIR/hysteria"
HYSTERIA_UNIT="/etc/systemd/system/986-hysteria.service"
EXPIRY_SERVICE="/etc/systemd/system/986-user-expiry.service"
EXPIRY_TIMER="/etc/systemd/system/986-user-expiry.timer"
PURGE="false"

if [[ "${1:-}" == "--purge" ]]; then
  PURGE="true"
fi

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }

systemctl disable --now 986-user-expiry.timer >/dev/null 2>&1 || true
rm -f "$EXPIRY_SERVICE" "$EXPIRY_TIMER"
systemctl daemon-reload >/dev/null 2>&1 || true

printf '[986] Removing CLI/orchestration runtime only...\n'
rm -f "$BIN_LINK"
rm -rf "$INSTALL_ROOT"

if [[ "$PURGE" == "true" ]]; then
  printf '[986] Purge requested: removing non-runtime 986 application state where safe.\n'
  if [[ -d "$CONFIG_DIR" ]]; then
    find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 \
      ! -name xray \
      ! -name hysteria \
      -exec rm -rf -- {} +
  fi
  rm -rf "$STATE_DIR"
  printf '[986] WireGuard configuration in /etc/wireguard is intentionally preserved.\n'
  [[ -d "$XRAY_CONFIG_DIR" ]] && printf '[986] Xray live configuration preserved in %s.\n' "$XRAY_CONFIG_DIR"
  [[ -d "$HYSTERIA_CONFIG_DIR" ]] && printf '[986] Hysteria2 live configuration/TLS material preserved in %s.\n' "$HYSTERIA_CONFIG_DIR"
else
  printf '[986] Preserving %s and %s.\n' "$CONFIG_DIR" "$STATE_DIR"
fi

[[ -d "$XRAY_RUNTIME_DIR" ]] && printf '[986] Xray protocol runtime preserved in %s.\n' "$XRAY_RUNTIME_DIR"
[[ -f "$XRAY_UNIT" ]] && printf '[986] Xray systemd service preserved: %s.\n' "$XRAY_UNIT"
[[ -d "$HYSTERIA_RUNTIME_DIR" ]] && printf '[986] Hysteria2 protocol runtime preserved in %s.\n' "$HYSTERIA_RUNTIME_DIR"
[[ -f "$HYSTERIA_UNIT" ]] && printf '[986] Hysteria2 systemd service preserved: %s.\n' "$HYSTERIA_UNIT"

printf '[986] Seller expiry automation removed with the management CLI.\n'
printf '[986] Backups remain in %s.\n' "$BACKUP_DIR"
printf '[986] Existing VPN/proxy services were not stopped or deleted.\n'
printf '[986] Reinstalling 986 later will rediscover/preserve supported runtime state.\n'
