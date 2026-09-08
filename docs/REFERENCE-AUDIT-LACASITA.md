# Reference Audit: SCRIPTMOD-LACASITA

Reference repository: `lacasitamx/SCRIPTMOD-LACASITA`

Date reviewed: 2026-09-08

## Purpose

This document records product and engineering ideas observed in the reference repository that may be useful to 986 VPS Engine.

This is a **clean-room feature study**, not a source-code port. 986 VPS Engine must not copy opaque third-party binaries, obfuscated payloads, branding, or unlicensed source code. Equivalent features are to be implemented independently from documented behavior and official upstream projects.

## Verified repository characteristics

The reviewed repository currently contains:

- a large obfuscated `Instalador/LACASITA.sh` entrypoint;
- an `hcr-server` binary and a readable systemd installer;
- a `SLOWDNS/dns-server` binary;
- a standalone `Reiniciar/reboot` binary;
- a large `jesus` binary;
- a bundled `test/badvpn-master.zip` archive;
- a minimal README.

The current root does not expose the kind of modular source layout, CI, security documentation, release provenance, or dependency policy required by 986 VPS Engine.

## Ideas worth implementing independently

### 1. Defensive per-module installer standard

The HCR installer demonstrates several patterns that are valuable for 986:

- fixed execution PATH and locale;
- strict argument validation;
- root and systemd environment checks;
- installation locking with `flock`;
- ownership and permission validation;
- refusal to trust unexpected symlinks or unit locations;
- executable identity/version validation;
- TLS certificate/private-key matching;
- generated systemd unit verification with `systemd-analyze verify`;
- post-start health verification;
- conservative uninstall behavior that preserves runtime files.

986 should generalize these ideas into a reusable module lifecycle framework instead of duplicating installer logic in every protocol module.

### 2. Systemd sandboxing

Every daemon module should receive the strongest sandbox compatible with that daemon, including appropriate use of:

- `NoNewPrivileges`;
- `PrivateTmp`;
- `PrivateDevices`;
- `ProtectSystem`;
- `ProtectHome`;
- namespace restrictions;
- address-family restrictions;
- resource limits;
- journald output;
- restart-rate limiting.

Capabilities must be granted explicitly per module rather than running every service with unrestricted root privileges.

### 3. Transport relay module

The reference HCR service exposes a relay that can accept TLS/plain transport and forward to a local SSH service.

986 may implement an optional **Transport Relay** module for sellers who still require SSH/HTTP-custom style compatibility. It must be isolated from the Xray core and must not be enabled by default.

Planned properties:

- TLS-only, plain, or controlled compatibility mode;
- configurable listen/target ports;
- port-conflict detection;
- certificate validation;
- independent health/repair commands;
- independent install/remove lifecycle;
- no effect on Xray if the relay fails.

### 4. DNS tunnel fallback

The presence of a SlowDNS server suggests demand for DNS-tunnel connectivity in restrictive networks.

986 may provide **SlowDNS/DNS Tunnel** as an optional compatibility/fallback module, not a default high-performance protocol.

Requirements before release:

- maintained/auditable implementation;
- explicit DNS-domain prerequisites;
- MTU and throughput warnings;
- independent service health;
- no opaque third-party binary ingestion.

### 5. UDP gateway compatibility

The bundled BadVPN archive indicates legacy demand for UDP forwarding alongside SSH-style tunnels.

986 should support the **capability**, not blindly vendor the historical ZIP. A maintained implementation or independently built, provenance-verified component should be selected after testing.

### 6. One service inventory

The number of independent networking components in seller scripts makes port collisions and hidden failures likely.

986 should maintain a canonical service/port registry, for example:

```text
SERVICE              LISTEN        STATUS
Xray Reality         :443          healthy
Xray subscription    :8443         healthy
Hysteria2             :443/udp      healthy
Transport Relay       :8080         disabled
DNS Tunnel            :5300         disabled
WireGuard             :51820/udp    optional
```

Every installer must reserve/check ports through this registry before changing the system.

## Modern 986 protocol direction

The reference repository remains useful for legacy transport ideas, but 986 is not being designed around the historical SSH-script model.

Primary direction:

- Xray-core as the primary modern proxy engine;
- VLESS + REALITY as a primary profile;
- XTLS Vision / supported modern Xray transports;
- Trojan;
- VMess for compatibility where needed;
- Shadowsocks where useful;
- sing-box as an evaluated secondary engine for protocols/features that are better served there;
- Hysteria2 and TUIC as modern QUIC options;
- OpenClash/Mihomo, sing-box clients, v2rayNG-class clients and generic URI compatibility through the 986 Subscription Engine;
- WireGuard and OpenVPN as optional conventional VPN modules;
- legacy SSH relay, DNS tunnel and UDP gateway as optional compatibility modules.

## Product improvements beyond the reference repository

986 should add the following capabilities rather than reproduce a monolithic script:

### Unified customer identity

One customer record controls all assigned protocols:

- one expiry;
- one quota policy;
- one suspend/resume state;
- protocol-specific credentials generated underneath it;
- bulk renew/suspend/delete operations.

### Subscription engine

Generate client-ready output from the same customer identity:

- VLESS URI;
- VMess URI where enabled;
- Trojan URI;
- Shadowsocks URI;
- Mihomo/OpenClash YAML;
- sing-box JSON;
- generic subscription formats;
- QR output where applicable.

### Protocol-independent health engine

Each module must expose common operations:

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

### Transactional changes

Before a module update or configuration mutation:

1. validate prerequisites;
2. acquire a lock;
3. snapshot affected configuration;
4. stage the new configuration;
5. validate syntax;
6. apply atomically;
7. health-check the service;
8. automatically restore the previous known-good state on failure.

### Supply-chain controls

Third-party components must come from official upstream sources and be:

- version pinned;
- architecture matched;
- checksum/signature verified when upstream provides them;
- recorded in local component inventory;
- rollback capable.

Random binaries copied from other script repositories are not accepted.

### Observability

Local CLI and future 986 control plane should expose:

- component versions;
- service status;
- restart count;
- active sessions where technically reliable;
- port map;
- CPU/RAM consumption;
- last health failure;
- update availability;
- config generation/revision;
- license state without exposing customer secrets.

## Explicitly rejected patterns

986 must not adopt:

- giant obfuscated shell payloads as the primary runtime;
- unexplained executable blobs;
- bundled third-party archives without provenance;
- silent remote telemetry;
- direct public database access from seller VPS nodes;
- destructive remote kill switches;
- service-wide root permissions when a narrower sandbox works;
- updates that overwrite configuration before validation;
- dependency on one protocol daemon for unrelated modules;
- "latest at all costs" package/kernel upgrades.

## Implementation rule

A feature observed in another project is only an input to product requirements. The 986 implementation must be independently designed, documented, tested, recoverable, and compatible with the 986 stability-first architecture.
