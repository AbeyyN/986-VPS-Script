# Unified Seller Account Engine

`0.3.0-alpha.1` introduces the first unified seller identity model for 986 VPS Engine.

## Current scope

One seller user now owns one persistent customer identity with:

- username;
- lifecycle status (`active`, `suspended`, `expired`);
- expiry date;
- assigned protocol list;
- persistent Xray UUID;
- creation/update timestamps;
- per-user VLESS REALITY URI;
- per-user Mihomo/OpenClash YAML export.

The current protocol assignment supported by the seller engine is:

```text
vless-reality
```

The schema is deliberately protocol-aware so Hysteria2, TUIC, Trojan and other engines can later attach credentials to the same customer identity instead of creating unrelated user databases.

## Storage

Seller registry:

```text
/var/lib/986-vps/sellers.tsv
```

Columns:

```text
username
status
expires_at
protocols
xray_uuid
created_at
updated_at
```

Generated client exports remain root-only under:

```text
/etc/986-vps/clients/
```

The legacy WireGuard registry remains separate during migration and is available through `986 wireguard user ...`.

## Commands

Create a 30-day seller user:

```bash
sudo 986 user add alice --days 30 --protocol vless-reality
```

Inspect users:

```bash
sudo 986 user list
sudo 986 user show alice
```

Suspend/resume:

```bash
sudo 986 user suspend alice
sudo 986 user resume alice
```

Renew:

```bash
sudo 986 user renew alice 30
```

Delete:

```bash
sudo 986 user delete alice
```

Generate client outputs:

```bash
sudo 986 subscription uri alice
sudo 986 subscription mihomo alice
sudo 986 subscription status alice
```

## Suspend/resume design

Suspension does not rotate or destroy the customer's Xray UUID.

Instead, 986 transactionally removes only that user's `username@986.local` identity from the managed Xray inbound. Resume inserts the same UUID again.

This preserves stable client credentials while disabling access.

## Expiry design

The installer enables:

```text
986-user-expiry.timer
```

The timer checks every 30 minutes, with a small randomized delay. It only restarts Xray when one or more active users have actually expired.

Manual enforcement:

```bash
sudo 986 user expire
```

Expired users are removed from the managed Xray inbound in one batch transaction and then marked `expired` in the seller registry. Other customers remain untouched.

A renewed expired user is not silently reactivated. Renew the expiry first, then explicitly resume:

```bash
sudo 986 user renew alice 30
sudo 986 user resume alice
```

This avoids unexpected service reactivation.

## Concurrency safety

All seller mutations executed through the `986` CLI share one operation lock:

```text
/var/lib/986-vps/seller-operation.lock
```

This prevents the automatic expiry timer from racing a manual add/suspend/resume/renew/delete operation.

## Current limitations

Not yet complete:

- quota accounting;
- bandwidth policy;
- concurrent/device limits;
- multi-protocol credentials on one user;
- bulk operations;
- reseller ownership/credits;
- online-session reporting;
- hosted tokenized subscription URLs;
- remote dashboard/control-plane synchronization.

Those features must extend this identity model instead of creating incompatible parallel account databases.
