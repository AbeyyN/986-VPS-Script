#!/usr/bin/env bash

system_summary() {
  local os_name kernel arch cpu ram disk uptime_h default_if public_ip
  os_name="$(awk -F= '$1=="PRETTY_NAME" {gsub(/^"|"$/, "", $2); print $2; exit}' /etc/os-release 2>/dev/null)"
  [[ -n "$os_name" ]] || os_name='Unknown Linux'
  kernel="$(uname -r)"
  arch="$(uname -m)"
  cpu="$(nproc 2>/dev/null || printf '?')"
  ram="$(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
  disk="$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
  uptime_h="$(uptime -p 2>/dev/null || true)"
  default_if="$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')"
  public_ip="$(curl -4 -fsS --max-time 4 https://api.ipify.org 2>/dev/null || printf 'unavailable')"

  printf '%-18s %s\n' 'Installation:' "$(installation_id)"
  printf '%-18s %s\n' 'Version:' "$PRODUCT_VERSION"
  printf '%-18s %s\n' 'OS:' "$os_name"
  printf '%-18s %s\n' 'Kernel:' "$kernel"
  printf '%-18s %s\n' 'Architecture:' "$arch"
  printf '%-18s %s\n' 'CPU threads:' "$cpu"
  printf '%-18s %s\n' 'Memory:' "$ram"
  printf '%-18s %s\n' 'Root disk:' "$disk"
  printf '%-18s %s\n' 'Uptime:' "$uptime_h"
  printf '%-18s %s\n' 'Default iface:' "${default_if:-unavailable}"
  printf '%-18s %s\n' 'Public IPv4:' "$public_ip"
}

doctor() {
  local failures=0 warnings=0
  printf '%s diagnostics\n\n' "$PRODUCT_NAME"

  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then ok 'Running with root privileges'; else warn 'Not running as root'; ((warnings+=1)); fi

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
      debian)
        if (( ${VERSION_ID%%.*} >= 13 )); then ok "Supported OS: ${PRETTY_NAME:-Debian}"; else fail "Unsupported Debian version: ${VERSION_ID:-unknown}"; ((failures+=1)); fi
        ;;
      ubuntu)
        if (( ${VERSION_ID%%.*} >= 26 )); then ok "Supported OS: ${PRETTY_NAME:-Ubuntu}"; else fail "Unsupported Ubuntu version: ${VERSION_ID:-unknown}"; ((failures+=1)); fi
        ;;
      *) warn "Unvalidated OS: ${PRETTY_NAME:-unknown}"; ((warnings+=1)) ;;
    esac
  else
    fail '/etc/os-release is unavailable'; ((failures+=1))
  fi

  for cmd in curl ip awk sed grep openssl systemctl; do
    if command -v "$cmd" >/dev/null 2>&1; then
      ok "Dependency available: $cmd"
    else
      fail "Missing dependency: $cmd"
      ((failures+=1))
    fi
  done

  if sysctl -n net.ipv4.ip_forward 2>/dev/null | grep -qx '1'; then
    ok 'IPv4 forwarding enabled'
  else
    warn 'IPv4 forwarding is disabled (WireGuard installer will enable it)'
    ((warnings+=1))
  fi

  if [[ -f "$WG_CONF" ]]; then
    if command -v wg >/dev/null 2>&1; then ok 'WireGuard configuration detected'; else fail 'WireGuard config exists but wg command is missing'; ((failures+=1)); fi
    if systemctl is-active --quiet wg-quick@wg0 2>/dev/null; then ok 'wg0 service active'; else warn 'wg0 configuration exists but service is not active'; ((warnings+=1)); fi
  else
    warn 'WireGuard is not configured yet'; ((warnings+=1))
  fi

  printf '\nResult: %d failure(s), %d warning(s)\n' "$failures" "$warnings"
  (( failures == 0 ))
}

status_summary() {
  load_config
  printf '%s %s\n' "$PRODUCT_NAME" "$PRODUCT_VERSION"
  printf 'Installation ID : %s\n' "$(installation_id)"
  printf 'License mode    : %s\n' "${LICENSE_MODE:-early_access}"
  printf 'Telemetry       : %s\n' "${TELEMETRY_ENABLED:-false}"
  printf 'Control plane   : %s\n' "${CONTROL_PLANE_URL:-not configured}"
  if systemctl is-active --quiet wg-quick@wg0 2>/dev/null; then
    printf 'WireGuard       : active\n'
  elif [[ -f "$WG_CONF" ]]; then
    printf 'WireGuard       : configured / inactive\n'
  else
    printf 'WireGuard       : not installed\n'
  fi
  if [[ -f "$USERS_DB" ]]; then
    printf 'Local users     : %s\n' "$(awk 'NR>1 {n++} END {print n+0}' "$USERS_DB")"
  fi
}
