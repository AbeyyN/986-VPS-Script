#!/usr/bin/env bash

SELLER_DB="$STATE_DIR/sellers.tsv"
SELLER_EXPIRY_SERVICE="986-user-expiry.service"
SELLER_EXPIRY_TIMER="986-user-expiry.timer"
export SELLER_DB SELLER_EXPIRY_SERVICE SELLER_EXPIRY_TIMER

seller_ensure_state() {
  install -d -m 0755 "$STATE_DIR"
  if [[ ! -f "$SELLER_DB" ]]; then
    printf 'username\tstatus\texpires_at\tprotocols\txray_uuid\tcreated_at\tupdated_at\n' > "$SELLER_DB"
    chmod 0600 "$SELLER_DB"
  fi
}

seller_exists() {
  local username="$1"
  seller_ensure_state
  awk -F '\t' -v u="$username" 'NR>1 && $1==u {found=1} END {exit !found}' "$SELLER_DB"
}

seller_row() {
  local username="$1"
  seller_ensure_state
  awk -F '\t' -v u="$username" 'NR>1 && $1==u {print; exit}' "$SELLER_DB"
}

seller_field() {
  local username="$1" field="$2"
  seller_row "$username" | awk -F '\t' -v f="$field" '{print $f}'
}

seller_update_field() {
  local username="$1" field="$2" value="$3" tmp now
  seller_ensure_state
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$(mktemp "$STATE_DIR/.sellers.XXXXXX")"
  awk -F '\t' -v OFS='\t' -v u="$username" -v f="$field" -v v="$value" -v now="$now" '
    NR==1 {print; next}
    $1==u {$f=v; $7=now}
    {print}
  ' "$SELLER_DB" > "$tmp"
  chmod 0600 "$tmp"
  mv -f "$tmp" "$SELLER_DB"
}

seller_validate_protocol() {
  case "$1" in
    vless-reality) ;;
    *) die "Unsupported seller protocol in this milestone: $1. Available: vless-reality" ;;
  esac
}

seller_load_reality_server() {
  [[ -x "$XRAY_BIN" ]] || die "Xray is not installed. Run: sudo 986 xray install"
  [[ -s "$XRAY_CONFIG" ]] || die "Xray is not configured. Bootstrap REALITY first."
  [[ -r "$XRAY_PROFILE_FILE" ]] || die "Xray server profile metadata is missing. Bootstrap REALITY first."
  # shellcheck disable=SC1090
  source "$XRAY_PROFILE_FILE"

  local required
  for required in XRAY_LISTEN_PORT XRAY_SERVER_NAME XRAY_REALITY_PUBLIC_KEY XRAY_REALITY_SHORT_ID XRAY_PUBLIC_ENDPOINT; do
    [[ -n "${!required:-}" ]] || die "Xray server profile metadata is incomplete: $required"
  done

  jq -e '.inbounds[] | select(.tag == "vless-reality")' "$XRAY_CONFIG" >/dev/null \
    || die "Managed vless-reality inbound is missing from $XRAY_CONFIG"
}

seller_stage_xray_add() {
  local username="$1" uuid="$2" staged email
  email="$username@986.local"
  staged="$(mktemp "$XRAY_CONFIG_DIR/.seller-add.XXXXXX.json")"

  if jq -e --arg email "$email" --arg uuid "$uuid" '
      .inbounds[] | select(.tag == "vless-reality") | .settings.clients[]? |
      select(.email == $email or .id == $uuid)
    ' "$XRAY_CONFIG" >/dev/null; then
    rm -f "$staged"
    die "Xray already contains the customer identity or UUID for: $username"
  fi

  jq --arg email "$email" --arg uuid "$uuid" '
    (.inbounds[] | select(.tag == "vless-reality") | .settings.clients) +=
      [{id: $uuid, flow: "xtls-rprx-vision", email: $email}]
  ' "$XRAY_CONFIG" > "$staged"
  chmod 0600 "$staged"
  printf '%s\n' "$staged"
}

seller_stage_xray_remove() {
  local username="$1" staged email
  email="$username@986.local"
  staged="$(mktemp "$XRAY_CONFIG_DIR/.seller-remove.XXXXXX.json")"
  jq --arg email "$email" '
    (.inbounds[] | select(.tag == "vless-reality") | .settings.clients) |=
      map(select(.email != $email))
  ' "$XRAY_CONFIG" > "$staged"
  chmod 0600 "$staged"
  printf '%s\n' "$staged"
}

seller_xray_identity_present() {
  local username="$1" uuid="$2" email
  email="$username@986.local"
  jq -e --arg email "$email" --arg uuid "$uuid" '
    .inbounds[] | select(.tag == "vless-reality") | .settings.clients[]? |
    select(.email == $email and .id == $uuid)
  ' "$XRAY_CONFIG" >/dev/null
}

seller_add() {
  require_root
  seller_ensure_state
  seller_load_reality_server

  local username="${1:-}" days=30 protocol='vless-reality'
  local uuid expires now staged db_tmp
  shift || true

  while (($#)); do
    case "$1" in
      --days) [[ $# -ge 2 ]] || die "--days requires a value"; days="$2"; shift 2 ;;
      --protocol) [[ $# -ge 2 ]] || die "--protocol requires a value"; protocol="$2"; shift 2 ;;
      *) die "Unknown user option: $1" ;;
    esac
  done

  [[ -n "$username" ]] || die "Usage: 986 user add NAME [--days N] [--protocol vless-reality]"
  validate_username "$username"
  validate_positive_int "$days"
  seller_validate_protocol "$protocol"
  seller_exists "$username" && die "Seller user already exists: $username"

  uuid="$($XRAY_BIN uuid | head -n 1 | tr -d '\r')"
  [[ "$uuid" =~ ^[0-9a-fA-F-]{36}$ ]] || die "Xray returned an unexpected UUID."
  expires="$(date -u -d "+$days days" +%F)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  staged="$(seller_stage_xray_add "$username" "$uuid")"
  db_tmp="$(mktemp "$STATE_DIR/.sellers.XXXXXX")"
  cat "$SELLER_DB" > "$db_tmp"
  printf '%s\tactive\t%s\t%s\t%s\t%s\t%s\n' \
    "$username" "$expires" "$protocol" "$uuid" "$now" "$now" >> "$db_tmp"
  chmod 0600 "$db_tmp"

  backup_file "$SELLER_DB" sellers
  _xray_apply_config_transaction "$staged" "$XRAY_LISTEN_PORT"
  mv -f "$db_tmp" "$SELLER_DB"
  rm -f "$staged"

  if declare -F subscription_write_exports >/dev/null 2>&1; then
    subscription_write_exports "$username" >/dev/null
  fi

  ok "Created seller user: $username"
  printf 'Status    : active\n'
  printf 'Expires   : %s\n' "$expires"
  printf 'Protocols : %s\n' "$protocol"
  printf 'Xray UUID : %s\n' "$uuid"
  printf '\nExports:\n'
  printf '  sudo 986 subscription uri %s\n' "$username"
  printf '  sudo 986 subscription mihomo %s\n' "$username"
}

seller_list() {
  seller_ensure_state
  printf '%-20s %-11s %-12s %-18s\n' 'USERNAME' 'STATUS' 'EXPIRES' 'PROTOCOLS'
  printf '%-20s %-11s %-12s %-18s\n' '--------' '------' '-------' '---------'
  awk -F '\t' 'NR>1 {printf "%-20s %-11s %-12s %-18s\n", $1,$2,$3,$4}' "$SELLER_DB"
}

seller_show() {
  seller_ensure_state
  local username="${1:-}" row
  [[ -n "$username" ]] || die "Usage: 986 user show NAME"
  validate_username "$username"
  seller_exists "$username" || die "Unknown seller user: $username"
  row="$(seller_row "$username")"
  IFS=$'\t' read -r username status expires protocols uuid created updated <<< "$row"
  printf 'Username  : %s\n' "$username"
  printf 'Status    : %s\n' "$status"
  printf 'Expires   : %s\n' "$expires"
  printf 'Protocols : %s\n' "$protocols"
  printf 'Xray UUID : %s\n' "$uuid"
  printf 'Created   : %s\n' "$created"
  printf 'Updated   : %s\n' "$updated"
}

seller_suspend() {
  require_root
  seller_ensure_state
  seller_load_reality_server
  local username="${1:-}" row status uuid staged
  [[ -n "$username" ]] || die "Usage: 986 user suspend NAME"
  validate_username "$username"
  seller_exists "$username" || die "Unknown seller user: $username"
  row="$(seller_row "$username")"
  IFS=$'\t' read -r _ status _ _ uuid _ _ <<< "$row"

  case "$status" in
    suspended) die "User is already suspended: $username" ;;
    deleted) die "User is deleted: $username" ;;
  esac

  if seller_xray_identity_present "$username" "$uuid"; then
    staged="$(seller_stage_xray_remove "$username")"
    _xray_apply_config_transaction "$staged" "$XRAY_LISTEN_PORT"
    rm -f "$staged"
  fi
  seller_update_field "$username" 2 suspended
  ok "Suspended seller user: $username"
}

seller_resume() {
  require_root
  seller_ensure_state
  seller_load_reality_server
  local username="${1:-}" row status expires uuid staged today
  [[ -n "$username" ]] || die "Usage: 986 user resume NAME"
  validate_username "$username"
  seller_exists "$username" || die "Unknown seller user: $username"
  row="$(seller_row "$username")"
  IFS=$'\t' read -r _ status expires _ uuid _ _ <<< "$row"
  today="$(date -u +%F)"

  [[ "$status" != active ]] || die "User is already active: $username"
  if [[ "$expires" < "$today" ]]; then
    die "User expired on $expires. Renew it before resume: sudo 986 user renew $username DAYS"
  fi

  if ! seller_xray_identity_present "$username" "$uuid"; then
    staged="$(seller_stage_xray_add "$username" "$uuid")"
    _xray_apply_config_transaction "$staged" "$XRAY_LISTEN_PORT"
    rm -f "$staged"
  fi
  seller_update_field "$username" 2 active
  ok "Resumed seller user: $username"
}

seller_renew() {
  require_root
  seller_ensure_state
  local username="${1:-}" days="${2:-30}" row old_expiry status base expires today
  [[ -n "$username" ]] || die "Usage: 986 user renew NAME [DAYS]"
  validate_username "$username"
  validate_positive_int "$days"
  seller_exists "$username" || die "Unknown seller user: $username"

  row="$(seller_row "$username")"
  IFS=$'\t' read -r _ status old_expiry _ _ _ _ <<< "$row"
  today="$(date -u +%F)"
  base="$today"
  [[ "$old_expiry" > "$today" ]] && base="$old_expiry"
  expires="$(date -u -d "$base +$days days" +%F)"
  seller_update_field "$username" 3 "$expires"

  ok "Renewed $username until $expires"
  if [[ "$status" != active ]]; then
    info "User remains $status. Resume explicitly with: sudo 986 user resume $username"
  fi
}

seller_delete() {
  require_root
  seller_ensure_state
  seller_load_reality_server
  local username="${1:-}" row uuid staged tmp
  [[ -n "$username" ]] || die "Usage: 986 user delete NAME"
  validate_username "$username"
  seller_exists "$username" || die "Unknown seller user: $username"
  row="$(seller_row "$username")"
  uuid="$(printf '%s\n' "$row" | awk -F '\t' '{print $5}')"

  if seller_xray_identity_present "$username" "$uuid"; then
    staged="$(seller_stage_xray_remove "$username")"
    _xray_apply_config_transaction "$staged" "$XRAY_LISTEN_PORT"
    rm -f "$staged"
  fi

  backup_file "$SELLER_DB" sellers
  tmp="$(mktemp "$STATE_DIR/.sellers.XXXXXX")"
  awk -F '\t' -v u="$username" 'NR==1 || $1!=u' "$SELLER_DB" > "$tmp"
  chmod 0600 "$tmp"
  mv -f "$tmp" "$SELLER_DB"
  rm -f "$CONFIG_DIR/clients/$username-vless-reality.txt" "$CONFIG_DIR/clients/$username-mihomo.yaml"
  ok "Deleted seller user: $username"
}

seller_expire() {
  require_root
  seller_ensure_state
  local today names_file count staged emails_json db_tmp
  today="$(date -u +%F)"
  names_file="$(mktemp "$STATE_DIR/.expired.XXXXXX")"
  awk -F '\t' -v today="$today" 'NR>1 && $2=="active" && $3 < today {print $1}' "$SELLER_DB" > "$names_file"
  count="$(awk 'NF {n++} END {print n+0}' "$names_file")"

  if (( count == 0 )); then
    rm -f "$names_file"
    printf 'No active seller users expired before %s.\n' "$today"
    return 0
  fi

  seller_load_reality_server
  emails_json="$(awk 'NF {print $0 "@986.local"}' "$names_file" | jq -Rsc 'split("\n") | map(select(length > 0))')"
  staged="$(mktemp "$XRAY_CONFIG_DIR/.seller-expire.XXXXXX.json")"
  jq --argjson emails "$emails_json" '
    (.inbounds[] | select(.tag == "vless-reality") | .settings.clients) |=
      map(select((.email as $e | ($emails | index($e))) == null))
  ' "$XRAY_CONFIG" > "$staged"
  chmod 0600 "$staged"

  _xray_apply_config_transaction "$staged" "$XRAY_LISTEN_PORT"
  rm -f "$staged"

  db_tmp="$(mktemp "$STATE_DIR/.sellers.XXXXXX")"
  awk -F '\t' -v OFS='\t' -v now="$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    NR==FNR {if (NF) expired[$1]=1; next}
    FNR==1 {print; next}
    $1 in expired {$2="expired"; $7=now}
    {print}
  ' "$names_file" "$SELLER_DB" > "$db_tmp"
  chmod 0600 "$db_tmp"
  mv -f "$db_tmp" "$SELLER_DB"

  while IFS= read -r username; do
    [[ -n "$username" ]] && printf 'Expired: %s\n' "$username"
  done < "$names_file"
  rm -f "$names_file"
  ok "Expired $count seller user(s) without affecting other Xray clients"
}

seller_install_expiry_timer() {
  require_root
  local service_path="/etc/systemd/system/$SELLER_EXPIRY_SERVICE"
  local timer_path="/etc/systemd/system/$SELLER_EXPIRY_TIMER"
  local tmp_service tmp_timer

  tmp_service="$(mktemp /etc/systemd/system/.986-user-expiry.XXXXXX.service)"
  tmp_timer="$(mktemp /etc/systemd/system/.986-user-expiry.XXXXXX.timer)"

  cat > "$tmp_service" <<'EOF_SERVICE'
[Unit]
Description=986 VPS Engine - Seller User Expiry Enforcement
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/986 user expire
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
EOF_SERVICE

  cat > "$tmp_timer" <<'EOF_TIMER'
[Unit]
Description=986 VPS Engine - Seller User Expiry Timer

[Timer]
OnBootSec=10min
OnUnitActiveSec=30min
RandomizedDelaySec=2min
Persistent=true
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF_TIMER

  chmod 0644 "$tmp_service" "$tmp_timer"
  systemd-analyze verify "$tmp_service" "$tmp_timer" >/dev/null
  mv -f "$tmp_service" "$service_path"
  mv -f "$tmp_timer" "$timer_path"
  systemctl daemon-reload
  systemctl enable --now "$SELLER_EXPIRY_TIMER" >/dev/null
  ok "Seller expiry timer enabled: $SELLER_EXPIRY_TIMER"
}

seller_timer_status() {
  if systemctl is-enabled --quiet "$SELLER_EXPIRY_TIMER" 2>/dev/null; then
    printf 'Expiry timer : enabled\n'
  else
    printf 'Expiry timer : not enabled\n'
  fi
  systemctl list-timers "$SELLER_EXPIRY_TIMER" --no-pager 2>/dev/null || true
}

seller_summary() {
  seller_ensure_state
  local total active suspended expired
  total="$(awk 'NR>1 {n++} END {print n+0}' "$SELLER_DB")"
  active="$(awk -F '\t' 'NR>1 && $2=="active" {n++} END {print n+0}' "$SELLER_DB")"
  suspended="$(awk -F '\t' 'NR>1 && $2=="suspended" {n++} END {print n+0}' "$SELLER_DB")"
  expired="$(awk -F '\t' 'NR>1 && $2=="expired" {n++} END {print n+0}' "$SELLER_DB")"
  printf 'Seller users     : %s total / %s active / %s suspended / %s expired\n' "$total" "$active" "$suspended" "$expired"
}
