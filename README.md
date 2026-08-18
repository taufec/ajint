# ChatGPT GitOps

One-line bootstrap for a GitHub-based control plane that lets ChatGPT operate a remote Linux machine through GitHub Actions and SSH.

```text
ChatGPT -> GitHub -> GitHub Actions -> SSH -> your machine
```

It is not tied to Hermes or Codex. You can launch the installer from a normal shell, Hermes, Codex, or any other agent that can execute shell commands.

> This is **GitOps-style remote administration** rather than a fully declarative GitOps controller: a committed request becomes an auditable GitHub Actions execution on the target machine.

## One-line install

Run this on the Linux VPS/server you want ChatGPT to control:

```bash
curl -fsSL https://raw.githubusercontent.com/taufec/chatgpt-gitops/main/install.sh | bash
```

The installer creates a **private per-machine control repository** in your own GitHub account, generates a dedicated SSH identity, configures the required GitHub Actions secrets, installs the workflow files, and prepares a harmless acceptance test.

## Requirements

Current SSH-mode MVP requires:

- Linux VPS/server reachable by SSH from GitHub-hosted runners
- `gh`, `git`, `ssh`, `ssh-keygen`, `curl`
- GitHub CLI authenticated on the target machine
- a GitHub account allowed to create private repositories and Actions secrets

Check authentication:

```bash
gh auth status
```

If needed:

```bash
gh auth login
```

Then run the one-line installer again.

## What gets created

By default, ChatGPT GitOps creates a private control repository named:

```text
chatgpt-machine-admin
```

That private repo contains:

```text
.github/workflows/admin.yml
requests/current.sh
scripts/run-admin.sh
```

The public `chatgpt-gitops` repository is only the reusable installer/template. Machine credentials are stored as GitHub Actions secrets in the generated **private** control repository.

## Architecture

```text
Natural-language request
        ↓
ChatGPT
        ↓
private GitHub control repo
        ↓
requests/current.sh
        ↓
GitHub Actions
        ↓
SSH
        ↓
Linux machine
        ↓
stdout / stderr / exit code / request SHA-256
        ↓
GitHub Actions artifact
        ↓
ChatGPT
```

Normal operation:

1. ChatGPT edits `requests/current.sh` in the private control repo.
2. A push to `main` triggers GitHub Actions.
3. The GitHub-hosted runner connects to the target over SSH.
4. The request is piped to `bash -se` on the target machine.
5. stdout, stderr, exit code, and request SHA-256 are saved in a short-lived artifact.
6. ChatGPT inspects the result and continues from actual evidence.

## Custom install

Override detected connection details or the generated private repo name:

```bash
BRIDGE_HOST=203.0.113.10 \
BRIDGE_PORT=22 \
BRIDGE_USER=root \
BRIDGE_REPO=chatgpt-my-vps \
curl -fsSL https://raw.githubusercontent.com/taufec/chatgpt-gitops/main/install.sh | bash
```

Installer variables:

- `BRIDGE_HOST` - public IP or DNS name reachable from GitHub Actions
- `BRIDGE_PORT` - SSH port, default `22`
- `BRIDGE_USER` - SSH user, default current OS user
- `BRIDGE_REPO` - generated private control repo name, default `chatgpt-machine-admin`

## Example use

After installation and after connecting the generated private repo to ChatGPT, ask:

> Check disk space on my VPS.

A request may become:

```bash
#!/usr/bin/env bash
set -euo pipefail
df -h
```

Or ask:

> Restart this service and verify it recovered.

For changes, the expected operating pattern is:

```text
inspect -> change -> verify
```

A workflow starting successfully is **not** proof that the remote command succeeded. Check the remote exit code and result artifact.

## Security model

**ChatGPT GitOps is a privileged remote-execution control plane.** Anyone who can modify the generated private control repository may be able to execute commands as the configured SSH user.

The generated workflow uses:

- a dedicated SSH identity
- strict SSH host-key checking
- `BatchMode=yes`
- `ForwardAgent=no`
- `RequestTTY=no`
- `ClearAllForwardings=yes`
- minimum GitHub workflow permission (`contents: read`)
- short-lived execution artifacts

The installer does **not** silently change sudo policy. For root-level administration, deliberately install it as `root` or use a user with the exact non-interactive sudo privileges you intend to expose.

Never commit private keys, API keys, passwords, tokens, `.env` files, or other secrets into the control repository.

## Current support

### Public Linux VPS/server via SSH — MVP implemented

The target must be reachable from GitHub-hosted runners over SSH.

### Laptop/private device/self-hosted runner — not implemented yet

This is the planned path for laptops, desktops, homelabs, and machines behind NAT where inbound SSH should not be exposed.

## After installation

1. Open the generated private control repo in GitHub.
2. Connect that repo to ChatGPT's GitHub connector.
3. Trigger the `Machine Admin` workflow once.
4. Verify the acceptance test exits with code `0` and returns the real target hostname/user/uptime.
5. Only then treat that machine as connected.

## Status

Early MVP. The reusable repository and SSH-mode installer exist, but every new machine should remain **unverified** until its own end-to-end acceptance test passes.

## License

MIT.
