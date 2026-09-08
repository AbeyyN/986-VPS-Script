#!/usr/bin/env bash

wireguard_install() {
  require_root
  load_config
  ensure_state

  if [[ -f "$WG_CONF" ]]; then
    warn "$WG_CONF already exists. Refusing to overwrite an existing WireGuard server."
    warn "Back up and remove it manually if you intentionally want a fresh 986-managed wg0."
    return 1
  fi

  info 'Installing WireGuard dependencies...'
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends wireguard wireguard-tools qrencode iptables

  local default_if endpoint server_private server_public
  default_if="$(ip route show default | awk 'NR==1 {print $5}')"
  [[ -n "$default_if" ]] || die 'Unable to identify the default network interface.'

  endpoint="${PUBLIC_ENDPOINT:-}"
  if [[ -z "$endpoint" ]]; then
    endpoint="$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  fi

  install -d -m 0700 "$WG_DIR" "$CONFIG_DIR/clients"
  umask 077
  server_private="$(wg genkey)"
  server_public="$(printf '%s' "$server_private" | wg pubkey)"
  printf '%s\n' "$server_public" > "$STATE_DIR/wg-server-public.key"
  chmod 0600 "$STATE_DIR/wg-server-public.key"

  cat > "$WG_CONF" <<EOF
# Managed by 986 VPS Engine
# Manual changes are allowed, but keep a backup before upgrades.
[Interface]
Address = ${WG_SERVER_ADDRESS:-10.86.0.1/24}
ListenPort = ${WG_PORT:-51820}
PrivateKey = $server_private
SaveConfig = false
PostUp = iptables -t nat -A POSTROUTING -s ${WG_SUBNET:-10.86.0.0/24} -o $default_if -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s ${WG_SUBNET:-10.86.0.0/24} -o $default_if -j MASQUERADE
EOF
  chmod 0600 "$WG_CONF"

  cat > /etc/sysctl.d/99-986-vps.conf <<'EOF'
# 986 VPS Engine networking baseline
net.ipv4.ip_forward=1
EOF
  sysctl --system >/dev/null

  systemctl enable --now wg-quick@wg0

  ok 'WireGuard server installed and wg0 is active.'
  printf 'Server public key : %s\n' "$server_public"
  printf 'UDP port          : %s\n' "${WG_PORT:-51820}"
  printf 'Public endpoint   : %s\n' "${endpoint:-not detected}"
  if [[ -z "$endpoint" ]]; then
    warn "Set PUBLIC_ENDPOINT in $CONFIG_FILE before creating client configs."
  fi
}

wireguard_status() {
  if ! command -v wg >/dev/null 2>&1; then
    printf 'WireGuard tools are not installed.\n'
    return 1
  fi
  if [[ ! -f "$WG_CONF" ]]; then
    printf 'WireGuard is not configured by 986 VPS Engine.\n'
    return 1
  fi
  systemctl --no-pager --full status wg-quick@wg0 || true
  printf '\nWireGuard runtime:\n'
  wg show wg0 || true
}

wireguard_restart() {
  require_root
  [[ -f "$WG_CONF" ]] || die 'wg0 is not configured.'
  systemctl restart wg-quick@wg0
  ok 'WireGuard restarted.'
}

sync_wireguard_runtime() {
  local stripped
  systemctl is-active --quiet wg-quick@wg0 || return 0
  stripped="$(mktemp)"
  wg-quick strip wg0 > "$stripped"
  wg syncconf wg0 "$stripped"
  rm -f "$stripped"
}
