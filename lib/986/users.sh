#!/usr/bin/env bash

user_exists() {
  local username="$1"
  [[ -f "$USERS_DB" ]] && awk -F '\t' -v u="$username" 'NR>1 && $1==u {found=1} END {exit !found}' "$USERS_DB"
}

user_row() {
  local username="$1"
  awk -F '\t' -v u="$username" 'NR>1 && $1==u {print; exit}' "$USERS_DB"
}

allocate_client_ip() {
  load_config
  local server_ip prefix i candidate
  server_ip="${WG_SERVER_ADDRESS:-10.86.0.1/24}"
  server_ip="${server_ip%/*}"
  prefix="${server_ip%.*}"
  for i in $(seq 2 254); do
    candidate="$prefix.$i"
    if ! awk -F '\t' -v ip="$candidate" 'NR>1 && $4==ip {found=1} END {exit !found}' "$USERS_DB"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  die 'No free client IPv4 addresses remain in the configured /24 subnet.'
}

remove_peer_block() {
  local username="$1" tmp start end
  [[ -f "$WG_CONF" ]] || return 0
  start="# 986-user:$username"
  end="# 986-end:$username"
  tmp="$(mktemp)"
  awk -v start="$start" -v end="$end" '
    $0==start {skip=1; next}
    $0==end {skip=0; next}
    !skip {print}
  ' "$WG_CONF" > "$tmp"
  cat "$tmp" > "$WG_CONF"
  chmod 0600 "$WG_CONF"
  rm -f "$tmp"
}

append_peer_block() {
  local username="$1" public_key="$2" ip_address="$3"
  cat >> "$WG_CONF" <<EOF

# 986-user:$username
[Peer]
PublicKey = $public_key
AllowedIPs = $ip_address/32
# 986-end:$username
EOF
}

db_update_field() {
  local username="$1" field="$2" value="$3" tmp
  tmp="$(mktemp)"
  awk -F '\t' -v OFS='\t' -v u="$username" -v f="$field" -v v="$value" '
    NR==1 {print; next}
    $1==u {$f=v}
    {print}
  ' "$USERS_DB" > "$tmp"
  cat "$tmp" > "$USERS_DB"
  chmod 0600 "$USERS_DB"
  rm -f "$tmp"
}

user_add() {
  require_root
  ensure_state
  load_config
  local username="${1:-}" days=30
  shift || true
  while (( $# )); do
    case "$1" in
      --days) days="${2:-}"; shift 2 ;;
      *) die "Unknown user option: $1" ;;
    esac
  done
  [[ -n "$username" ]] || die 'Usage: 986 user add <username> [--days N]'
  validate_username "$username"
  validate_positive_int "$days"
  [[ -f "$WG_CONF" ]] || die 'WireGuard is not installed. Run: 986 wireguard install'
  command -v wg >/dev/null 2>&1 || die 'WireGuard tools are unavailable.'
  user_exists "$username" && die "User already exists: $username"

  local endpoint port dns ip_address private_key public_key server_private server_public expires config_path
  endpoint="${PUBLIC_ENDPOINT:-}"
  [[ -n "$endpoint" ]] || endpoint="$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  [[ -n "$endpoint" ]] || die "Public endpoint could not be detected. Set PUBLIC_ENDPOINT in $CONFIG_FILE."
  port="${WG_PORT:-51820}"
  dns="${WG_DNS:-1.1.1.1,1.0.0.1}"
  ip_address="$(allocate_client_ip)"
  private_key="$(wg genkey)"
  public_key="$(printf '%s' "$private_key" | wg pubkey)"
  server_private="$(awk -F ' *= *' '$1=="PrivateKey" {print $2; exit}' "$WG_CONF")"
  [[ -n "$server_private" ]] || die 'Cannot read the server private key from wg0.conf.'
  server_public="$(printf '%s' "$server_private" | wg pubkey)"
  expires="$(date -u -d "+$days days" +%F)"
  config_path="$CONFIG_DIR/clients/$username.conf"

  backup_file "$WG_CONF" 'wg0'
  append_peer_block "$username" "$public_key" "$ip_address"
  sync_wireguard_runtime

  umask 077
  cat > "$config_path" <<EOF
[Interface]
PrivateKey = $private_key
Address = $ip_address/32
DNS = $dns

[Peer]
PublicKey = $server_public
Endpoint = $endpoint:$port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
  chmod 0600 "$config_path"

  printf '%s\tactive\t%s\t%s\t%s\t%s\n' "$username" "$expires" "$ip_address" "$public_key" "$config_path" >> "$USERS_DB"

  ok "Created WireGuard user: $username"
  printf 'Expires : %s\n' "$expires"
  printf 'Address : %s\n' "$ip_address"
  printf 'Config  : %s\n' "$config_path"
  if command -v qrencode >/dev/null 2>&1; then
    printf '\nClient QR:\n'
    qrencode -t ansiutf8 < "$config_path" || true
  fi
}

user_list() {
  ensure_state
  printf '%-20s %-12s %-12s %-16s\n' 'USERNAME' 'STATUS' 'EXPIRES' 'ADDRESS'
  printf '%-20s %-12s %-12s %-16s\n' '--------' '------' '-------' '-------'
  awk -F '\t' 'NR>1 {printf "%-20s %-12s %-12s %-16s\n", $1,$2,$3,$4}' "$USERS_DB"
}

user_suspend() {
  require_root
  ensure_state
  local username="${1:-}"
  [[ -n "$username" ]] || die 'Usage: 986 user suspend <username>'
  user_exists "$username" || die "Unknown user: $username"
  backup_file "$WG_CONF" 'wg0'
  remove_peer_block "$username"
  sync_wireguard_runtime
  db_update_field "$username" 2 'suspended'
  ok "Suspended user: $username"
}

user_resume() {
  require_root
  ensure_state
  local username="${1:-}" row status ip_address public_key
  [[ -n "$username" ]] || die 'Usage: 986 user resume <username>'
  user_exists "$username" || die "Unknown user: $username"
  row="$(user_row "$username")"
  IFS=$'\t' read -r _ status _ ip_address public_key _ <<< "$row"
  [[ "$status" != 'active' ]] || die "User is already active: $username"
  backup_file "$WG_CONF" 'wg0'
  remove_peer_block "$username"
  append_peer_block "$username" "$public_key" "$ip_address"
  sync_wireguard_runtime
  db_update_field "$username" 2 'active'
  ok "Resumed user: $username"
}

user_renew() {
  require_root
  ensure_state
  local username="${1:-}" days="${2:-30}" expires
  [[ -n "$username" ]] || die 'Usage: 986 user renew <username> [days]'
  validate_positive_int "$days"
  user_exists "$username" || die "Unknown user: $username"
  expires="$(date -u -d "+$days days" +%F)"
  db_update_field "$username" 3 "$expires"
  ok "Renewed $username until $expires"
}

user_delete() {
  require_root
  ensure_state
  local username="${1:-}" row config_path tmp
  [[ -n "$username" ]] || die 'Usage: 986 user delete <username>'
  user_exists "$username" || die "Unknown user: $username"
  row="$(user_row "$username")"
  config_path="$(printf '%s\n' "$row" | awk -F '\t' '{print $6}')"
  backup_file "$WG_CONF" 'wg0'
  backup_file "$USERS_DB" 'users'
  remove_peer_block "$username"
  sync_wireguard_runtime
  rm -f "$config_path"
  tmp="$(mktemp)"
  awk -F '\t' -v u="$username" 'NR==1 || $1!=u' "$USERS_DB" > "$tmp"
  cat "$tmp" > "$USERS_DB"
  chmod 0600 "$USERS_DB"
  rm -f "$tmp"
  ok "Deleted user: $username"
}

user_show_config() {
  require_root
  ensure_state
  local username="${1:-}" row config_path
  [[ -n "$username" ]] || die 'Usage: 986 user config <username>'
  user_exists "$username" || die "Unknown user: $username"
  row="$(user_row "$username")"
  config_path="$(printf '%s\n' "$row" | awk -F '\t' '{print $6}')"
  [[ -r "$config_path" ]] || die "Client config is missing: $config_path"
  cat "$config_path"
}
