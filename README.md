# Ajint

**AI decides. GitHub carries the instruction. Ajint executes it on the machine.**

Ajint is a lightweight GitHub-based remote execution adapter for AI agents. It connects an AI or agent running outside your server to a Linux VPS/server through GitHub Actions and SSH.

```text
AI / Agent
    ↓
GitHub control repo
    ↓
GitHub Actions
    ↓
Ajint SSH execution layer
    ↓
Linux machine
    ↓
stdout / stderr / exit code / request hash
    ↓
GitHub
    ↓
AI / Agent
```

Ajint is **not the AI agent itself**. It is the execution/control layer that gives an agent remote hands on a machine.

That means the intelligence layer can change independently:

```text
ChatGPT ─┐
Gemini ──┤
Kimi ────┤
Codex ───┤
Claude ──┤
other AI ┘
          ↓
        Ajint
          ↓
       machine
```

The current phase focuses on the execution adapter first. A future integration can plug Ajint into agent runtimes such as GitHub Agentic Workflows instead of rebuilding memory, planning, policy, and agent harnesses from scratch.

## One-line install

Run this on the Linux VPS/server you want to connect:

```bash
curl -fsSL https://raw.githubusercontent.com/taufec/ajint/main/install.sh | bash
```

The installer creates a **private per-machine GitHub control repo**, generates a dedicated SSH identity, configures GitHub Actions secrets, installs the execution workflow, and prepares a harmless acceptance test.

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

Then run the installer again.

## What gets created

By default Ajint creates a private control repository named:

```text
ajint-machine-admin
```

It contains:

```text
.github/workflows/admin.yml
requests/current.sh
scripts/run-admin.sh
```

The public `ajint` repository contains the reusable installer/template. Machine credentials stay in GitHub Actions secrets inside the generated **private** control repository.

## How it works

1. An AI/agent edits `requests/current.sh` in the private control repo.
2. A push to `main` triggers GitHub Actions.
3. The GitHub-hosted runner connects to the target using a dedicated SSH key.
4. The request is piped to `bash -se` on the target machine.
5. stdout, stderr, exit code, and request SHA-256 are saved as an Actions artifact.
6. The AI/agent reads the evidence and decides what to do next.

For changes, the intended operating pattern is:

```text
inspect -> change -> verify
```

A workflow starting successfully is **not** proof that the remote command succeeded. Check the remote exit code and result artifact.

## Custom install

Override connection details or the generated private repo name:

```bash
BRIDGE_HOST=203.0.113.10 \
BRIDGE_PORT=22 \
BRIDGE_USER=root \
BRIDGE_REPO=ajint-my-vps \
curl -fsSL https://raw.githubusercontent.com/taufec/ajint/main/install.sh | bash
```

Current installer variables:

- `BRIDGE_HOST` - public IP or DNS name reachable from GitHub Actions
- `BRIDGE_PORT` - SSH port, default `22`
- `BRIDGE_USER` - SSH user, default current OS user
- `BRIDGE_REPO` - generated private control repo name, default `ajint-machine-admin`

The `BRIDGE_*` variable names are internal compatibility names for the current MVP and may later gain `AJINT_*` aliases.

## Security model

**Ajint is a privileged remote-execution control plane.** Anyone who can modify the generated private control repository may be able to execute commands as the configured SSH user.

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

## Roadmap direction

```text
GitHub Agentic Workflows / other agent runtime
              ↓
            Ajint
              ↓
      VPS / server / device
```

Ajint should stay small and AI-agnostic: execution, evidence, transport, and machine access. Agent memory, planning, policy, and higher-level reasoning can live in the agent runtime above it.

## Status

Early MVP. The SSH-mode adapter exists, but every new machine remains **unverified** until its own end-to-end acceptance test passes.

## License

MIT.
