#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STATE_DIR="$TMP/state"
CONFIG_DIR="$TMP/etc"
XRAY_CONFIG_DIR="$CONFIG_DIR/xray"
XRAY_CONFIG="$XRAY_CONFIG_DIR/config.json"
mkdir -p "$STATE_DIR" "$XRAY_CONFIG_DIR" "$CONFIG_DIR/clients"

# Minimal common/runtime shims for the isolated seller-engine test.
die() { printf 'TEST ERROR: %s\n' "$*" >&2; exit 1; }
require_root() { :; }
backup_file() { :; }
validate_username() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,31}$ ]] || die "bad username"; }
validate_positive_int() { [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "bad integer"; }
ok() { :; }
info() { :; }

# shellcheck disable=SC1091
source "$ROOT/lib/986/seller.sh"

seller_load_reality_server() {
  XRAY_LISTEN_PORT=443
  export XRAY_LISTEN_PORT
}

_xray_apply_config_transaction() {
  local staged="$1"
  cp "$staged" "$XRAY_CONFIG"
}

cat > "$XRAY_CONFIG" <<'EOF_JSON'
{
  "inbounds": [
    {
      "tag": "vless-reality",
      "settings": {
        "clients": [
          {"id":"00000000-0000-0000-0000-000000000001","flow":"xtls-rprx-vision","email":"bootstrap@986.local"},
          {"id":"00000000-0000-0000-0000-000000000002","flow":"xtls-rprx-vision","email":"alice@986.local"},
          {"id":"00000000-0000-0000-0000-000000000003","flow":"xtls-rprx-vision","email":"bob@986.local"}
        ]
      }
    }
  ]
}
EOF_JSON

seller_ensure_state
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
yesterday="$(date -u -d 'yesterday' +%F)"
tomorrow="$(date -u -d 'tomorrow' +%F)"
printf 'alice\tactive\t%s\tvless-reality\t00000000-0000-0000-0000-000000000002\t%s\t%s\n' "$yesterday" "$now" "$now" >> "$SELLER_DB"
printf 'bob\tactive\t%s\tvless-reality\t00000000-0000-0000-0000-000000000003\t%s\t%s\n' "$tomorrow" "$now" "$now" >> "$SELLER_DB"

seller_expire >/dev/null

jq -e '[.inbounds[] | select(.tag=="vless-reality") | .settings.clients[].email] | index("alice@986.local") == null' "$XRAY_CONFIG" >/dev/null
jq -e '[.inbounds[] | select(.tag=="vless-reality") | .settings.clients[].email] | index("bob@986.local") != null' "$XRAY_CONFIG" >/dev/null
jq -e '[.inbounds[] | select(.tag=="vless-reality") | .settings.clients[].email] | index("bootstrap@986.local") != null' "$XRAY_CONFIG" >/dev/null

[[ "$(seller_field alice 2)" == "expired" ]]
[[ "$(seller_field bob 2)" == "active" ]]

printf 'seller-engine expiry isolation: PASS\n'
