#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STATE_DIR="$TMP/state"
CONFIG_DIR="$TMP/etc"
SELLER_DB="$STATE_DIR/sellers.tsv"
mkdir -p "$STATE_DIR" "$CONFIG_DIR"

die() { printf 'TEST ERROR: %s\n' "$*" >&2; exit 1; }
require_root() { :; }
validate_username() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,31}$ ]] || die "bad username"; }
ok() { :; }
warn() { :; }
info() { :; }
fail() { :; }
backup_file() { :; }

# shellcheck disable=SC1091
source "$ROOT/lib/986/hysteria.sh"

mkdir -p "$HYSTERIA_CONFIG_DIR"
cat > "$HYSTERIA_PROFILE_FILE" <<'EOF_PROFILE'
HYSTERIA_DOMAIN='vpn.example.com'
HYSTERIA_PORT='8443'
HYSTERIA_BOOTSTRAP_NAME='bootstrap-hy2'
HYSTERIA_BOOTSTRAP_PASSWORD='bootpass986'
EOF_PROFILE

cat > "$SELLER_DB" <<'EOF_SELLERS'
username	status	expires_at	protocols	xray_uuid	created_at	updated_at
alice	active	2099-01-01	vless-reality,hysteria2	11111111-1111-1111-1111-111111111111	2026-01-01T00:00:00Z	2026-01-01T00:00:00Z
bob	suspended	2099-01-01	vless-reality,hysteria2	22222222-2222-2222-2222-222222222222	2026-01-01T00:00:00Z	2026-01-01T00:00:00Z
charlie	active	2099-01-01	vless-reality	33333333-3333-3333-3333-333333333333	2026-01-01T00:00:00Z	2026-01-01T00:00:00Z
EOF_SELLERS

cat > "$HYSTERIA_USERS_DB" <<'EOF_USERS'
username	password
alice	alicepass986
bob	bobpass986
charlie	charliepass986
EOF_USERS
chmod 0600 "$HYSTERIA_USERS_DB"

rendered="$TMP/rendered.yaml"
_hysteria_render_config "$rendered"
_hysteria_check_config_shape "$rendered"

grep -Fq '    bootstrap-hy2: bootpass986' "$rendered"
grep -Fq '    alice: alicepass986' "$rendered"
! grep -Fq '    bob: bobpass986' "$rendered"
! grep -Fq '    charlie: charliepass986' "$rendered"

printf 'hysteria2 seller isolation: PASS\n'
