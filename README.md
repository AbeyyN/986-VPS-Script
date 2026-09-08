# 986 VPS Engine

A stability-first VPS management platform for VPN sellers and server operators.

> Status: **Early Access / active development**. The control-plane, telemetry, licensing service, and paid plans are not enabled yet.

## Project goals

986 VPS Engine is being built as a modular server-management product rather than a single monolithic VPN script.

Priority order:

1. Stability
2. Security
3. Performance
4. Maintainability
5. Features
6. Newest-version adoption only when it is production-safe

## Initial platform support

- Debian 13 (amd64)
- Ubuntu Server 26.04 LTS (amd64)
- systemd-based VPS environments

ARM64 and additional distributions are planned after the amd64 baseline is proven stable.

## What the seller will be able to manage

- Server health and diagnostics
- WireGuard installation and lifecycle management
- VPN customer creation, suspension, renewal, deletion and listing
- Expiry and device/account policy foundations
- Traffic/quota foundations
- Backup and migration foundations
- Modular protocol engines
- Update channels and rollback foundations
- Future seller/reseller dashboard integration
- Future fleet telemetry and licensing integration

## Current Early Access scope

The first public baseline includes:

- `986` management CLI
- safe installer and uninstaller
- OS and dependency validation
- system diagnostics / doctor command
- WireGuard server bootstrap
- WireGuard customer add/list/suspend/renew/delete workflow
- persistent local customer registry
- configuration backup before destructive edits
- transparent future telemetry configuration (disabled by default)
- future control-plane configuration placeholders
- CI syntax and ShellCheck validation

## Install

Review the installer before running it:

```bash
curl -fsSL https://raw.githubusercontent.com/AbeyyN/986-VPS-Script/main/install.sh -o install-986.sh
less install-986.sh
sudo bash install-986.sh
```

Then launch:

```bash
sudo 986
```

Or use direct commands:

```bash
sudo 986 status
sudo 986 doctor
sudo 986 system
sudo 986 wireguard install
sudo 986 user add alice --days 30
sudo 986 user list
```

## Safety model

986 VPS Engine does **not** expose PostgreSQL/Supabase directly to managed VPS nodes. Future cloud integration will use a dedicated HTTPS API and per-installation cryptographic identity.

When telemetry is introduced it will be explicit and documented. The project will not collect VPN traffic contents, browsing history, customer passwords, VPN private keys, SSH private keys, or `/etc/shadow`.

See [docs/PRIVACY.md](docs/PRIVACY.md) and [SECURITY.md](SECURITY.md).

## Future control plane

The planned production architecture is:

```text
Seller VPS
   |
   | HTTPS
   v
Cloudflare edge / tunnel
   |
   v
986 control plane
   |
   +-- API
   +-- licensing
   +-- owner dashboard
   +-- seller dashboard
   +-- self-hosted Supabase/PostgreSQL
```

The authoritative data store is intended to remain self-hosted. A public static IP is not required when an outbound tunnel is used.

## Licensing direction

This repository is currently published under the **986 VPS Engine Early Access License**. It is source-available, not an OSI-approved open-source license.

Early Access is currently free. Commercial licensing may be introduced later. Future licensing will use signed leases and grace periods; loss of control-plane connectivity must not immediately terminate existing customer VPN tunnels.

See [LICENSE](LICENSE).

## Repository layout

```text
.
|-- bin/986                 Main CLI
|-- lib/986/                Runtime modules
|-- config/986.conf.example Configuration template
|-- docs/                   Architecture and policy docs
|-- .github/workflows/      CI checks
|-- install.sh              Installer
|-- uninstall.sh            Safe uninstaller
|-- CHANGELOG.md
|-- ROADMAP.md
|-- SECURITY.md
|-- CONTRIBUTING.md
`-- LICENSE
```

## Development rule

Do not trade server availability for feature count. Every protocol module should be independently diagnosable, restartable and removable without corrupting unrelated services.

## Disclaimer

Use only on systems and networks you own or are authorized to administer. VPN operation, resale, logging, privacy, and lawful-use requirements vary by jurisdiction and provider.

Copyright (c) 2026 AbeyyN / 986 VPS Engine.
