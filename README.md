# 986 VPS Engine

A stability-first, Xray-first VPS management platform for VPN/proxy sellers and server operators.

> Status: **Early Access / active development**. The current working alpha contains the initial CLI, diagnostics and WireGuard module. Xray, subscriptions, the control plane, telemetry and commercial licensing are being built in staged milestones and are **not yet claimed production-ready**.

## Product direction

986 VPS Engine is not intended to become another giant monolithic VPN shell script. It is being built as a modular seller platform where each network engine can be installed, validated, diagnosed, repaired, upgraded, rolled back and removed independently.

Priority order:

1. Stability
2. Security
3. Performance
4. Maintainability
5. Features
6. Newest-version adoption only when it is production-safe

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
- stable sing-box features where they reduce duplication or improve compatibility

### Client/subscription targets

The planned 986 Subscription Engine will generate client-ready formats for:

- Mihomo / OpenClash
- sing-box clients
- v2rayNG-class clients
- generic VLESS / VMess / Trojan / Shadowsocks URI imports
- QR output where applicable

**OpenClash is treated as a client/subscription target, not as a VPS server protocol.**

### Optional compatibility modules

- WireGuard
- OpenVPN
- SSH/SSL compatibility
- Transport Relay for HTTP-custom/SSH-style usage
- SlowDNS/DNS Tunnel fallback
- UDP gateway compatibility

Legacy/fallback modules must remain isolated from the Xray seller core so that a failure in one module cannot break unrelated services.

## Unified seller account model

The product direction is **one customer identity, multiple assigned protocols**.

A customer record will ultimately control:

- expiry;
- suspend/resume state;
- quota policy;
- device/concurrency policy where technically reliable;
- protocol-specific credentials;
- subscription output;
- reseller ownership.

Example future flow:

```bash
sudo 986 user add alice --days 30 --protocol vless-reality
sudo 986 user renew alice 30
sudo 986 user suspend alice
sudo 986 user subscription alice --format mihomo
```

## Current Early Access implementation

The current alpha includes:

- `986` management CLI;
- safe installer and conservative uninstaller;
- Debian/Ubuntu environment validation;
- system diagnostics / doctor command;
- persistent installation ID;
- local state and backup directories;
- WireGuard server bootstrap as the first working protocol module;
- WireGuard customer add/list/suspend/resume/renew/delete workflow;
- persistent local customer registry;
- configuration backup before destructive edits;
- future telemetry configuration disabled by default;
- future control-plane configuration placeholders;
- CI Bash syntax, ShellCheck and repository safety checks.

WireGuard is **not** the final product focus. It is retained as an optional conventional VPN module while the Xray-first seller core is developed.

## Initial platform support

Validated target baseline:

- Debian 13 amd64
- Ubuntu Server 26.04 LTS amd64
- systemd-based VPS environments

ARM64 and additional distributions are planned after the amd64 production test matrix is stable.

## Install the current alpha

Review the installer before running it:

```bash
curl -fsSL https://raw.githubusercontent.com/AbeyyN/986-VPS-Script/main/install.sh -o install-986.sh
less install-986.sh
sudo bash install-986.sh
```

Launch the management CLI:

```bash
sudo 986
```

Current direct commands include:

```bash
sudo 986 status
sudo 986 doctor
sudo 986 system
sudo 986 license

sudo 986 wireguard install
sudo 986 wireguard status
sudo 986 wireguard restart

sudo 986 user add alice --days 30
sudo 986 user list
sudo 986 user suspend alice
sudo 986 user resume alice
sudo 986 user renew alice 30
sudo 986 user config alice
sudo 986 user delete alice
```

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

High-risk operations should follow a transaction-like process:

1. validate environment and dependencies;
2. acquire an installation/configuration lock;
3. snapshot the affected known-good state;
4. stage the new configuration;
5. validate syntax and ownership/permissions;
6. apply atomically;
7. verify service health;
8. automatically restore the previous known-good state when validation or startup fails.

## Supply-chain policy

Third-party networking components must come from official upstream sources.

986 should not ingest random binaries or archives copied from other VPN-script repositories. Components are expected to be:

- version pinned;
- architecture matched;
- checksum/signature verified when upstream provides verification material;
- recorded in a local component inventory;
- rollback capable.

See [docs/REFERENCE-AUDIT-LACASITA.md](docs/REFERENCE-AUDIT-LACASITA.md) for an example clean-room reference audit.

## Safety and privacy model

986 VPS Engine does **not** expose PostgreSQL/Supabase directly to managed VPS nodes. Future cloud integration will use a dedicated HTTPS API and per-installation cryptographic identity.

When telemetry is introduced it will be explicit and documented. The project will not collect VPN traffic contents, browsing history, customer passwords, VPN private keys, SSH private keys, or `/etc/shadow`.

See [docs/PRIVACY.md](docs/PRIVACY.md) and [SECURITY.md](SECURITY.md).

## Future control plane

The planned production architecture is:

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

This repository is currently published under the **986 VPS Engine Early Access License**. It is source-available, not an OSI-approved open-source license.

Early Access is currently free. Commercial licensing may be introduced later. Future licensing is planned around signed leases and grace periods; temporary loss of the 986 control plane must not immediately terminate existing customer tunnels.

See [LICENSE](LICENSE).

## Repository layout

```text
.
|-- bin/986                 Main CLI
|-- lib/986/                Runtime modules
|-- config/986.conf.example Configuration template
|-- docs/                   Architecture, privacy and reference audits
|-- .github/workflows/      CI checks
|-- install.sh              Installer
|-- uninstall.sh            Conservative uninstaller
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
