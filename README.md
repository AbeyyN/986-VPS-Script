# 986 VPS Engine

A stability-first, Xray-first VPS management platform for VPN/proxy sellers and server operators.

> **Current milestone: `0.2.0-alpha.1` / Early Access.** The current code has a verified Xray runtime path, VLESS REALITY + XTLS Vision bootstrap, rollback safeguards and an initial local Mihomo/OpenClash export. Real-VPS integration testing is still required before any production-ready claim.

## Principles

1. Stability
2. Security
3. Performance
4. Maintainability
5. Features
6. Newest-version adoption only when it is production-safe

986 is intentionally modular. A failure in one optional protocol module must not corrupt or stop unrelated services.

## What works in `0.2.0-alpha.1`

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
- generated root-only VLESS client URI;
- Xray status and diagnostics.

### Initial OpenClash / Mihomo compatibility

After bootstrapping REALITY, 986 can generate a local Mihomo/OpenClash YAML:

```bash
sudo 986 subscription mihomo
```

The file is stored under `/etc/986-vps/clients/` with root-only permissions.

A hosted subscription URL is **not yet enabled** because the future 986 control plane/domain is intentionally a later milestone.

### Optional conventional VPN

WireGuard remains available as an optional module, including its original local Early Access user lifecycle. It is no longer the product's primary direction.

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

## Target seller model

The destination architecture is **one customer identity, multiple assigned protocols** with one expiry/quota/suspend policy and protocol-specific credentials.

That unified seller lifecycle is not yet complete in this alpha; the current Xray bootstrap client remains an initial standalone profile.

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

## Xray quick start

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

Inspect/export:

```bash
sudo 986 xray status
sudo 986 xray doctor
sudo 986 xray client bootstrap
sudo 986 subscription uri bootstrap
sudo 986 subscription mihomo bootstrap
sudo 986 subscription status
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

986 subscription uri [NAME]
986 subscription mihomo [NAME]
986 subscription openclash [NAME]
986 subscription status

986 wireguard install
986 wireguard status
986 wireguard restart
```

## Future protocol templates

The repository includes design templates for work that is **not yet exposed as active seller lifecycle commands**:

```text
templates/xray/trojan-tls.json.example
templates/xray/vmess-ws-tls.json.example
```

This distinction is intentional: a template is not marked complete until installation, validation, health, rollback and real-VPS testing exist around it.

## Runtime separation / safe uninstall

```text
/usr/local/lib/986-vps/      removable CLI/orchestration modules
/opt/986-vps/xray/           live versioned Xray runtime/assets
/etc/986-vps/xray/           live Xray configuration
/var/lib/986-vps/            local state/registries
/var/backups/986-vps/        backups
```

A normal 986 uninstall does not stop/delete existing protocol services. `--purge` also preserves the live Xray configuration and `/etc/wireguard`; management cleanup must not become a surprise customer outage.

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

## CI gates

GitHub Actions currently checks:

- Bash syntax;
- ShellCheck;
- Xray JSON example validity;
- pinned Xray version/digest presence;
- required security/privacy docs;
- obvious private-key/password leakage patterns;
- accidental checked-in ELF binaries;
- accidental checked-in ZIP/tar binary payloads.

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

The planned authoritative data store remains self-hosted. A dedicated public IP is not required when an outbound tunnel is used.

Future telemetry will be explicit and must not collect VPN traffic contents, browsing history, customer passwords, VPN private keys, SSH private keys or `/etc/shadow`.

## Licensing

The repository uses the **986 VPS Engine Early Access License**. It is source-available, not an OSI-approved open-source license.

Early Access is currently free. Future commercial licensing is planned around signed leases and grace periods; temporary control-plane failure must not immediately terminate existing customer tunnels.

## Documentation

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
