# Changelog

All notable changes to 986 VPS Engine will be documented here.

The project follows semantic-versioning concepts, with `alpha`, `beta` and release-candidate identifiers used before stable releases.

## [0.3.0-alpha.1] - 2026-09-08

### Added

- Unified seller account registry at `/var/lib/986-vps/sellers.tsv`.
- Persistent seller identity fields for username, lifecycle status, expiry, assigned protocols, Xray UUID and timestamps.
- Multiple managed VLESS REALITY customers on the same Xray inbound.
- Seller lifecycle commands: add, list, show, suspend, resume, renew and delete.
- Per-user VLESS REALITY URI generation.
- Per-user Mihomo/OpenClash YAML generation.
- Automatic seller expiry enforcement through `986-user-expiry.timer`.
- Batch expiry mutation so multiple due users are removed in one Xray configuration transaction.
- Seller/Xray consistency checks in `986 doctor`.
- Seller counts and expiry-timer state in `986 status`.
- Shared seller operation lock to prevent the expiry timer racing manual account changes.
- Unified seller-engine documentation.

### Changed

- `986 user ...` now represents the product-wide seller identity lifecycle.
- The previous WireGuard-only user commands remain available under `986 wireguard user ...`.
- Installer now initializes the seller registry and enables the expiry timer.
- Subscription commands can resolve an individual managed seller user instead of only the bootstrap REALITY client.
- Renewing an expired/suspended user extends validity but does not silently reactivate access; resume remains explicit.

### Safety behavior

- Suspend/expire removes only the affected `username@986.local` identity from Xray.
- Resume restores the same persistent Xray UUID instead of rotating client credentials.
- Delete removes the managed Xray identity and root-only local exports for that seller user.
- Removing the 986 management CLI disables/removes the expiry timer first while preserving live protocol services/configuration.

### Still not production-ready

- Real Debian 13 VPS seller-lifecycle integration validation.
- Real Ubuntu Server 26.04 LTS seller-lifecycle integration validation.
- Quota/bandwidth accounting.
- Device/concurrency policy.
- Multi-protocol credentials on a single seller identity.
- Bulk seller operations and reseller ownership/credits.
- Hosted/tokenized subscription endpoint.
- Hysteria2/TUIC production engine integration.
- Remote telemetry/control-plane registration/licensing enforcement.

## [0.2.0-alpha.1] - 2026-09-08

### Added

- Xray-first CLI and interactive menu direction.
- Official XTLS/Xray-core stable-channel acquisition.
- Xray `v26.3.27` pin for the initial 986 stable channel.
- SHA-256 verification for the official Linux amd64 Xray release archive.
- Versioned Xray runtime under `/opt/986-vps/xray`.
- Dedicated `986-xray` system user.
- Hardened `986-xray.service` generation and systemd validation.
- Persistent 986 service registry.
- Persistent 986 port registry with managed and actual socket conflict detection.
- Xray config staging and `xray run -test` validation.
- Transactional Xray config apply with previous-config rollback on failed health verification.
- Xray binary rollback baseline for failed upgrades.
- Initial VLESS REALITY + XTLS Vision bootstrap.
- Root-only generated VLESS REALITY client URI.
- Initial local Mihomo/OpenClash YAML export for the REALITY bootstrap client.
- Xray-specific status and doctor commands.
- Future Trojan TLS and VMess WebSocket/TLS profile templates.
- Xray and OpenClash compatibility documentation.

### Changed

- WireGuard is now presented as an optional conventional VPN module rather than the product's primary protocol.
- Live Xray runtime is separated from the removable 986 CLI/orchestration directory.
- Installer now installs Xray, subscription and registry runtime modules while preserving existing config/state.
- System diagnostics now understand the Xray primary engine.
- README and roadmap distinguish implemented Xray/OpenClash features from future protocol/hosted-subscription work.

### Fixed

- Safe-uninstall design no longer risks deleting the managed Xray executable while claiming that active protocol services are preserved.
- `--purge` preserves live Xray configuration and `/etc/wireguard` rather than turning application cleanup into an unexpected network-service outage.

## [0.1.0-alpha.1] - 2026-09-08

### Added

- Initial professional repository structure.
- Stability/security/performance-first product principles.
- Debian 13+ and Ubuntu 26.04+ amd64 installer validation.
- `986` interactive and direct-command CLI.
- System information and diagnostic commands.
- WireGuard installation/bootstrap module.
- WireGuard user add/list/suspend/resume/renew/delete/config workflow.
- Local installation identity and user registry.
- Configuration backups before managed WireGuard edits.
- Safe uninstaller that preserves existing VPN services/configuration by default.
- Early Access source-available license.
- Security, privacy, architecture and contribution documentation.
- Future control-plane/licensing placeholders with telemetry disabled and enforcement inactive.
- GitHub Actions Bash syntax/ShellCheck baseline.

### Not yet enabled

- Remote telemetry.
- Control-plane registration.
- License enforcement.
- Paid plans.
- Traffic quota accounting.
- OpenVPN and secondary modern engines.
