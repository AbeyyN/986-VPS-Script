#!/usr/bin/env bash

seller_protocols_has() {
  local username="$1" protocol="$2" protocols
  protocols="$(seller_field "$username" 4)"
  [[ ",$protocols," == *",$protocol,"* ]]
}

seller_protocols_add() {
  local username="$1" protocol="$2" protocols
  protocols="$(seller_field "$username" 4)"
  if [[ ",$protocols," == *",$protocol,"* ]]; then
    return 0
  fi
  if [[ -n "$protocols" ]]; then
    protocols="$protocols,$protocol"
  else
    protocols="$protocol"
  fi
  seller_update_field "$username" 4 "$protocols"
}

seller_protocols_remove() {
  local username="$1" protocol="$2" protocols new="" item
  protocols="$(seller_field "$username" 4)"
  IFS=',' read -r -a items <<< "$protocols"
  for item in "${items[@]}"; do
    [[ -z "$item" || "$item" == "$protocol" ]] && continue
    [[ -n "$new" ]] && new+=','
    new+="$item"
  done
  seller_update_field "$username" 4 "$new"
}

_seller_copy_file_or_empty() {
  local src="$1" dest="$2"
  if [[ -f "$src" ]]; then
    cp -a "$src" "$dest"
  else
    : > "$dest"
  fi
}

_seller_restore_file_snapshot() {
  local snapshot="$1" dest="$2"
  if [[ -s "$snapshot" ]]; then
    cp -a "$snapshot" "$dest"
  else
    rm -f "$dest"
  fi
}

seller_protocol_add() {
  require_root
  local username="${1:-}" protocol="${2:-}"
  local seller_snapshot hysteria_snapshot
  [[ -n "$username" && -n "$protocol" ]] || die "Usage: 986 user protocol add NAME PROTOCOL"
  validate_username "$username"
  seller_exists "$username" || die "Unknown seller user: $username"

  case "$protocol" in
    hysteria2)
      [[ -x "$HYSTERIA_BIN" && -s "$HYSTERIA_CONFIG" && -r "$HYSTERIA_PROFILE_FILE" ]] \
        || die "Hysteria2 must be installed and bootstrapped before assigning it to seller users."
      seller_protocols_has "$username" hysteria2 && die "User already has Hysteria2: $username"

      seller_snapshot="$(mktemp "$STATE_DIR/.seller-proto.XXXXXX")"
      hysteria_snapshot="$(mktemp "$STATE_DIR/.hy2-users.XXXXXX")"
      _seller_copy_file_or_empty "$SELLER_DB" "$seller_snapshot"
      _seller_copy_file_or_empty "$HYSTERIA_USERS_DB" "$hysteria_snapshot"

      hysteria_credential_add "$username"
      seller_protocols_add "$username" hysteria2
      if ! (hysteria_reconcile); then
        _seller_restore_file_snapshot "$seller_snapshot" "$SELLER_DB"
        _seller_restore_file_snapshot "$hysteria_snapshot" "$HYSTERIA_USERS_DB"
        (hysteria_reconcile) >/dev/null 2>&1 || true
        rm -f "$seller_snapshot" "$hysteria_snapshot"
        die "Hysteria2 assignment failed and seller/credential state was rolled back."
      fi
      rm -f "$seller_snapshot" "$hysteria_snapshot"
      ok "Assigned Hysteria2 to seller user: $username"
      printf 'Hysteria2 URI: sudo 986 subscription hysteria2 %s\n' "$username"
      ;;
    *) die "Unsupported protocol assignment: $protocol. Available: hysteria2" ;;
  esac
}

seller_protocol_remove() {
  require_root
  local username="${1:-}" protocol="${2:-}"
  local seller_snapshot hysteria_snapshot
  [[ -n "$username" && -n "$protocol" ]] || die "Usage: 986 user protocol remove NAME PROTOCOL"
  validate_username "$username"
  seller_exists "$username" || die "Unknown seller user: $username"

  case "$protocol" in
    hysteria2)
      seller_protocols_has "$username" hysteria2 || die "User does not have Hysteria2: $username"
      seller_snapshot="$(mktemp "$STATE_DIR/.seller-proto.XXXXXX")"
      hysteria_snapshot="$(mktemp "$STATE_DIR/.hy2-users.XXXXXX")"
      _seller_copy_file_or_empty "$SELLER_DB" "$seller_snapshot"
      _seller_copy_file_or_empty "$HYSTERIA_USERS_DB" "$hysteria_snapshot"

      hysteria_credential_remove "$username"
      seller_protocols_remove "$username" hysteria2
      if [[ -s "$HYSTERIA_CONFIG" ]] && ! (hysteria_reconcile); then
        _seller_restore_file_snapshot "$seller_snapshot" "$SELLER_DB"
        _seller_restore_file_snapshot "$hysteria_snapshot" "$HYSTERIA_USERS_DB"
        (hysteria_reconcile) >/dev/null 2>&1 || true
        rm -f "$seller_snapshot" "$hysteria_snapshot"
        die "Hysteria2 removal failed and seller/credential state was rolled back."
      fi
      rm -f "$seller_snapshot" "$hysteria_snapshot"
      ok "Removed Hysteria2 from seller user: $username"
      ;;
    *) die "Unsupported protocol removal: $protocol. Available: hysteria2" ;;
  esac
}

seller_multi_suspend() {
  local username="${1:-}" had_hysteria=false
  seller_protocols_has "$username" hysteria2 && had_hysteria=true
  seller_suspend "$username"
  if [[ "$had_hysteria" == true && -s "$HYSTERIA_CONFIG" ]]; then
    if ! (hysteria_reconcile); then
      warn "Hysteria2 reconcile failed; rolling seller suspension back."
      (seller_resume "$username") || true
      (hysteria_reconcile) >/dev/null 2>&1 || true
      die "Cross-engine suspend failed; rollback was attempted. Run: sudo 986 doctor"
    fi
  fi
}

seller_multi_resume() {
  local username="${1:-}" had_hysteria=false
  seller_protocols_has "$username" hysteria2 && had_hysteria=true
  seller_resume "$username"
  if [[ "$had_hysteria" == true && -s "$HYSTERIA_CONFIG" ]]; then
    if ! (hysteria_reconcile); then
      warn "Hysteria2 reconcile failed; rolling seller resume back."
      (seller_suspend "$username") || true
      (hysteria_reconcile) >/dev/null 2>&1 || true
      die "Cross-engine resume failed; rollback was attempted. Run: sudo 986 doctor"
    fi
  fi
}

seller_multi_delete() {
  require_root
  local username="${1:-}" had_hysteria=false hysteria_snapshot=""
  validate_username "$username"
  seller_exists "$username" || die "Unknown seller user: $username"
  seller_protocols_has "$username" hysteria2 && had_hysteria=true

  if [[ "$had_hysteria" == true ]]; then
    hysteria_snapshot="$(mktemp "$STATE_DIR/.hy2-users.XXXXXX")"
    _seller_copy_file_or_empty "$HYSTERIA_USERS_DB" "$hysteria_snapshot"
    hysteria_credential_remove "$username"
    if [[ -s "$HYSTERIA_CONFIG" ]] && ! (hysteria_reconcile); then
      _seller_restore_file_snapshot "$hysteria_snapshot" "$HYSTERIA_USERS_DB"
      (hysteria_reconcile) >/dev/null 2>&1 || true
      rm -f "$hysteria_snapshot"
      die "Hysteria2 credential removal failed; seller was not deleted."
    fi
  fi

  if ! (seller_delete "$username"); then
    if [[ "$had_hysteria" == true ]]; then
      _seller_restore_file_snapshot "$hysteria_snapshot" "$HYSTERIA_USERS_DB"
      (hysteria_reconcile) >/dev/null 2>&1 || true
      rm -f "$hysteria_snapshot"
    fi
    die "Seller deletion failed; Hysteria2 restoration was attempted. Run: sudo 986 doctor"
  fi
  [[ -n "$hysteria_snapshot" ]] && rm -f "$hysteria_snapshot"
}

seller_multi_expire() {
  require_root
  seller_ensure_state
  local today due snapshot tmp count
  today="$(date -u +%F)"
  due="$(mktemp "$STATE_DIR/.expire-multi.XXXXXX")"
  awk -F '\t' -v today="$today" 'NR>1 && $2=="active" && $3 < today {print $1}' "$SELLER_DB" > "$due"
  count="$(awk 'NF {n++} END {print n+0}' "$due")"
  if (( count == 0 )); then
    rm -f "$due"
    seller_expire
    return
  fi

  if [[ -s "$HYSTERIA_CONFIG" ]]; then
    snapshot="$(mktemp "$STATE_DIR/.seller-expire-snapshot.XXXXXX")"
    cp -a "$SELLER_DB" "$snapshot"
    tmp="$(mktemp "$STATE_DIR/.seller-expire-stage.XXXXXX")"
    awk -F '\t' -v OFS='\t' '
      NR==FNR {if (NF) due[$1]=1; next}
      FNR==1 {print; next}
      $1 in due {$2="expired"}
      {print}
    ' "$due" "$SELLER_DB" > "$tmp"
    chmod 0600 "$tmp"
    mv -f "$tmp" "$SELLER_DB"

    if ! (hysteria_reconcile); then
      cp -a "$snapshot" "$SELLER_DB"
      rm -f "$snapshot" "$due"
      die "Expiry was not applied because Hysteria2 could not reconcile safely."
    fi
    cp -a "$snapshot" "$SELLER_DB"
  fi

  if ! (seller_expire); then
    if [[ -n "${snapshot:-}" ]]; then
      cp -a "$snapshot" "$SELLER_DB"
      (hysteria_reconcile) >/dev/null 2>&1 || true
    fi
    rm -f "${snapshot:-}" "$due"
    die "Xray expiry transaction failed; Hysteria2 restoration was attempted. Run: sudo 986 doctor"
  fi

  rm -f "${snapshot:-}" "$due"
}

seller_multi_protocol_status() {
  local username="${1:-}" protocols
  [[ -n "$username" ]] || die "Usage: 986 user protocol list NAME"
  validate_username "$username"
  seller_exists "$username" || die "Unknown seller user: $username"
  protocols="$(seller_field "$username" 4)"
  printf 'User      : %s\n' "$username"
  printf 'Protocols : %s\n' "${protocols:-none}"
  if seller_protocols_has "$username" hysteria2; then
    if hysteria_user_exists "$username"; then
      printf 'Hysteria2 : credential ready\n'
    else
      printf 'Hysteria2 : ERROR - assigned but credential missing\n'
    fi
  fi
}
