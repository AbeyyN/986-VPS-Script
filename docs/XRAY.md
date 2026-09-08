# Xray Engine

## Status

The first Xray implementation lands in `0.2.0-alpha.1` and is still Early Access. It is intended for controlled VPS testing before any production claim.

## Stable channel policy

The `stable` channel is a 986-tested/pinned channel, not a synonym for the newest upstream tag.

For this milestone:

- upstream project: `XTLS/Xray-core`;
- pinned version: `v26.3.27`;
- platform asset: `Xray-linux-64.zip`;
- archive SHA-256: `23cd9af937744d97776ee35ecad4972cf4b2109d1e0fe6be9930467608f7c8ae`.

The installer downloads directly from the official upstream GitHub release and refuses installation when the digest or binary-reported version does not match.

## Filesystem separation

The CLI/orchestration layer and the live network runtime are intentionally separated:

```text
/usr/local/lib/986-vps/      986 CLI/runtime modules
/opt/986-vps/xray/           versioned Xray binaries/assets
/etc/986-vps/xray/           live Xray configuration
/var/lib/986-vps/            986 local state/registries
/var/backups/986-vps/        managed backups
```

Removing the 986 CLI must not silently delete the live Xray binary or configuration used by an existing service.

## VLESS REALITY bootstrap

Install the pinned runtime first:

```bash
sudo 986 xray install
```

Then bootstrap the initial VLESS REALITY + XTLS Vision profile:

```bash
sudo 986 xray bootstrap reality \
  --server-name HOSTNAME \
  --target HOSTNAME:443 \
  --port 443 \
  --name bootstrap
```

`--server-name` and `--target` are intentionally required. 986 does not silently choose a third-party REALITY target for the operator.

Before apply, 986:

1. validates all arguments;
2. checks its service/port registry and the actual listening sockets;
3. generates the UUID, X25519 keypair and short ID locally;
4. stages JSON configuration;
5. validates it with `xray run -test`;
6. backs up the previous managed configuration when one exists;
7. applies the staged configuration;
8. verifies the service remains active;
9. restores the previous configuration automatically when the new runtime fails health verification.

## Service hardening

`986-xray.service` runs under a dedicated `986-xray` system account and uses systemd restrictions including `NoNewPrivileges`, private temporary/device namespaces, read-only system protection, kernel/control-group protections and restricted address families.

Hardening settings must remain compatible with the network engine. Any future relaxation requires a documented reason.

## Current profile support

Working in this milestone:

- Xray runtime installation/update from the pinned stable channel;
- VLESS REALITY;
- XTLS Vision flow;
- generated VLESS client URI;
- Xray-specific status and diagnostics;
- transactional configuration rollback;
- binary rollback during an upgrade failure;
- service/port registry integration.

Repository templates exist for future Trojan TLS and VMess WebSocket/TLS compatibility. They are **not yet wired into the seller account engine or claimed production-ready**.

## Remaining work before production status

- Debian 13 real-VPS integration testing;
- Ubuntu Server 26.04 LTS real-VPS integration testing;
- common customer identity across protocols;
- multiple Xray inbounds without replacing the entire bootstrap profile;
- Trojan/VMess/Shadowsocks lifecycle commands;
- automatic certificate lifecycle for TLS profiles;
- subscription/Mihomo/OpenClash output;
- structured logs and repair workflows;
- firewall abstraction and broader port-conflict tests.
