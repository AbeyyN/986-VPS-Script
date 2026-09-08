# Architecture

## Product boundary

986 VPS Engine is split conceptually into two layers:

1. **986 Core** - runs on the seller VPS and owns local VPN/service management.
2. **986 Control Plane** - future self-hosted API, licensing, dashboards, fleet registry and telemetry storage.

The core must continue serving existing VPN customers through temporary control-plane outages.

## Current Early Access architecture

```text
Seller / root operator
        |
        v
   /usr/local/bin/986
        |
        +-- common.sh
        +-- system.sh
        +-- wireguard.sh
        +-- users.sh
        `-- licensing.sh (non-enforcing placeholder)
        |
        +-- /etc/986-vps
        +-- /var/lib/986-vps
        +-- /var/backups/986-vps
        `-- /etc/wireguard/wg0.conf
```

## Future control-plane architecture

```text
Managed VPS nodes
      |
      | outbound HTTPS only
      v
Public API hostname
      |
      v
Cloudflare edge/tunnel
      |
      v
986-server (authoritative)
      |
      +-- API
      +-- license service
      +-- owner dashboard
      +-- seller dashboard
      `-- self-hosted Supabase/PostgreSQL
```

No dedicated public IP or inbound port-forward is required for the home-hosted control plane when an outbound tunnel is used.

## Trust model

Future node identity:

```text
first install
  -> generate installation UUID
  -> generate Ed25519 key pair
  -> private key remains on the VPS
  -> public key registered with 986 control plane
```

Requests should include a timestamp/nonce and installation signature. There must not be one master API credential copied to every VPS.

## Licensing model

Planned state model:

```text
ACTIVE -> EXPIRING -> GRACE -> MANAGEMENT_LIMITED
```

A license state transition must not intentionally delete VPN configuration, private keys or customer records.

Future signed license leases should be cached locally so a temporary API/tunnel/home-Internet outage does not immediately disrupt service.

## Telemetry model

Future telemetry should contain only operational metadata required for fleet/product health, for example:

- installation ID;
- first/last seen timestamps;
- public server IP and coarse region when required for fleet identification;
- OS, kernel and architecture;
- CPU/RAM/disk capacity and health summary;
- 986 Engine/agent version;
- enabled protocol modules;
- service health;
- aggregate local account counts;
- license/entitlement state.

It must not contain traffic contents, browsing destinations, customer passwords, customer VPN private keys, SSH private keys or `/etc/shadow`.

## Network and kernel policy

"Latest" is not automatically preferred. Supported distribution kernels/packages are the default. A newer kernel or network stack is promoted only after compatibility and regression validation.

## Module rule

A protocol module should be installable, diagnosable, restartable, upgraded and removed independently. Failure of one protocol must not corrupt unrelated protocols or the core user registry.
