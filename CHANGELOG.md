# Changelog

All notable changes to 986 VPS Engine will be documented here.

The project follows semantic-versioning concepts, with `alpha`, `beta` and release-candidate identifiers used before stable releases.

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
- Xray-specific status and doctor commands.
- Future Trojan TLS and VMess WebSocket/TLS profile templates.
- Xray engineering/safety documentation.

### Changed

- WireGuard is now presented as an optional conventional VPN module rather than the product's primary protocol.
- Live Xray runtime is separated from the removable 986 CLI/orchestration directory.
- Installer now installs Xray/registry runtime modules and Xray dependencies while preserving existing config/state.
- System diagnostics now understand the Xray primary engine.
- README and roadmap now distinguish implemented Xray features from future protocol templates.

### Fixed

- Safe-uninstall design no longer risks deleting the managed Xray executable while claiming that active protocol services are preserved.
- `--purge` preserves live Xray configuration and `/etc/wireguard` rather than turning application cleanup into an unexpected network-service outage.

### Still not production-ready

- Real Debian 13 VPS integration validation.
- Real Ubuntu Server 26.04 LTS VPS integration validation.
- Unified Xray seller customer lifecycle.
- Trojan/VMess/Shadowsocks lifecycle commands.
- Mihomo/OpenClash subscription output.
- Hysteria2/TUIC/sing-box engine integration.
- Automatic expiry/quota/device-limit enforcement.
- Remote telemetry/control-plane registration/licensing enforcement.

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
- Automatic expiry enforcement.
- Traffic quota accounting.
- OpenVPN/Xray protocol modules.
