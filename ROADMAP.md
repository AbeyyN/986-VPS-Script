# Roadmap

## Phase 0 - Foundation

Status: **in progress**

- [x] Professional repository baseline
- [x] Early Access licensing direction
- [x] Installer/uninstaller
- [x] CLI/module layout
- [x] System diagnostics
- [x] WireGuard bootstrap as initial working module
- [x] Local WireGuard user lifecycle
- [x] Privacy/security documentation
- [x] CI syntax/ShellCheck baseline
- [x] Clean-room reference audit policy
- [ ] Production VPS integration test matrix
- [ ] Shared module lifecycle framework
- [ ] Installer transaction/rollback engine
- [ ] Per-module installation lock
- [ ] Component provenance/checksum inventory
- [ ] Structured logging
- [ ] Canonical service/port registry and conflict detection

## Phase 1 - Xray-first seller core

Priority: **P0**

- [ ] Official Xray-core acquisition with version pinning and checksum/signature verification
- [ ] Hardened `986-xray.service`
- [ ] Xray config staging, syntax validation, atomic apply and rollback
- [ ] VLESS + REALITY profile
- [ ] VLESS + XTLS Vision / current supported Xray transport profile
- [ ] Trojan profile
- [ ] VMess compatibility profile
- [ ] Shadowsocks compatibility profile
- [ ] Xray health/doctor/repair workflow
- [ ] Xray safe upgrade/rollback
- [ ] Common user identity across Xray protocols
- [ ] Production integration tests on Debian 13 amd64
- [ ] Production integration tests on Ubuntu Server 26.04 LTS amd64

## Phase 2 - Subscription and client compatibility

Priority: **P0/P1**

- [ ] Unified subscription engine
- [ ] VLESS URI generation
- [ ] VMess URI generation where enabled
- [ ] Trojan URI generation
- [ ] Shadowsocks URI generation
- [ ] Mihomo/OpenClash YAML output
- [ ] sing-box JSON output
- [ ] Generic subscription output
- [ ] QR output where applicable
- [ ] Subscription token rotation/revocation
- [ ] Customer-safe export that never exposes unrelated server secrets

## Phase 3 - Modern secondary protocols

Priority: **P1**

- [ ] Evaluate stable sing-box as secondary engine
- [ ] Hysteria2
- [ ] TUIC
- [ ] QUIC/UDP firewall and MTU validation
- [ ] Per-engine independent service sandbox
- [ ] Per-engine health/repair/rollback

## Phase 4 - Seller account engine

- [ ] Automatic expiry enforcement with systemd timer
- [ ] Traffic/quota accounting
- [ ] Concurrent/device-limit policy where technically reliable
- [ ] Unified suspend/resume across assigned protocols
- [ ] Bulk account create/renew/suspend/delete
- [ ] Online/session visibility where technically reliable
- [ ] Expiring-account reporting
- [ ] Reseller-ready ownership fields

## Phase 5 - Optional compatibility modules

These modules must remain isolated from the modern Xray seller core.

- [ ] WireGuard retained as optional conventional VPN module
- [ ] OpenVPN optional conventional VPN module
- [ ] Transport Relay for SSH/HTTP-custom style compatibility
- [ ] SlowDNS/DNS Tunnel fallback module
- [ ] Maintained/provenance-verified UDP gateway capability
- [ ] SSH/SSL compatibility management where justified by seller demand

No opaque executable copied from another script repository is permitted.

## Phase 6 - Operations, backup and migration

- [ ] Encrypted backup/restore
- [ ] Server-to-server migration
- [ ] Update channels: stable/beta/experimental
- [ ] Signed release verification
- [ ] Safe updater with rollback
- [ ] Firewall abstraction
- [ ] Certificate lifecycle/validation
- [ ] Service restart-rate monitoring
- [ ] Config revision history
- [ ] Disaster-recovery runbook

## Phase 7 - 986 control plane

- [ ] Self-hosted API on 986-server
- [ ] Supabase/PostgreSQL schema
- [ ] Installation Ed25519 identity
- [ ] Node registration and signed heartbeat
- [ ] Transparent telemetry consent/notice
- [ ] Owner fleet dashboard
- [ ] Seller dashboard
- [ ] Health and version distribution
- [ ] Component/version inventory
- [ ] Security/anomaly events
- [ ] Cloudflare Tunnel publication when domain is available

## Phase 8 - Licensing and commercial readiness

- [ ] Server-held signing key
- [ ] Signed license leases
- [ ] 72-hour cached lease target
- [ ] Grace-period state machine
- [ ] Management-limited expiry behavior
- [ ] Installation migration/transfer flow
- [ ] Clone/anomaly detection
- [ ] Free Early Access to paid-plan migration tooling
- [ ] Billing-provider integration (provider undecided)

Existing VPN/proxy tunnels must not be destroyed simply because licensing or the control plane is temporarily unavailable.

## Phase 9 - Seller/reseller platform

- [ ] Organizations and team roles
- [ ] Reseller credits/limits
- [ ] Multi-VPS fleet operations
- [ ] Notifications
- [ ] API access for eligible plans
- [ ] Audit events
- [ ] Fleet-wide safe update orchestration
- [ ] Per-seller and per-reseller dashboards

## Engineering standards derived from reference audits

Every daemon/module should support a common lifecycle:

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

Install/update operations should use locking, permission checks, staged configuration, syntax validation, atomic application, health verification and automatic restoration of the previous known-good state on failure.

See `docs/REFERENCE-AUDIT-LACASITA.md`.

## Release principle

A feature is not considered complete because it works once. It must have diagnostics, a safe failure mode, documented state, a provenance record for third-party components, and a recovery/rollback path appropriate to its risk.

Priority remains:

**Stability > Security > Performance > Maintainability > Features > Newest-version adoption only when production-safe.**
