#!/usr/bin/env bash

license_status() {
  load_config
  printf 'License mode      : %s\n' "${LICENSE_MODE:-early_access}"
  printf 'Control plane    : %s\n' "${CONTROL_PLANE_URL:-not configured}"
  printf 'Telemetry        : %s\n' "${TELEMETRY_ENABLED:-false}"
  printf 'Enforcement      : disabled in %s\n' "$PRODUCT_VERSION"
  printf '\nEarly Access note:\n'
  printf '  Licensing hooks are intentionally non-enforcing until the 986 control plane is deployed.\n'
  printf '  Future releases are designed to use signed license leases with an offline grace period.\n'
  printf '  Loss of control-plane connectivity must not immediately terminate existing VPN tunnels.\n'
}
