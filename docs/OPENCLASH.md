# Mihomo / OpenClash compatibility

## Status

`0.2.0-alpha.1` provides the first **local** Mihomo/OpenClash export for the bootstrap VLESS REALITY + XTLS Vision profile.

This is not yet the future hosted subscription service. A custom domain/control plane is intentionally not required for this milestone.

Generate the local YAML after Xray bootstrap:

```bash
sudo 986 subscription mihomo
```

The generated file is stored with root-only permissions under:

```text
/etc/986-vps/clients/<client>-mihomo.yaml
```

The export includes the fields required for the current 986 REALITY profile, including:

- `type: vless`;
- server and port;
- UUID;
- TCP network;
- TLS enabled;
- `flow: xtls-rprx-vision`;
- SNI/server name;
- client fingerprint;
- REALITY public key;
- REALITY short ID;
- a minimal selectable proxy group and MATCH rule.

## Compatibility pin

Mihomo's current TLS/REALITY documentation warns that it does not intend to preserve compatibility with Xray behavior introduced in `v26.7.11+`.

For this reason, the first 986 stable channel is intentionally pinned to the older official Xray stable `v26.3.27` while OpenClash/Mihomo interoperability is validated. Newer Xray versions are not promoted simply because they are newer.

Reference:

- https://wiki.metacubex.one/en/config/proxies/tls/
- https://wiki.metacubex.one/en/config/proxies/vless/

## Current limitation

The following is **not yet implemented**:

```text
https://subscription.example/<token>
```

That requires the later 986 control plane/domain milestone. Until then the seller can generate/copy the local YAML or VLESS URI directly from the VPS.

Future hosted subscriptions must use revocable opaque tokens and must never expose server-private keys or unrelated customer credentials.
