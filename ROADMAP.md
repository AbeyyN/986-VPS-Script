# Roadmap

## Phase 0 - Foundation

Status: **in progress**

- [x] Professional repository baseline
- [x] Early Access licensing direction
- [x] Installer/uninstaller
- [x] CLI/module layout
- [x] System diagnostics
- [x] WireGuard bootstrap
- [x] Local WireGuard user lifecycle
- [x] Privacy/security documentation
- [x] CI syntax/ShellCheck baseline
- [ ] Production VPS integration test matrix
- [ ] Installer rollback transaction
- [ ] Structured logging

## Phase 1 - Stable seller core

- [ ] Automatic expiry enforcement with systemd timer
- [ ] Traffic/quota accounting
- [ ] Concurrent/device-limit policy where technically reliable
- [ ] Encrypted backup/restore
- [ ] Server-to-server migration
- [ ] Update channels: stable/beta/experimental
- [ ] Signed release verification
- [ ] Safe updater with rollback
- [ ] OpenVPN module
- [ ] Xray-family module evaluation
- [ ] Firewall abstraction and conflict detection

## Phase 2 - 986 control plane

- [ ] Self-hosted API on 986-server
- [ ] Supabase/PostgreSQL schema
- [ ] Installation Ed25519 identity
- [ ] Node registration and signed heartbeat
- [ ] Transparent telemetry consent/notice
- [ ] Owner fleet dashboard
- [ ] Seller dashboard
- [ ] Health and version distribution
- [ ] Cloudflare Tunnel publication when domain is available

## Phase 3 - Licensing and commercial readiness

- [ ] Server-held signing key
- [ ] Signed license leases
- [ ] 72-hour cached lease target
- [ ] Grace-period state machine
- [ ] Management-limited expiry behavior
- [ ] Installation migration/transfer flow
- [ ] Clone/anomaly detection
- [ ] Free Early Access to paid-plan migration tooling
- [ ] Billing-provider integration (provider undecided)

## Phase 4 - Seller/reseller platform

- [ ] Organizations and team roles
- [ ] Reseller credits/limits
- [ ] Bulk account operations
- [ ] Notifications
- [ ] Multi-VPS fleet operations
- [ ] API access for eligible plans
- [ ] Audit events

## Release principle

A feature is not considered complete because it works once. It must have diagnostics, a safe failure mode, documented state, and a recovery/rollback path appropriate to its risk.
