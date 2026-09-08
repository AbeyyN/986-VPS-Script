# Security Policy

## Supported versions

986 VPS Engine is currently Early Access. Security fixes target the latest supported Early Access release unless otherwise announced.

## Reporting a vulnerability

Do **not** publish exploit details, private keys, credentials, server IPs or customer data in a public GitHub issue.

Until a dedicated security mailbox is published, open a minimal GitHub issue stating that you need a private security-reporting channel. Do not include sensitive reproduction data in the public issue.

## Security design principles

- Stability and safe failure are preferred over aggressive enforcement.
- Existing VPN customer configurations must not be destroyed by licensing or update failures.
- PostgreSQL/Supabase must never be exposed directly to managed seller VPS nodes.
- Managed VPS nodes should authenticate to the future control plane using per-installation cryptographic identities, not a shared master secret.
- Future license artifacts must be signed by a server-held signing key.
- Control-plane outages must use cached signed leases/grace periods rather than immediately terminating existing tunnels.
- Telemetry must be documented and must not contain VPN traffic contents, browsing history, customer passwords, customer VPN private keys, SSH private keys or `/etc/shadow`.
- Updates should be checksum/signature verified before production use once the release-signing pipeline is enabled.

## Operational guidance

Before changing VPN/firewall/network configuration:

1. keep an out-of-band console or provider recovery path;
2. maintain a current backup;
3. test on a non-production VPS first;
4. avoid running unreviewed `curl | bash` commands on production hosts;
5. restrict root access and keep the base OS security-supported.

## Scope

Security issues in 986-owned code and deployment guidance are in scope. Vulnerabilities in WireGuard, Linux, OpenVPN or other third-party dependencies should also be reported to the relevant upstream project.
