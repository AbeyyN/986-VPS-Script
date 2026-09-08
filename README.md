# 986 VPS Engine

A stability-first, Xray-first VPS management platform for VPN/proxy sellers and server operators.

> **Current milestone: `0.3.0-alpha.1` / Early Access.** The current code includes a verified Xray runtime, VLESS REALITY + XTLS Vision, multiple managed seller users, expiry/suspend/resume/renew lifecycle, per-user Mihomo/OpenClash export, rollback safeguards and automatic expiry enforcement. Real-VPS integration testing is still required before any production-ready claim.

## Principles

1. Stability
2. Security
3. Performance
4. Maintainability
5. Features
6. Newest-version adoption only when it is production-safe

986 is intentionally modular. A failure in one optional protocol module must not corrupt or stop unrelated services.

## What works in `0.3.0-alpha.1`

### Xray primary engine

- official `XTLS/Xray-core` download path;
- 986 stable channel pinned to Xray `v26.3.27` for this milestone;
- pinned SHA-256 verification of the official Linux amd64 archive;
- versioned runtime under `/opt/986-vps/xray`;
- dedicated `986-xray` service account;
- hardened systemd service;
- service and port registry/conflict detection;
- staged `xray run -test` config validation;
- transactional config apply + rollback;
- previous Xray binary rollback path after failed upgrade health checks;
- VLESS REALITY + `xtls-rprx-vision` bootstrap;
- Xray status and diagnostics.

### Unified seller users

Seller users now have one persistent identity with:

- username;
- status (`active`, `suspended`, `expired`);
- expiry date;
- assigned protocol list;
- persistent Xray UUID;
- per-user VLESS URI;
- per-user Mihomo/OpenClash YAML.

Create a customer:

```bash
sudo 986 user add alice --days 30 --protocol vless-reality
```

Lifecycle:

```bash
sudo 986 user list
sudo 986 user show alice
sudo 986 user suspend alice
sudo 986 user resume alice
sudo 986 user renew alice 30
sudo 986 user delete alice
```

Suspend/expire removes only that customer's managed Xray identity. Resume restores the same UUID so the client credential remains stable.

### Automatic expiry

The installer enables:

```text
986-user-expiry.timer
```

The timer checks periodically and only changes Xray when active accounts have actually expired.

Manual enforcement:

```bash
sudo 986 user expire
```

Expiry is batch-applied in one Xray configuration transaction, so several expiring customers do not cause repeated sequential restarts.

### Mihomo / OpenClash compatibility

Generate a customer-specific config:

```bash
sudo 986 subscription mihomo alice
```

Other exports:

```bash
sudo 986 subscription uri alice
sudo 986 subscription status alice
```

Files are stored root-only under:

```text
/etc/986-vps/clients/
```

A hosted subscription URL is **not yet enabled** because the future 986 control plane/domain remains a later milestone.

### Optional conventional VPN

WireGuard remains available as an optional module. Its older local user lifecycle is preserved under:

```bash
sudo 986 wireguard user add legacy-wg --days 30
sudo 986 wireguard user list
```

`986 user ...` is now reserved for the unified seller identity model.

## Planned protocol stack

### P0 / primary

- Xray-core;
- VLESS REALITY;
- XTLS Vision/current supported Xray transports;
- Trojan;
- VMess compatibility;
- Shadowsocks compatibility.

### P1 / secondary

- Hysteria2;
- TUIC;
- selected stable sing-box capabilities.

### Optional / compatibility

- WireGuard;
- OpenVPN;
- SSH/SSL compatibility;
- Transport Relay;
- SlowDNS/DNS Tunnel;
- maintained UDP gateway capability.

OpenClash is treated as a **client/subscription target**, not a server-side protocol.

## Platform target

- Debian 13 amd64;
- Ubuntu Server 26.04 LTS amd64;
- systemd-based VPS environments.

ARM64 and additional distributions follow only after the amd64 baseline passes real integration tests.

## Install / upgrade

Review the installer first:

```bash
curl -fsSL https://raw.githubusercontent.com/AbeyyN/986-VPS-Script/main/install.sh -o install-986.sh
less install-986.sh
sudo bash install-986.sh
```

Existing `/etc/986-vps/986.conf` and local state are preserved on reinstall/upgrade.

Launch:

```bash
sudo 986
```

## Xray + seller quick start

Install the 986-tested stable runtime:

```bash
sudo 986 xray install
```

Bootstrap VLESS REALITY + XTLS Vision:

```bash
sudo 986 xray bootstrap reality \
  --server-name HOSTNAME \
  --target HOSTNAME:443 \
  --port 443 \
  --name bootstrap
```

`--server-name` and `--target` are deliberately required. 986 does not silently choose a third-party REALITY target for the operator.

Create seller users:

```bash
sudo 986 user add alice --days 30 --protocol vless-reality
sudo 986 user add bob --days 7 --protocol vless-reality
sudo 986 user list
```

Generate client exports:

```bash
sudo 986 subscription uri alice
sudo 986 subscription mihomo alice
```

Inspect platform state:

```bash
sudo 986 status
sudo 986 doctor
sudo 986 xray doctor
sudo 986 user timer status
sudo 986 registry
```

## CLI overview

```text
986
986 status
986 doctor
986 system
986 registry
986 license

986 xray install [stable]
986 xray bootstrap reality --server-name HOST --target HOST:443 [--port N] [--name NAME]
986 xray status
986 xray doctor
986 xray restart
986 xray client [NAME]

986 user add NAME [--days N] [--protocol vless-reality]
986 user list
986 user show NAME
986 user suspend NAME
986 user resume NAME
986 user renew NAME [DAYS]
986 user delete NAME
986 user expire
986 user timer install
986 user timer status

986 subscription uri [NAME]
986 subscription mihomo [NAME]
986 subscription openclash [NAME]
986 subscription status [NAME]

986 wireguard install
986 wireguard status
986 wireguard restart
986 wireguard user ...
```

## Future protocol templates

The repository includes design templates for work that is **not yet exposed as active seller lifecycle commands**:

```text
templates/xray/trojan-tls.json.example
templates/xray/vmess-ws-tls.json.example
```

A template is not marked complete until installation, validation, health, rollback and real-VPS testing exist around it.

## Runtime separation / safe uninstall

```text
/usr/local/lib/986-vps/      removable CLI/orchestration modules
/opt/986-vps/xray/           live versioned Xray runtime/assets
/etc/986-vps/xray/           live Xray configuration
/var/lib/986-vps/            local state/registries
/var/backups/986-vps/        backups
```

A normal 986 uninstall does not stop/delete existing protocol services. `--purge` also preserves the live Xray configuration and `/etc/wireguard`; management cleanup must not become a surprise customer outage.

The seller expiry timer is removed with the management CLI because it depends on `/usr/local/bin/986`.

## Engineering standard

High-risk operations should follow this sequence:

```text
validate environment
        |
verify upstream provenance + digest
        |
check service/port conflict
        |
acquire lock
        |
backup known-good state
        |
stage new runtime/config
        |
validate syntax
        |
apply
        |
health check
        |
PASS -> keep
FAIL -> rollback
```

Third-party networking components must come from official upstream sources. Opaque executables/archives copied from unrelated script repositories are prohibited by project policy and CI.

## Current limits

`0.3.0-alpha.1` does **not** yet claim:

- quota/bandwidth accounting;
- device/concurrency limits;
- multiple simultaneous protocols on one seller identity;
- bulk reseller operations;
- Trojan/VMess/Shadowsocks seller lifecycle;
- Hysteria2/TUIC engine integration;
- hosted/tokenized subscriptions;
- remote seller dashboard/control-plane synchronization;
- production readiness.

## Privacy and future control plane

Telemetry remains disabled. PostgreSQL/Supabase will never be exposed directly to managed seller VPS nodes.

Future architecture:

```text
Seller VPS
   |
   | HTTPS + signed node identity
   v
Cloudflare edge / tunnel
   |
   v
986 control plane
   |
   +-- API
   +-- licensing
   +-- owner fleet dashboard
   +-- seller dashboard
   +-- self-hosted Supabase/PostgreSQL on 986-server
```

Future telemetry will be explicit and must not collect VPN traffic contents, browsing history, customer passwords, VPN private keys, SSH private keys or `/etc/shadow`.

## Licensing

The repository uses the **986 VPS Engine Early Access License**. It is source-available, not an OSI-approved open-source license.

Early Access is currently free. Future commercial licensing is planned around signed leases and grace periods; temporary control-plane failure must not immediately terminate existing customer tunnels.

## Documentation

- [Seller engine](docs/SELLER-ENGINE.md)
- [Xray engine](docs/XRAY.md)
- [Mihomo / OpenClash compatibility](docs/OPENCLASH.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Privacy](docs/PRIVACY.md)
- [Security](SECURITY.md)
- [Roadmap](ROADMAP.md)
- [Clean-room LACASITA reference audit](docs/REFERENCE-AUDIT-LACASITA.md)

## Repository policy

Do not trade server availability for feature count. "Latest" is accepted only after compatibility, health behavior and rollback are understood.

Use only on systems and networks you own or are authorized to administer. VPN/proxy operation, resale, logging, privacy and lawful-use requirements vary by jurisdiction and provider.

Copyright (c) 2026 AbeyyN / 986 VPS Engine.
