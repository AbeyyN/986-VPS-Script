# Privacy and Telemetry Policy

## Current Early Access baseline

Remote telemetry is **disabled** in `0.1.0-alpha.1`.

The configuration contains placeholders for future control-plane integration, but no production control-plane URL is configured and no licensing enforcement is active.

## Planned transparent telemetry

When fleet telemetry is introduced, installation/setup documentation must disclose what is collected before enabling it.

Expected operational fields may include:

- installation ID;
- first seen / last seen;
- VPS public IP;
- coarse region/country when useful for fleet management;
- operating system and version;
- kernel and architecture;
- CPU, RAM and disk capacity/health summary;
- 986 Engine and agent versions;
- enabled modules and service health;
- aggregate account counts;
- license state.

## Data that must not be collected as product telemetry

- VPN traffic payloads;
- browsing history or destination logs;
- customer VPN passwords;
- customer VPN private keys;
- SSH private keys;
- `/etc/shadow`;
- arbitrary file contents from the seller VPS.

## Storage direction

The authoritative future control-plane database is intended to be self-hosted by the project operator using Supabase/PostgreSQL. Managed seller VPS nodes will communicate through a dedicated HTTPS API rather than connecting directly to the database.

## Seller responsibility

A seller/operator remains responsible for their own customer privacy notices, retention practices, local laws, hosting-provider rules, abuse handling and any logs they independently enable outside 986 VPS Engine.

## Changes

Material telemetry/privacy changes should be documented in the changelog and this file before or at the same time they ship.
