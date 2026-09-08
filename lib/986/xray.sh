#!/usr/bin/env bash

XRAY_STABLE_VERSION="v26.3.27"
XRAY_STABLE_SHA256_AMD64="23cd9af937744d97776ee35ecad4972cf4b2109d1e0fe6be9930467608f7c8ae"
XRAY_VENDOR_ROOT="$INSTALL_ROOT/vendor/xray"
XRAY_CURRENT="$XRAY_VENDOR_ROOT/current"
XRAY_BIN="$XRAY_CURRENT/xray"
XRAY_CONFIG_DIR="$CONFIG_DIR/xray"
XRAY_CONFIG="$XRAY_CONFIG_DIR/config.json"
XRAY_KEY_DIR="$STATE_DIR/keys/xray"
XRAY_PROFILE_FILE="$STATE_DIR/xray-profile.env"
XRAY_SERVICE="986-xray.service"
XRAY_UNIT="/etc/systemd/system/$XRAY_SERVICE"
XRAY_USER="986-xray"
export XRAY_STABLE_VERSION XRAY_VENDOR_ROOT XRAY_CURRENT XRAY_BIN XRAY_CONFIG_DIR XRAY_CONFIG XRAY_KEY_DIR XRAY_PROFILE_FILE XRAY_SERVICE XRAY_UNIT XRAY_USER

_xray_require_dependencies() {
  local cmd
  for cmd in curl unzip sha256sum jq openssl systemctl ss flock getent useradd install mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || die "Xray dependency is missing: $cmd"
  done
}

_xray_ensure_user() {
  if ! getent passwd "$XRAY_USER" >/dev/null 2>&1; then
    useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin "$XRAY_USER"
  fi
}

_xray_prepare_dirs() {
  _xray_ensure_user
  install -d -m 0755 "$XRAY_VENDOR_ROOT"
  install -d -m 0750 -o root -g "$XRAY_USER" "$XRAY_CONFIG_DIR"
  install -d -m 0700 "$XRAY_KEY_DIR"
}

_xray_release_metadata() {
  local channel="${1:-stable}"
  case "$channel" in
    stable)
      printf '%s\t%s\t%s\n' \
        "$XRAY_STABLE_VERSION" \
        "https://github.com/XTLS/Xray-core/releases/download/$XRAY_STABLE_VERSION/Xray-linux-64.zip" \
        "$XRAY_STABLE_SHA256_AMD64"
      ;;
    *) die "Unsupported Xray channel: $channel. Available: stable" ;;
  esac
}

_xray_version_text() {
  local bin="${1:-$XRAY_BIN}"
  [[ -x "$bin" ]] || return 1
  "$bin" version 2>/dev/null | head -n 1
}

_xray_validate_config_with() {
  local bin="$1" asset_dir="$2" config="$3"
  [[ -x "$bin" ]] || return 1
  [[ -s "$config" ]] || return 1
  jq -e . "$config" >/dev/null 2>&1 || return 1
  XRAY_LOCATION_ASSET="$asset_dir" "$bin" run -test -config "$config" >/dev/null 2>&1
}

_xray_validate_config() {
  _xray_validate_config_with "$XRAY_BIN" "$XRAY_CURRENT" "$XRAY_CONFIG"
}

_xray_write_unit() {
  local tmp
  tmp="$(mktemp /etc/systemd/system/.986-xray.XXXXXX)"
  cat > "$tmp" <<EOF_UNIT
[Unit]
Description=986 VPS Engine - Xray Core
Documentation=https://github.com/AbeyyN/986-VPS-Script
Wants=network-online.target
After=network-online.target
ConditionPathExists=$XRAY_CONFIG
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
User=$XRAY_USER
Group=$XRAY_USER
Environment=XRAY_LOCATION_ASSET=$XRAY_CURRENT
ExecStartPre=$XRAY_BIN run -test -config $XRAY_CONFIG
ExecStart=$XRAY_BIN run -config $XRAY_CONFIG
Restart=on-failure
RestartSec=3s
TimeoutStopSec=20s
KillSignal=SIGTERM
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=true
RestrictSUIDSGID=true
LockPersonality=true
SystemCallArchitectures=native
LimitNOFILE=1048576
LimitCORE=0
TasksMax=4096
StandardOutput=journal
StandardError=journal
SyslogIdentifier=986-xray

[Install]
WantedBy=multi-user.target
EOF_UNIT
  chmod 0644 "$tmp"
  systemd-analyze verify "$tmp" >/dev/null
  mv -f "$tmp" "$XRAY_UNIT"
  systemctl daemon-reload
}

_xray_health_check() {
  local tries="${1:-5}"
  local i
  for ((i=1; i<=tries; i++)); do
    if systemctl is-active --quiet "$XRAY_SERVICE" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

_xray_switch_current() {
  local target="$1"
  local tmp_link="$XRAY_VENDOR_ROOT/.current.new"
  rm -f "$tmp_link"
  ln -s "$target" "$tmp_link"
  mv -Tf "$tmp_link" "$XRAY_CURRENT"
}

xray_install() {
  local channel="${1:-stable}"
  local metadata version url expected tmpdir archive version_dir previous current_version

  require_root
  _xray_require_dependencies
  registry_ensure_state
  _xray_prepare_dirs

  exec 8>"$STATE_DIR/xray-install.lock"
  flock -n 8 || die "Another 986 Xray operation is already running."

  metadata="$(_xray_release_metadata "$channel")"
  IFS=$'\t' read -r version url expected <<< "$metadata"
  version_dir="$XRAY_VENDOR_ROOT/$version"
  current_version="$(_xray_version_text 2>/dev/null || true)"

  if [[ -x "$version_dir/xray" ]]; then
    ok "Xray $version is already staged"
  else
    tmpdir="$(mktemp -d)"
    archive="$tmpdir/xray.zip"
    info "Downloading official XTLS/Xray-core $version ($channel channel)..."
    if ! curl --fail --show-error --location --retry 3 --retry-delay 2 "$url" -o "$archive"; then
      rm -rf "$tmpdir"
      die "Failed to download Xray from official upstream."
    fi

    if ! printf '%s  %s\n' "$expected" "$archive" | sha256sum -c - >/dev/null; then
      rm -rf "$tmpdir"
      die "Xray SHA-256 verification failed. Nothing was installed."
    fi

    if ! unzip -q "$archive" -d "$tmpdir/unpacked"; then
      rm -rf "$tmpdir"
      die "Failed to extract verified Xray archive."
    fi
    [[ -x "$tmpdir/unpacked/xray" ]] || { rm -rf "$tmpdir"; die "Verified archive does not contain an executable xray binary."; }

    if ! "$tmpdir/unpacked/xray" version 2>/dev/null | head -n 1 | grep -Fq "${version#v}"; then
      rm -rf "$tmpdir"
      die "Downloaded Xray binary version does not match $version."
    fi

    install -d -m 0755 "$version_dir"
    install -m 0755 "$tmpdir/unpacked/xray" "$version_dir/xray"
    [[ -f "$tmpdir/unpacked/geoip.dat" ]] && install -m 0644 "$tmpdir/unpacked/geoip.dat" "$version_dir/geoip.dat"
    [[ -f "$tmpdir/unpacked/geosite.dat" ]] && install -m 0644 "$tmpdir/unpacked/geosite.dat" "$version_dir/geosite.dat"
    printf '%s\n' "$expected" > "$version_dir/archive.sha256"
    printf '%s\n' "$url" > "$version_dir/source.url"
    chmod 0644 "$version_dir/archive.sha256" "$version_dir/source.url"
    rm -rf "$tmpdir"
    ok "Verified Xray $version staged"
  fi

  previous="$(readlink -f "$XRAY_CURRENT" 2>/dev/null || true)"
  if [[ -s "$XRAY_CONFIG" ]]; then
    _xray_validate_config_with "$version_dir/xray" "$version_dir" "$XRAY_CONFIG" || die "Existing Xray configuration is not valid with $version. Current runtime was preserved."
  fi

  _xray_switch_current "$version_dir"
  _xray_write_unit

  if [[ -s "$XRAY_CONFIG" ]]; then
    if ! systemctl restart "$XRAY_SERVICE" || ! _xray_health_check 5; then
      warn "Xray $version failed runtime health verification. Rolling back binary."
      if [[ -n "$previous" && -x "$previous/xray" ]]; then
        _xray_switch_current "$previous"
        _xray_write_unit
        systemctl restart "$XRAY_SERVICE" || true
      else
        systemctl disable --now "$XRAY_SERVICE" >/dev/null 2>&1 || true
      fi
      die "Xray upgrade rolled back. Inspect: journalctl -u $XRAY_SERVICE -n 100"
    fi
  fi

  registry_service_set xray xray "$XRAY_SERVICE" installed
  ok "Xray runtime ready: $(_xray_version_text)"
  if [[ -z "$current_version" ]]; then
    info "Next: sudo 986 xray bootstrap reality --server-name HOST --target HOST:443"
  fi
}

_xray_validate_reality_inputs() {
  local server_name="$1" target="$2" port="$3" client_name="$4"
  local target_port endpoint
  [[ "$server_name" =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$ ]] || die "Invalid REALITY server name: $server_name"
  [[ "$target" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*:[0-9]{1,5}$ ]] || die "REALITY target must look like host.example:443"
  target_port="${target##*:}"
  registry_validate_port "$target_port"
  registry_validate_port "$port"
  validate_username "$client_name"

  load_config
  endpoint="${PUBLIC_ENDPOINT:-}"
  if [[ -n "$endpoint" && ! "$endpoint" =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$ ]]; then
    die "PUBLIC_ENDPOINT must currently be an IPv4 address or DNS hostname."
  fi
}

_xray_public_endpoint() {
  load_config
  if [[ -n "${PUBLIC_ENDPOINT:-}" ]]; then
    printf '%s\n' "$PUBLIC_ENDPOINT"
    return
  fi
  curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true
}

_xray_apply_config_transaction() {
  local staged="$1" port="$2"
  local rollback="" had_old="false"

  _xray_validate_config_with "$XRAY_BIN" "$XRAY_CURRENT" "$staged" || die "Generated Xray configuration failed upstream validation. Existing service was not changed."
  registry_assert_port_available tcp "$port" xray

  if [[ -f "$XRAY_CONFIG" ]]; then
    had_old="true"
    rollback="$(mktemp "$XRAY_CONFIG_DIR/.config.rollback.XXXXXX")"
    cp -a "$XRAY_CONFIG" "$rollback"
    backup_file "$XRAY_CONFIG" xray-config
  fi

  install -m 0640 -o root -g "$XRAY_USER" "$staged" "$XRAY_CONFIG"
  systemctl enable "$XRAY_SERVICE" >/dev/null

  if ! systemctl restart "$XRAY_SERVICE" || ! _xray_health_check 5; then
    warn "New Xray configuration failed runtime health verification. Rolling back configuration."
    if [[ "$had_old" == 'true' ]]; then
      install -m 0640 -o root -g "$XRAY_USER" "$rollback" "$XRAY_CONFIG"
      systemctl restart "$XRAY_SERVICE" || true
    else
      rm -f "$XRAY_CONFIG"
      systemctl disable --now "$XRAY_SERVICE" >/dev/null 2>&1 || true
    fi
    [[ -n "$rollback" ]] && rm -f "$rollback"
    die "Configuration rolled back. Inspect: journalctl -u $XRAY_SERVICE -n 100"
  fi

  [[ -n "$rollback" ]] && rm -f "$rollback"
  registry_port_remove_owner xray
  registry_port_set tcp "$port" xray
  registry_service_set xray xray "$XRAY_SERVICE" active
}

xray_bootstrap_reality() {
  local server_name="" target="" port="443" client_name="bootstrap"
  local uuid key_output private_key public_key short_id endpoint staged client_file encoded_name uri

  require_root
  _xray_require_dependencies
  registry_ensure_state
  _xray_prepare_dirs
  [[ -x "$XRAY_BIN" ]] || die "Xray is not installed. Run: sudo 986 xray install"

  shift || true
  while (($#)); do
    case "$1" in
      --server-name) [[ $# -ge 2 ]] || die "--server-name requires a value"; server_name="$2"; shift 2 ;;
      --target) [[ $# -ge 2 ]] || die "--target requires a value"; target="$2"; shift 2 ;;
      --port) [[ $# -ge 2 ]] || die "--port requires a value"; port="$2"; shift 2 ;;
      --name) [[ $# -ge 2 ]] || die "--name requires a value"; client_name="$2"; shift 2 ;;
      *) die "Unknown REALITY option: $1" ;;
    esac
  done

  [[ -n "$server_name" ]] || die "Missing --server-name. Use the TLS hostname presented by your chosen REALITY target."
  [[ -n "$target" ]] || die "Missing --target. Example format: host.example:443"
  _xray_validate_reality_inputs "$server_name" "$target" "$port" "$client_name"

  endpoint="$(_xray_public_endpoint)"
  [[ -n "$endpoint" ]] || die "Unable to detect public IPv4. Set PUBLIC_ENDPOINT in $CONFIG_FILE."
  [[ "$endpoint" =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$ ]] || die "Detected PUBLIC_ENDPOINT is not a supported IPv4/hostname value: $endpoint"

  uuid="$($XRAY_BIN uuid | head -n 1 | tr -d '\r')"
  [[ "$uuid" =~ ^[0-9a-fA-F-]{36}$ ]] || die "Xray returned an unexpected UUID."

  key_output="$($XRAY_BIN x25519)"
  private_key="$(awk -F': *' '/PrivateKey/ {print $2; exit}' <<< "$key_output")"
  public_key="$(awk -F': *' '/Password|PublicKey/ {print $2; exit}' <<< "$key_output")"
  [[ -n "$private_key" && -n "$public_key" ]] || die "Unable to parse Xray REALITY X25519 keypair."
  short_id="$(openssl rand -hex 8)"

  staged="$(mktemp "$XRAY_CONFIG_DIR/.config.XXXXXX.json")"
  jq -n \
    --arg uuid "$uuid" \
    --arg target "$target" \
    --arg server_name "$server_name" \
    --arg private_key "$private_key" \
    --arg short_id "$short_id" \
    --argjson port "$port" \
    '{
      log: {loglevel: "warning"},
      inbounds: [{
        tag: "vless-reality",
        listen: "0.0.0.0",
        port: $port,
        protocol: "vless",
        settings: {
          clients: [{id: $uuid, flow: "xtls-rprx-vision", email: "bootstrap@986.local"}],
          decryption: "none"
        },
        streamSettings: {
          network: "tcp",
          security: "reality",
          realitySettings: {
            show: false,
            dest: $target,
            xver: 0,
            serverNames: [$server_name],
            privateKey: $private_key,
            shortIds: [$short_id]
          }
        },
        sniffing: {
          enabled: true,
          destOverride: ["http", "tls", "quic"],
          routeOnly: true
        }
      }],
      outbounds: [
        {tag: "direct", protocol: "freedom"},
        {tag: "block", protocol: "blackhole"}
      ]
    }' > "$staged"
  chmod 0600 "$staged"

  _xray_apply_config_transaction "$staged" "$port"
  rm -f "$staged"

  cat > "$XRAY_PROFILE_FILE" <<EOF_PROFILE
XRAY_PROFILE_NAME=vless-reality
XRAY_LISTEN_PORT=$port
XRAY_SERVER_NAME=$server_name
XRAY_TARGET=$target
XRAY_CLIENT_NAME=$client_name
XRAY_CLIENT_UUID=$uuid
XRAY_REALITY_PUBLIC_KEY=$public_key
XRAY_REALITY_SHORT_ID=$short_id
XRAY_PUBLIC_ENDPOINT=$endpoint
EOF_PROFILE
  chmod 0600 "$XRAY_PROFILE_FILE"

  encoded_name="$(printf '%s' "986-$client_name" | jq -sRr @uri)"
  uri="vless://$uuid@$endpoint:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp#$encoded_name"
  client_file="$CONFIG_DIR/clients/$client_name-vless-reality.txt"
  umask 077
  printf '%s\n' "$uri" > "$client_file"

  ok "VLESS REALITY / XTLS Vision profile is active on TCP/$port"
  printf 'Client          : %s\n' "$client_name"
  printf 'Endpoint        : %s:%s\n' "$endpoint" "$port"
  printf 'Server name     : %s\n' "$server_name"
  printf 'Target          : %s\n' "$target"
  printf 'Client URI file : %s\n' "$client_file"
  printf '\n%s\n' "$uri"
}

xray_show_client() {
  local name="${1:-}" file
  require_root
  if [[ -z "$name" && -r "$XRAY_PROFILE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$XRAY_PROFILE_FILE"
    name="${XRAY_CLIENT_NAME:-}"
  fi
  [[ -n "$name" ]] || die "Specify a client name."
  validate_username "$name"
  file="$CONFIG_DIR/clients/$name-vless-reality.txt"
  [[ -r "$file" ]] || die "No VLESS REALITY client URI found for: $name"
  cat "$file"
}

xray_restart() {
  require_root
  [[ -s "$XRAY_CONFIG" ]] || die "Xray is not configured."
  _xray_validate_config || die "Xray configuration validation failed; restart was refused."
  systemctl restart "$XRAY_SERVICE"
  _xray_health_check 5 || die "Xray did not remain healthy after restart."
  registry_service_set xray xray "$XRAY_SERVICE" active
  ok "Xray restarted and remained active"
}

xray_status() {
  local version='not installed' profile='not configured' port='-'
  [[ -x "$XRAY_BIN" ]] && version="$(_xray_version_text)"
  if [[ -r "$XRAY_PROFILE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$XRAY_PROFILE_FILE"
    profile="${XRAY_PROFILE_NAME:-unknown}"
    port="${XRAY_LISTEN_PORT:-?}"
  fi

  printf 'Xray runtime   : %s\n' "$version"
  printf '986 profile    : %s\n' "$profile"
  printf 'Listen port    : %s\n' "$port"
  if systemctl is-active --quiet "$XRAY_SERVICE" 2>/dev/null; then
    printf 'Service        : active\n'
  elif [[ -s "$XRAY_CONFIG" ]]; then
    printf 'Service        : configured / inactive\n'
  else
    printf 'Service        : not configured\n'
  fi
  printf 'Config         : %s\n' "$XRAY_CONFIG"
}

xray_doctor() {
  local failures=0 warnings=0 port=''
  printf 'Xray diagnostics\n\n'

  if [[ -x "$XRAY_BIN" ]]; then
    ok "$(_xray_version_text)"
  else
    warn 'Xray runtime is not installed'
    ((warnings+=1))
  fi

  if [[ -s "$XRAY_CONFIG" ]]; then
    if _xray_validate_config; then ok 'Configuration passes xray run -test'; else fail 'Configuration validation failed'; ((failures+=1)); fi
  else
    warn 'Xray profile is not configured'
    ((warnings+=1))
  fi

  if [[ -r "$XRAY_PROFILE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$XRAY_PROFILE_FILE"
    port="${XRAY_LISTEN_PORT:-}"
    if [[ -n "$port" ]] && registry_port_bound tcp "$port"; then ok "TCP/$port is listening"; else warn "Expected Xray listen port is not active: TCP/${port:-?}"; ((warnings+=1)); fi
  fi

  if systemctl is-active --quiet "$XRAY_SERVICE" 2>/dev/null; then ok "$XRAY_SERVICE is active"; else warn "$XRAY_SERVICE is not active"; ((warnings+=1)); fi

  printf '\nResult: %d failure(s), %d warning(s)\n' "$failures" "$warnings"
  (( failures == 0 ))
}
