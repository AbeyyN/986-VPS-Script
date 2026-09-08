#!/usr/bin/env bash

HYSTERIA_STABLE_VERSION="v2.12.2"
HYSTERIA_STABLE_SHA256_AMD64="6493dfffd55b5883f64c76c63880ecc32988f0c568c9ca9014907877b4d55f94"
HYSTERIA_VENDOR_ROOT="/opt/986-vps/hysteria"
HYSTERIA_CURRENT="$HYSTERIA_VENDOR_ROOT/current"
HYSTERIA_BIN="$HYSTERIA_CURRENT/hysteria"
HYSTERIA_CONFIG_DIR="$CONFIG_DIR/hysteria"
HYSTERIA_CONFIG="$HYSTERIA_CONFIG_DIR/config.yaml"
HYSTERIA_PROFILE_FILE="$STATE_DIR/hysteria-profile.env"
HYSTERIA_SERVICE="986-hysteria.service"
HYSTERIA_UNIT="/etc/systemd/system/$HYSTERIA_SERVICE"
HYSTERIA_USER="986-hysteria"
export HYSTERIA_STABLE_VERSION HYSTERIA_VENDOR_ROOT HYSTERIA_CURRENT HYSTERIA_BIN HYSTERIA_CONFIG_DIR HYSTERIA_CONFIG HYSTERIA_PROFILE_FILE HYSTERIA_SERVICE HYSTERIA_UNIT HYSTERIA_USER

_hysteria_require_dependencies() {
  local cmd
  for cmd in curl sha256sum systemctl systemd-analyze ss flock getent useradd install mktemp openssl awk grep; do
    command -v "$cmd" >/dev/null 2>&1 || die "Hysteria2 dependency is missing: $cmd"
  done
}

_hysteria_ensure_user() {
  if ! getent passwd "$HYSTERIA_USER" >/dev/null 2>&1; then
    useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin "$HYSTERIA_USER"
  fi
}

_hysteria_prepare_dirs() {
  _hysteria_ensure_user
  install -d -m 0755 "$HYSTERIA_VENDOR_ROOT"
  install -d -m 0750 -o root -g "$HYSTERIA_USER" "$HYSTERIA_CONFIG_DIR"
}

_hysteria_release_metadata() {
  local channel="${1:-stable}"
  case "$channel" in
    stable)
      printf '%s\t%s\t%s\n' \
        "$HYSTERIA_STABLE_VERSION" \
        "https://github.com/HyNetworks/hysteria/releases/download/app/$HYSTERIA_STABLE_VERSION/hysteria-linux-amd64" \
        "$HYSTERIA_STABLE_SHA256_AMD64"
      ;;
    *) die "Unsupported Hysteria2 channel: $channel. Available: stable" ;;
  esac
}

_hysteria_version_text() {
  [[ -x "$HYSTERIA_BIN" ]] || return 1
  "$HYSTERIA_BIN" version 2>/dev/null | head -n 1
}

_hysteria_candidate_version_text() {
  local bin="$1"
  "$bin" version 2>/dev/null | head -n 1
}

_hysteria_check_config_shape() {
  local config="$1"
  [[ -s "$config" ]] || return 1
  grep -Eq '^listen:[[:space:]]*' "$config" || return 1
  grep -Eq '^auth:[[:space:]]*$' "$config" || return 1
  grep -Eq '^[[:space:]]+type:[[:space:]]+userpass[[:space:]]*$' "$config" || return 1
  grep -Eq '^tls:[[:space:]]*$' "$config" || return 1
}

_hysteria_write_unit() {
  local tmp
  tmp="$(mktemp /etc/systemd/system/.986-hysteria.XXXXXX)"
  cat > "$tmp" <<EOF_UNIT
[Unit]
Description=986 VPS Engine - Hysteria2
Documentation=https://github.com/AbeyyN/986-VPS-Script
Wants=network-online.target
After=network-online.target
ConditionPathExists=$HYSTERIA_CONFIG
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
User=$HYSTERIA_USER
Group=$HYSTERIA_USER
ExecStart=$HYSTERIA_BIN server -c $HYSTERIA_CONFIG --disable-update-check
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
SyslogIdentifier=986-hysteria

[Install]
WantedBy=multi-user.target
EOF_UNIT
  chmod 0644 "$tmp"
  systemd-analyze verify "$tmp" >/dev/null
  mv -f "$tmp" "$HYSTERIA_UNIT"
  systemctl daemon-reload
}

_hysteria_health_check() {
  local tries="${1:-5}" i
  for ((i=1; i<=tries; i++)); do
    if systemctl is-active --quiet "$HYSTERIA_SERVICE" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

_hysteria_switch_current() {
  local target="$1" tmp_link="$HYSTERIA_VENDOR_ROOT/.current.new"
  rm -f "$tmp_link"
  ln -s "$target" "$tmp_link"
  mv -Tf "$tmp_link" "$HYSTERIA_CURRENT"
}

hysteria_install() {
  local channel="${1:-stable}" metadata version url expected tmp binary version_dir previous
  require_root
  _hysteria_require_dependencies
  registry_ensure_state
  _hysteria_prepare_dirs

  exec 8>"$STATE_DIR/hysteria-install.lock"
  flock -n 8 || die "Another 986 Hysteria2 operation is already running."

  metadata="$(_hysteria_release_metadata "$channel")"
  IFS=$'\t' read -r version url expected <<< "$metadata"
  version_dir="$HYSTERIA_VENDOR_ROOT/$version"

  if [[ -x "$version_dir/hysteria" ]]; then
    ok "Hysteria2 $version is already staged"
  else
    tmp="$(mktemp -d)"
    binary="$tmp/hysteria"
    info "Downloading official HyNetworks/hysteria $version ($channel channel)..."
    if ! curl --fail --show-error --location --retry 3 --retry-delay 2 "$url" -o "$binary"; then
      rm -rf "$tmp"
      die "Failed to download Hysteria2 from official upstream."
    fi
    if ! printf '%s  %s\n' "$expected" "$binary" | sha256sum -c - >/dev/null; then
      rm -rf "$tmp"
      die "Hysteria2 SHA-256 verification failed. Nothing was installed."
    fi
    chmod 0755 "$binary"
    if ! _hysteria_candidate_version_text "$binary" | grep -Fq "${version#v}"; then
      rm -rf "$tmp"
      die "Downloaded Hysteria2 binary version does not match $version."
    fi
    install -d -m 0755 "$version_dir"
    install -m 0755 "$binary" "$version_dir/hysteria"
    printf '%s\n' "$expected" > "$version_dir/archive.sha256"
    printf '%s\n' "$url" > "$version_dir/source.url"
    chmod 0644 "$version_dir/archive.sha256" "$version_dir/source.url"
    rm -rf "$tmp"
    ok "Verified Hysteria2 $version staged"
  fi

  previous="$(readlink -f "$HYSTERIA_CURRENT" 2>/dev/null || true)"
  _hysteria_switch_current "$version_dir"
  _hysteria_write_unit

  if [[ -s "$HYSTERIA_CONFIG" ]]; then
    _hysteria_check_config_shape "$HYSTERIA_CONFIG" || die "Existing Hysteria2 config shape is invalid; runtime switch was not started."
    if ! systemctl restart "$HYSTERIA_SERVICE" || ! _hysteria_health_check 5; then
      warn "Hysteria2 $version failed health verification. Rolling back binary."
      if [[ -n "$previous" && -x "$previous/hysteria" ]]; then
        _hysteria_switch_current "$previous"
        _hysteria_write_unit
        systemctl restart "$HYSTERIA_SERVICE" || true
      else
        systemctl disable --now "$HYSTERIA_SERVICE" >/dev/null 2>&1 || true
      fi
      die "Hysteria2 upgrade rolled back. Inspect: journalctl -u $HYSTERIA_SERVICE -n 100"
    fi
  fi

  registry_service_set hysteria2 hysteria "$HYSTERIA_SERVICE" installed
  ok "Hysteria2 runtime ready: $(_hysteria_version_text)"
  [[ -s "$HYSTERIA_CONFIG" ]] || info "Next: sudo 986 hysteria bootstrap --domain vpn.example.com --cert /path/fullchain.pem --key /path/privkey.pem"
}

_hysteria_validate_domain() {
  local domain="$1"
  [[ "$domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$ ]] || die "Invalid Hysteria2 domain: $domain"
}

_hysteria_copy_tls_material() {
  local cert="$1" key="$2" cert_dest="$HYSTERIA_CONFIG_DIR/server.crt" key_dest="$HYSTERIA_CONFIG_DIR/server.key"
  [[ -r "$cert" ]] || die "TLS certificate is not readable: $cert"
  [[ -r "$key" ]] || die "TLS private key is not readable: $key"
  openssl x509 -in "$cert" -noout >/dev/null 2>&1 || die "TLS certificate is not a valid X.509 certificate."
  openssl pkey -in "$key" -noout >/dev/null 2>&1 || die "TLS private key is not valid/readable by OpenSSL."

  local cert_pub key_pub
  cert_pub="$(openssl x509 -in "$cert" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
  key_pub="$(openssl pkey -in "$key" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
  [[ -n "$cert_pub" && "$cert_pub" == "$key_pub" ]] || die "TLS certificate and private key do not match."

  install -m 0640 -o root -g "$HYSTERIA_USER" "$cert" "$cert_dest"
  install -m 0640 -o root -g "$HYSTERIA_USER" "$key" "$key_dest"
}

_hysteria_write_bootstrap_config() {
  local staged="$1" port="$2" bootstrap_name="$3" bootstrap_password="$4"
  cat > "$staged" <<EOF_CONFIG
listen: :$port

tls:
  cert: $HYSTERIA_CONFIG_DIR/server.crt
  key: $HYSTERIA_CONFIG_DIR/server.key
  sniGuard: strict

auth:
  type: userpass
  userpass:
    $bootstrap_name: $bootstrap_password

quic:
  maxIdleTimeout: 30s

udpIdleTimeout: 60s

masquerade:
  type: string
  string:
    content: "Not Found"
    headers:
      content-type: text/plain
    statusCode: 404
EOF_CONFIG
  chmod 0600 "$staged"
}

_hysteria_apply_config_transaction() {
  local staged="$1" port="$2" rollback="" had_old=false
  _hysteria_check_config_shape "$staged" || die "Generated Hysteria2 configuration failed structural validation."
  registry_assert_port_available udp "$port" hysteria2

  if [[ -f "$HYSTERIA_CONFIG" ]]; then
    had_old=true
    rollback="$(mktemp "$HYSTERIA_CONFIG_DIR/.config.rollback.XXXXXX")"
    cp -a "$HYSTERIA_CONFIG" "$rollback"
    backup_file "$HYSTERIA_CONFIG" hysteria-config
  fi

  install -m 0640 -o root -g "$HYSTERIA_USER" "$staged" "$HYSTERIA_CONFIG"
  systemctl enable "$HYSTERIA_SERVICE" >/dev/null
  if ! systemctl restart "$HYSTERIA_SERVICE" || ! _hysteria_health_check 5; then
    warn "New Hysteria2 configuration failed runtime health verification. Rolling back."
    if [[ "$had_old" == true ]]; then
      install -m 0640 -o root -g "$HYSTERIA_USER" "$rollback" "$HYSTERIA_CONFIG"
      systemctl restart "$HYSTERIA_SERVICE" || true
    else
      rm -f "$HYSTERIA_CONFIG"
      systemctl disable --now "$HYSTERIA_SERVICE" >/dev/null 2>&1 || true
    fi
    [[ -n "$rollback" ]] && rm -f "$rollback"
    die "Hysteria2 config rolled back. Inspect: journalctl -u $HYSTERIA_SERVICE -n 100"
  fi

  [[ -n "$rollback" ]] && rm -f "$rollback"
  registry_port_remove_owner hysteria2
  registry_port_set udp "$port" hysteria2
  registry_service_set hysteria2 hysteria "$HYSTERIA_SERVICE" active
}

hysteria_bootstrap() {
  require_root
  _hysteria_require_dependencies
  _hysteria_prepare_dirs
  [[ -x "$HYSTERIA_BIN" ]] || die "Hysteria2 is not installed. Run: sudo 986 hysteria install"

  local domain="" cert="" key="" port="8443" name="bootstrap-hy2" password staged
  while (($#)); do
    case "$1" in
      --domain) [[ $# -ge 2 ]] || die "--domain requires a value"; domain="$2"; shift 2 ;;
      --cert) [[ $# -ge 2 ]] || die "--cert requires a value"; cert="$2"; shift 2 ;;
      --key) [[ $# -ge 2 ]] || die "--key requires a value"; key="$2"; shift 2 ;;
      --port) [[ $# -ge 2 ]] || die "--port requires a value"; port="$2"; shift 2 ;;
      --name) [[ $# -ge 2 ]] || die "--name requires a value"; name="$2"; shift 2 ;;
      *) die "Unknown Hysteria2 bootstrap option: $1" ;;
    esac
  done

  [[ -n "$domain" ]] || die "Missing --domain. Use a DNS name covered by the supplied TLS certificate."
  [[ -n "$cert" ]] || die "Missing --cert. 986 does not create insecure TLS by default."
  [[ -n "$key" ]] || die "Missing --key. 986 does not create insecure TLS by default."
  _hysteria_validate_domain "$domain"
  registry_validate_port "$port"
  validate_username "$name"
  registry_assert_port_available udp "$port" hysteria2

  _hysteria_copy_tls_material "$cert" "$key"
  password="$(openssl rand -base64 24 | tr -d '\n=/+' | cut -c1-28)"
  [[ ${#password} -ge 20 ]] || die "Failed to generate Hysteria2 bootstrap password."

  staged="$(mktemp "$HYSTERIA_CONFIG_DIR/.config.XXXXXX.yaml")"
  _hysteria_write_bootstrap_config "$staged" "$port" "$name" "$password"
  _hysteria_apply_config_transaction "$staged" "$port"
  rm -f "$staged"

  umask 077
  cat > "$HYSTERIA_PROFILE_FILE" <<EOF_PROFILE
HYSTERIA_DOMAIN='$domain'
HYSTERIA_PORT='$port'
HYSTERIA_BOOTSTRAP_NAME='$name'
HYSTERIA_BOOTSTRAP_PASSWORD='$password'
EOF_PROFILE
  chmod 0600 "$HYSTERIA_PROFILE_FILE"

  ok "Hysteria2 bootstrap active on UDP $port"
  printf 'Domain    : %s\n' "$domain"
  printf 'User      : %s\n' "$name"
  printf 'Password  : %s\n' "$password"
  printf '\nNext: sudo 986 hysteria client\n'
}

hysteria_client_uri_value() {
  [[ -r "$HYSTERIA_PROFILE_FILE" ]] || die "Hysteria2 profile metadata not found."
  # shellcheck disable=SC1090
  source "$HYSTERIA_PROFILE_FILE"
  local auth name
  auth="$(printf '%s:%s' "$HYSTERIA_BOOTSTRAP_NAME" "$HYSTERIA_BOOTSTRAP_PASSWORD" | jq -sRr @uri)"
  name="$(printf '%s' "986-$HYSTERIA_BOOTSTRAP_NAME" | jq -sRr @uri)"
  printf 'hysteria2://%s@%s:%s/?sni=%s#%s\n' "$auth" "$HYSTERIA_DOMAIN" "$HYSTERIA_PORT" "$HYSTERIA_DOMAIN" "$name"
}

hysteria_show_client() {
  require_root
  hysteria_client_uri_value
}

hysteria_status() {
  local version='not installed' state='not installed' port='-'
  [[ -x "$HYSTERIA_BIN" ]] && version="$(_hysteria_version_text)"
  if [[ -r "$HYSTERIA_PROFILE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$HYSTERIA_PROFILE_FILE"
    port="${HYSTERIA_PORT:-?}/udp"
  fi
  if systemctl is-active --quiet "$HYSTERIA_SERVICE" 2>/dev/null; then
    state='active'
  elif [[ -s "$HYSTERIA_CONFIG" ]]; then
    state='configured / inactive'
  fi
  printf 'Hysteria2 version : %s\n' "$version"
  printf 'Service           : %s\n' "$state"
  printf 'Listen            : %s\n' "$port"
  printf 'Config            : %s\n' "$HYSTERIA_CONFIG"
}

hysteria_doctor() {
  local failures=0
  printf '986 Hysteria2 diagnostics\n\n'
  if [[ -x "$HYSTERIA_BIN" ]]; then ok "$(_hysteria_version_text)"; else fail 'Hysteria2 binary missing'; ((failures+=1)); fi
  if [[ -s "$HYSTERIA_CONFIG" ]] && _hysteria_check_config_shape "$HYSTERIA_CONFIG"; then ok 'Config structure present'; else fail 'Hysteria2 config missing/invalid'; ((failures+=1)); fi
  if systemctl is-active --quiet "$HYSTERIA_SERVICE" 2>/dev/null; then ok "$HYSTERIA_SERVICE active"; else fail "$HYSTERIA_SERVICE inactive"; ((failures+=1)); fi
  if [[ -r "$HYSTERIA_CONFIG_DIR/server.crt" ]]; then
    if openssl x509 -checkend 604800 -noout -in "$HYSTERIA_CONFIG_DIR/server.crt" >/dev/null 2>&1; then ok 'TLS certificate valid for more than 7 days'; else fail 'TLS certificate expires within 7 days or is invalid'; ((failures+=1)); fi
  else
    fail 'Managed TLS certificate missing'; ((failures+=1))
  fi
  printf '\nResult: %d failure(s)\n' "$failures"
  (( failures == 0 ))
}

hysteria_restart() {
  require_root
  [[ -s "$HYSTERIA_CONFIG" ]] || die "Hysteria2 is not configured."
  systemctl restart "$HYSTERIA_SERVICE"
  _hysteria_health_check 5 || die "Hysteria2 failed to return active after restart."
  ok 'Hysteria2 restarted'
}
