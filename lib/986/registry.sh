#!/usr/bin/env bash

SERVICE_REGISTRY="$STATE_DIR/services.tsv"
PORT_REGISTRY="$STATE_DIR/ports.tsv"
export SERVICE_REGISTRY PORT_REGISTRY

registry_ensure_state() {
  install -d -m 0755 "$STATE_DIR"

  if [[ ! -f "$SERVICE_REGISTRY" ]]; then
    printf 'name\tengine\tunit\tstatus\tupdated_at\n' > "$SERVICE_REGISTRY"
    chmod 0600 "$SERVICE_REGISTRY"
  fi

  if [[ ! -f "$PORT_REGISTRY" ]]; then
    printf 'protocol\tport\towner\tupdated_at\n' > "$PORT_REGISTRY"
    chmod 0600 "$PORT_REGISTRY"
  fi
}

registry_validate_protocol() {
  case "$1" in
    tcp|udp) ;;
    *) die "Unsupported port protocol: $1" ;;
  esac
}

registry_validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || die "Invalid port: $port"
  (( port >= 1 && port <= 65535 )) || die "Port must be between 1 and 65535: $port"
}

registry_service_set() {
  local name="$1" engine="$2" unit="$3" status="$4"
  local tmp now
  registry_ensure_state
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$(mktemp "$STATE_DIR/.services.XXXXXX")"

  awk -F '\t' -v OFS='\t' -v name="$name" 'NR == 1 || $1 != name' "$SERVICE_REGISTRY" > "$tmp"
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$engine" "$unit" "$status" "$now" >> "$tmp"
  chmod 0600 "$tmp"
  mv -f "$tmp" "$SERVICE_REGISTRY"
}

registry_service_remove() {
  local name="$1" tmp
  registry_ensure_state
  tmp="$(mktemp "$STATE_DIR/.services.XXXXXX")"
  awk -F '\t' -v OFS='\t' -v name="$name" 'NR == 1 || $1 != name' "$SERVICE_REGISTRY" > "$tmp"
  chmod 0600 "$tmp"
  mv -f "$tmp" "$SERVICE_REGISTRY"
}

registry_port_owner() {
  local protocol="$1" port="$2"
  registry_ensure_state
  registry_validate_protocol "$protocol"
  registry_validate_port "$port"
  awk -F '\t' -v proto="$protocol" -v port="$port" 'NR > 1 && $1 == proto && $2 == port {print $3; exit}' "$PORT_REGISTRY"
}

registry_port_bound() {
  local protocol="$1" port="$2"
  registry_validate_protocol "$protocol"
  registry_validate_port "$port"

  if [[ "$protocol" == 'tcp' ]]; then
    ss -H -ltn 2>/dev/null | awk -v p=":$port" '$4 ~ p "$" {found=1} END {exit !found}'
  else
    ss -H -lun 2>/dev/null | awk -v p=":$port" '$5 ~ p "$" || $4 ~ p "$" {found=1} END {exit !found}'
  fi
}

registry_assert_port_available() {
  local protocol="$1" port="$2" allowed_owner="${3:-}"
  local owner
  registry_validate_protocol "$protocol"
  registry_validate_port "$port"
  owner="$(registry_port_owner "$protocol" "$port")"

  if [[ -n "$owner" && "$owner" != "$allowed_owner" ]]; then
    die "$protocol/$port is reserved by 986 module: $owner"
  fi

  if registry_port_bound "$protocol" "$port"; then
    if [[ -z "$owner" || "$owner" != "$allowed_owner" ]]; then
      die "$protocol/$port is already bound by another process. Run: sudo ss -ltnup"
    fi
  fi
}

registry_port_set() {
  local protocol="$1" port="$2" owner="$3"
  local tmp now
  registry_ensure_state
  registry_validate_protocol "$protocol"
  registry_validate_port "$port"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$(mktemp "$STATE_DIR/.ports.XXXXXX")"

  awk -F '\t' -v OFS='\t' -v proto="$protocol" -v port="$port" 'NR == 1 || !($1 == proto && $2 == port)' "$PORT_REGISTRY" > "$tmp"
  printf '%s\t%s\t%s\t%s\n' "$protocol" "$port" "$owner" "$now" >> "$tmp"
  chmod 0600 "$tmp"
  mv -f "$tmp" "$PORT_REGISTRY"
}

registry_port_remove_owner() {
  local owner="$1" tmp
  registry_ensure_state
  tmp="$(mktemp "$STATE_DIR/.ports.XXXXXX")"
  awk -F '\t' -v OFS='\t' -v owner="$owner" 'NR == 1 || $3 != owner' "$PORT_REGISTRY" > "$tmp"
  chmod 0600 "$tmp"
  mv -f "$tmp" "$PORT_REGISTRY"
}

registry_list() {
  registry_ensure_state
  printf 'Services\n'
  column -t -s $'\t' "$SERVICE_REGISTRY" 2>/dev/null || cat "$SERVICE_REGISTRY"
  printf '\nPorts\n'
  column -t -s $'\t' "$PORT_REGISTRY" 2>/dev/null || cat "$PORT_REGISTRY"
}
