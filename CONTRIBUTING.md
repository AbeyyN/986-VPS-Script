# Contributing to 986 VPS Engine

Contributions are welcome during Early Access, but this project is intentionally conservative: stability and safe recovery take priority over adding protocol count.

## Before opening a pull request

- Search existing issues and pull requests.
- Keep changes focused and reviewable.
- Do not commit credentials, private keys, real customer data or VPS secrets.
- Run Bash syntax checks and ShellCheck.
- Document user-visible behavior changes in `CHANGELOG.md` when appropriate.
- Preserve existing VPN configurations unless a migration is explicit and reversible.

## Local checks

```bash
bash -n install.sh
bash -n uninstall.sh
bash -n bin/986
find lib -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
shellcheck install.sh uninstall.sh bin/986 lib/986/*.sh
```

## Pull request expectations

A good pull request should explain:

1. the problem;
2. the proposed behavior;
3. compatibility impact;
4. rollback/recovery behavior;
5. security implications;
6. how it was tested.

## Design rules

- Avoid monolithic scripts when a module boundary is reasonable.
- Do not silently change firewall/network behavior.
- Do not make control-plane availability a hard dependency for existing VPN tunnels.
- Do not add hidden telemetry.
- Do not store customer private keys in telemetry or logs.
- Prefer distribution-supported packages/kernels over untested "latest" builds.
- Fail closed for privileged management actions, but fail safely for existing customer connectivity.

## Licensing of contributions

By intentionally submitting a contribution, you confirm that you have the right to submit it and agree that it may be distributed as part of 986 VPS Engine under the repository's current license and future commercial versions. If you cannot agree to that, do not submit the contribution without first obtaining a separate written agreement.
