# ChatGPT VPS Bridge

One-line bootstrap for a private control plane between ChatGPT and a VPS/server.

```text
ChatGPT -> GitHub -> GitHub Actions -> SSH -> your machine
```

It is not tied to Hermes or Codex. You can run the installer from a normal shell, Hermes, Codex, or any agent that can execute shell commands.

## One-line install

Run on the machine you want ChatGPT to control:

```bash
curl -fsSL https://raw.githubusercontent.com/taufec/chatgpt-vps-bridge/main/install.sh | bash
```

The installer creates a **private** GitHub control repo in your own account, installs a dedicated SSH key for that repo, configures GitHub Actions secrets, and prepares a harmless acceptance-test request.

### Requirements

- Linux VPS/server reachable by SSH from GitHub-hosted runners
- `gh`, `git`, `ssh`, `ssh-keygen`, `curl`
- GitHub CLI already authenticated: `gh auth status`
- current GitHub account can create private repos and Actions secrets

If GitHub CLI is not authenticated yet:

```bash
gh auth login
```

Then run the installer again.

## Default private repo

The machine gets its own private control repo:

```text
chatgpt-machine-admin
```

Override the name or connection details if needed:

```bash
BRIDGE_HOST=203.0.113.10 \
BRIDGE_PORT=22 \
BRIDGE_USER=root \
BRIDGE_REPO=chatgpt-my-vps \
curl -fsSL https://raw.githubusercontent.com/taufec/chatgpt-vps-bridge/main/install.sh | bash
```

## How it works

The generated private repo contains:

```text
.github/workflows/admin.yml
requests/current.sh
scripts/run-admin.sh
```

Normal operation:

1. ChatGPT edits `requests/current.sh`.
2. A push to `main` triggers GitHub Actions.
3. The GitHub-hosted runner sends the request over SSH.
4. The request executes on the target with `bash -se`.
5. stdout, stderr, exit code, and request SHA-256 are stored in a 7-day artifact.
6. ChatGPT can inspect the GitHub result and continue from evidence.

## Example

Ask ChatGPT:

> Check disk space on my VPS.

The request can become:

```bash
#!/usr/bin/env bash
set -euo pipefail
df -h
```

For changes, use `inspect -> change -> verify` rather than assuming a command worked.

## Security

**This is a privileged remote-execution bridge.** Anyone who can modify the private control repo may be able to execute commands as the configured SSH user.

The generated workflow uses:

- dedicated SSH identity
- strict host-key checking
- `BatchMode=yes`
- `ForwardAgent=no`
- `RequestTTY=no`
- `ClearAllForwardings=yes`
- GitHub workflow permission `contents: read`
- short-lived execution artifacts

The installer does **not** silently change sudo policy. If you need root-level control, use `root` deliberately or a user with the exact non-interactive sudo privileges you intend to expose.

## Current support

### Public VPS/server via SSH — MVP implemented

The target must be reachable from GitHub-hosted runners.

### Laptop/private device/self-hosted runner — not implemented yet

This is the next mode for machines behind NAT where exposing inbound SSH is undesirable.

## After install

Connect the generated **private control repo** to ChatGPT's GitHub connector. Then ChatGPT can edit requests and inspect results through GitHub.

## Status

Early MVP. Treat each new machine as unverified until its end-to-end acceptance test passes.
