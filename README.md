# 986 VPS Engine

A stability-first, Xray-first VPS management platform for VPN/proxy sellers and server operators.

> **Current milestone: `0.2.0-alpha.1` / Early Access.** Xray runtime management and an initial VLESS REALITY + XTLS Vision bootstrap are now implemented, but this release is still awaiting real-VPS integration validation before any production-ready claim.

## Product direction

986 VPS Engine is being built as a modular seller platform, not a giant monolithic VPN shell script. Each network engine should be independently installable, diagnosable, upgradable and recoverable.

Priority order:

1. Stability
2. Security
3. Performance
4. Maintainability
5. Features
6. Newest-version adoption only when it is production-safe

## Current Xray milestone

`0.2.0-alpha.1` adds the first Xray-first runtime foundation:

- official `XTLS/Xray-core` acquisition;
- 986 `stable` channel pinned to Xray `v26.3.27` for this milestone;
- pinned SHA-256 verification for `Xray-linux-64.zip`;
- versioned Xray runtime under `/opt/986-vps/xray`;
- dedicated `986-xray` system account;
- hardened `986-xray.service`;
- service/port registry and conflict detection;
- staged Xray configuration validation with `xray run -test`;
- backup + transactional configuration apply;
- automatic configuration rollback when service health verification fails;
- previous-binary rollback path during Xray upgrade failure;
- VLESS + REALITY bootstrap;
- XTLS Vision flow;
- generated VLESS client URI;
- Xray-specific status and doctor commands.

The latest upstream tag is **not automatically treated as 986 stable**. Pre-release/new upstream versions must pass the project's compatibility and rollback validation before promotion.

See [docs/XRAY.md](docs/XRAY.md).

## Target protocol stack

### Primary modern stack

- **Xray-core**
- VLESS + REALITY
- VLESS + XTLS Vision / current supported Xray transports
- Trojan
- VMess compatibility
- Shadowsocks compatibility

### Modern secondary stack

- Hysteria2
- TUIC
- stable sing-box capabilities where they reduce duplication or improve compatibility

### Client/subscription targets

The planned 986 Subscription Engine will generate client-ready formats for:

- Mihomo / OpenClash;
- sing-box clients;
- v2rayNG-class clients;
- generic VLESS / VMess / Trojan / Shadowsocks URI imports;
- QR output where applicable.

**OpenClash is a client/subscription target, not a VPS server protocol.**

### Optional compatibility modules

- WireGuard;
- OpenVPN;
- SSH/SSL compatibility;
- Transport Relay for HTTP-custom/SSH-style usage;
- SlowDNS/DNS Tunnel fallback;
- UDP gateway compatibility.

Legacy/fallback modules must remain isolated from the Xray seller core so a failure in one module cannot break unrelated services.

## Unified seller account model

The target model is **one customer identity, multiple assigned protocols**.

A customer record will ultimately control:

- expiry;
- suspend/resume state;
- quota policy;
- device/concurrency policy where technically reliable;
- protocol-specific credentials;
- subscription output;
- reseller ownership.

The current Xray bootstrap still creates an initial standalone REALITY client. Migration into the unified multi-protocol seller account engine is a later milestone and is not being misrepresented as complete.

## Initial platform support

Target baseline:

- Debian 13 amd64;
- Ubuntu Server 26.04 LTS amd64;
- systemd-based VPS environments.

Static CI is active. Real-VPS integration tests on both target distributions are still required before production status.

## Install / upgrade the current alpha

Review the installer before running it:

```bash
curl -fsSL https://raw.githubusercontent.com/AbeyyN/986-VPS-Script/main/install.sh -o install-986.sh
less install-986.sh
sudo bash install-986.sh
```

Existing `/etc/986-vps/986.conf` and local state are preserved by reinstall/upgrade.

Launch:

```bash
sudo 986
```

## Xray quick start

Install the 986-tested Xray stable runtime:

```bash
sudo 986 xray install
```

Bootstrap the initial VLESS REALITY + XTLS Vision profile:

```bash
sudo 986 xray bootstrap reality \
  --server-name HOSTNAME \
  --target HOSTNAME:443 \
  --port 443 \
  --name bootstrap
```

`--server-name` and `--target` are deliberately required. 986 does not silently choose a third-party REALITY target for the operator.

Inspect the engine:

```bash
sudo 986 xray status
sudo 986 xray doctor
sudo 986 xray client bootstrap
sudo 986 registry
```

The generated VLESS URI is stored with root-only permissions under `/etc/986-vps/clients/`.

## Current CLI

```text
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

986 wireguard install
986 wireguard status
986 wireguard restart
```

WireGuard remains available as an optional conventional VPN module. Its old local user lifecycle is still present during the transition to the unified seller account model.

## Protocol templates

Repository templates exist for future protocol work:

```text
templates/xray/trojan-tls.json.example
templates/xray/vmess-ws-tls.json.example
```

They are design/test inputs only. Trojan and VMess seller lifecycle commands are **not yet enabled**.

## Module engineering standard

Every daemon/module should converge on the same lifecycle:

```text
install
validate
status
health
restart
repair
upgrade
rollback
remove
```

High-risk operations follow a transaction-like process:

1. validate environment and dependencies;
2. acquire an installation/configuration lock;
3. verify upstream provenance and integrity;
4. check managed and actual port conflicts;
5. snapshot affected known-good state;
6. stage new configuration/runtime;
7. validate syntax and permissions;
8. apply atomically;
9. verify service health;
10. restore the previous known-good state when validation/startup fails.

## Runtime safety model

Live protocol runtimes are separated from the removable 986 CLI layer:

```text
/usr/local/lib/986-vps/      CLI/orchestration modules
/opt/986-vps/xray/           versioned Xray runtime/assets
/etc/986-vps/xray/           live Xray configuration
/var/lib/986-vps/            local state/registries
/var/backups/986-vps/        backups
```

A normal 986 uninstall removes the CLI/orchestration layer without stopping or deleting existing protocol services. Even `--purge` preserves live Xray configuration and `/etc/wireguard`; it must not turn a management uninstall into an unexpected customer outage.

## Supply-chain policy

Third-party networking components must come from official upstream sources. 986 must not ingest opaque executables or archives copied from unrelated VPN-script repositories.

Components should be:

- version pinned;
- architecture matched;
- checksum/signature verified when upstream provides verification material;
- provenance recorded;
- rollback capable.

See [docs/REFERENCE-AUDIT-LACASITA.md](docs/REFERENCE-AUDIT-LACASITA.md).

## Safety and privacy model

986 VPS Engine does **not** expose PostgreSQL/Supabase directly to managed VPS nodes. Future cloud integration will use a dedicated HTTPS API and per-installation cryptographic identity.

Future telemetry will be explicit and documented. The project will not collect VPN traffic contents, browsing history, customer passwords, VPN private keys, SSH private keys, or `/etc/shadow`.

Telemetry remains disabled in this milestone.

See [docs/PRIVACY.md](docs/PRIVACY.md) and [SECURITY.md](SECURITY.md).

## Future control plane

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

The authoritative data store is intended to remain self-hosted. A dedicated public IP is not required when an outbound tunnel is used.

## Licensing direction

This repository is published under the **986 VPS Engine Early Access License**. It is source-available, not an OSI-approved open-source license.

Early Access is currently free. Commercial licensing may be introduced later. Future licensing is planned around signed leases and grace periods; temporary loss of the 986 control plane must not immediately terminate existing customer tunnels.

See [LICENSE](LICENSE).

## Repository layout

```text
.
|-- bin/986                  Main CLI
|-- lib/986/                 Runtime/orchestration modules
|-- config/986.conf.example  Configuration template
|-- templates/xray/          Future protocol profile templates
|-- docs/                    Architecture, privacy and engineering docs
|-- .github/workflows/       CI checks
|-- install.sh               Installer/upgrader
|-- uninstall.sh             Conservative uninstaller
|-- CHANGELOG.md
|-- ROADMAP.md
|-- SECURITY.md
|-- CONTRIBUTING.md
`-- LICENSE
```

## Development rule

Do not trade server availability for feature count. Every protocol module must be independently diagnosable and recoverable. "Latest" is accepted only after compatibility and rollback behavior are understood.

## Disclaimer

Use only on systems and networks you own or are authorized to administer. VPN/proxy operation, resale, logging, privacy and lawful-use requirements vary by jurisdiction and provider.

Copyright (c) 2026 AbeyyN / 986 VPS Engine.
