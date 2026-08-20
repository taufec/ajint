# Ajint

**AI decides. GitHub carries the instruction. Ajint executes it on the machine.**

> **Status: 0.1.0-alpha.1 — Developer Preview**
>
> Ajint works end-to-end on tested Linux targets, but it is not production-stable yet. Interfaces, setup and security controls may still change during `0.x`.

Ajint is a lightweight, AI-agnostic execution adapter for remote Linux machines. It gives ChatGPT or another AI/agent remote hands through GitHub Actions and SSH while keeping execution evidence in GitHub.

```text
ChatGPT / AI / Agent
        ↓
private GitHub control repo
        ↓
GitHub Actions
        ↓ SSH
Linux machine
        ↓
stdout / stderr / exit code / request hash
        ↓
GitHub evidence
```

Ajint is **not the AI agent**. Memory, planning, policy and reasoning belong to the agent runtime above it. Ajint focuses on transport, execution, routing gates and evidence.

## Start here

If your goal is simply **"let ChatGPT safely operate my Linux VPS through GitHub"**, use the beginner guide:

- [ChatGPT → Ajint → Linux end-to-end quick start](docs/CHATGPT-QUICKSTART.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Security model](docs/SECURITY-MODEL.md)
- [Compatibility](docs/COMPATIBILITY.md)
- [Network and privacy notes](docs/NETWORK-AND-PRIVACY.md)
- [Operational disclaimer](DISCLAIMER.md)

Before using Ajint on a machine that matters, understand that approved requests can execute real shell commands with the configured SSH user's privileges.

## Quick install

### Standard Linux

Public alpha installs should pin both the fetched script and Ajint's internal source ref:

```bash
curl -fsSL https://raw.githubusercontent.com/taufec/ajint/v0.1.0-alpha.1/install.sh | AJINT_REF=v0.1.0-alpha.1 bash
```

Pinning both values prevents the tagged installer from silently fetching templates from mutable `main`.

### Minimal Linux (no curl required)

If Python 3 is available:

```bash
AJINT_REF=v0.1.0-alpha.1 python3 -c "import urllib.request;exec(compile(urllib.request.urlopen('https://raw.githubusercontent.com/taufec/ajint/v0.1.0-alpha.1/bootstrap.py').read(),'bootstrap.py','exec'))"
```

If Git is available:

```bash
d=$(mktemp -d) && git clone -q --depth 1 --branch v0.1.0-alpha.1 https://github.com/taufec/ajint "$d" && AJINT_REF=v0.1.0-alpha.1 bash "$d/install.sh"; rc=$?; rm -rf "$d"; exit $rc
```

Ajint auto-installs missing runtime tools (`gh`, `curl`, Git and OpenSSH client utilities) when it can use `apt-get`, `apk`, `dnf` or `yum` with root/sudo. If a restricted Linux environment reports package-manager success but still does not expose `gh`, Ajint falls back to GitHub CLI's official precompiled Linux release when Python 3 is available.

GitHub authentication is still a one-time trust boundary. Either authenticate first with `gh auth login`, or provide `GH_TOKEN` / `AJINT_GITHUB_TOKEN` through a secure environment.

## What the installer does

1. Detects/installs missing runtime dependencies.
2. Verifies GitHub authentication.
3. Creates or reuses a private per-machine control repo (default `ajint-machine-admin`).
4. Rotates one dedicated Ajint SSH key without accumulating duplicate Ajint keys.
5. Configures GitHub Actions secrets **before** workflow-triggering pushes.
6. Creates/updates Ajint-managed control files without force-pushing the repo.
7. Dispatches a real GitHub Actions acceptance test.
8. Downloads the result artifact and only prints `AJINT_ACCEPTANCE=PASS` when remote exit code is `0` and expected output is present.

Re-running the installer is supported: unrelated files/history in the private control repo are preserved.

## Requirements

Current SSH mode requires:

- a Linux VPS/server reachable from GitHub-hosted runners over SSH;
- Bash;
- at least one way to fetch the installer (`curl`, Python 3, or Git);
- root/sudo only if dependencies need to be installed;
- a GitHub account that can create private repositories, Actions secrets and workflows.

For direct **ChatGPT → Ajint** operation, your ChatGPT/GitHub environment must also have repository write/action capability for the private control repo. Some integrations may be read-only; the quick-start guide includes a capability preflight.

The target must already have a working SSH server reachable on the configured host/port. Ajint does not silently open firewalls or install/enable `sshd`.

## Tested Linux targets

Real internet → GitHub Actions → SSH → target → artifact E2E is part of the release gate.

- Debian 13 (trixie)
- Ubuntu 24.04 LTS

Other Linux distributions have package-manager fallbacks but remain unverified until their own E2E test passes.

## Custom target

```bash
curl -fsSL https://raw.githubusercontent.com/taufec/ajint/v0.1.0-alpha.1/install.sh | \
  BRIDGE_HOST=203.0.113.10 \
  BRIDGE_PORT=22 \
  BRIDGE_USER=root \
  BRIDGE_REPO=ajint-my-vps \
  AJINT_REF=v0.1.0-alpha.1 bash
```

Current compatibility variables:

- `BRIDGE_HOST` - public IP/DNS reachable from GitHub Actions;
- `BRIDGE_PORT` - SSH port, default `22`;
- `BRIDGE_USER` - current OS user, default `id -un`;
- `BRIDGE_REPO` - private control repo name, default `ajint-machine-admin`.

## First safe ChatGPT task

After the installer prints `AJINT_ACCEPTANCE=PASS`, connect the private control repo to a ChatGPT environment with GitHub write/action capability and start with a harmless request:

> Using Ajint, run `hostname; whoami; uptime` on the connected Linux machine. Use the existing `linux.generic` route, preserve the current routing architecture, and return the workflow evidence, stdout, stderr and exit code.

Full steps and capability checks are in [docs/CHATGPT-QUICKSTART.md](docs/CHATGPT-QUICKSTART.md).

## Parallel orchestration — ChatGPT commander mode

ChatGPT remains the reasoning layer. Ajint can execute deterministic shell requests in bounded parallel waves; the workers are executors, not independent AI agents.

```text
ChatGPT commander
       ↓
private GitHub control repo
       ↓
Ajint parallel orchestrator
       ↓
wave 10: inspect-a.sh + inspect-b.sh + inspect-c.sh  (parallel)
       ↓ success only
wave 20: verify-a.sh + verify-b.sh                   (parallel)
       ↓
structured evidence → ChatGPT
```

Prepare a batch under `requests/batches/<batch-id>/<wave>/*.sh`. Only creating/changing `requests/dispatch.txt` to `<batch-id>` triggers execution. Requests in one wave run concurrently (default cap 4); waves run lexically and stop after the first failed wave. Conflicting writes and production deploys should use separate/single-worker waves.

## Security

Ajint is a privileged remote-execution control plane. Anyone able to modify executable requests in the generated private control repo may be able to execute commands as the configured SSH user if the request passes the control path.

The workflow uses a dedicated SSH identity, strict host-key checking, `BatchMode=yes`, no agent forwarding, no TTY, cleared forwarding, minimum GitHub workflow permissions and short-lived result artifacts.

The hard routing gate validates capability/lane/request integrity and selected policy rules. It is **not a shell sandbox** and does not prove a permitted command is safe.

Ajint does **not** silently change sudo policy. Never commit private keys, tokens, passwords or `.env` files into the control repo.

Read:

- [SECURITY.md](SECURITY.md) — vulnerability reporting and supported security posture;
- [docs/SECURITY-MODEL.md](docs/SECURITY-MODEL.md) — trust boundaries and non-goals;
- [DISCLAIMER.md](DISCLAIMER.md) — operational risk and warranty/liability context.

## Current scope

### Public Linux server via SSH — implemented and E2E tested

### Laptop/private device/outbound runner — not implemented yet

Future agent runtimes can sit above Ajint without changing the Linux execution adapter.

## Upgrade, rollback and uninstall

- [Upgrade](docs/UPGRADE.md)
- [Uninstall / revoke access](docs/UNINSTALL.md)
- [Release lifecycle](docs/RELEASES.md)
- [Maintainer repository setup](docs/MAINTAINER-SETUP.md)
- [Changelog](CHANGELOG.md)

Ajint and its control plane are Git-backed. Preserve known-good commits/tags so regressions can be reviewed and reverted instead of force-pushing over history.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
