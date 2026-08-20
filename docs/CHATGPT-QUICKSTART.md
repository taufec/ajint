# ChatGPT -> Ajint -> Linux: End-to-End Quick Start

This guide starts from a Linux machine and ends with ChatGPT returning evidence from a harmless command actually executed on that machine.

## 1. What you need

- a GitHub account;
- a Linux VPS/server reachable from GitHub-hosted Actions runners over SSH;
- Bash;
- `curl`, Python 3 or Git to fetch Ajint;
- permission to create a private GitHub repository, Actions workflows and Actions secrets;
- a ChatGPT/GitHub environment that can **write to the private Ajint control repository** if you want direct ChatGPT dispatch.

Ajint can execute real shell commands. Read `../DISCLAIMER.md` and `SECURITY-MODEL.md` first if the target matters.

## 2. Confirm SSH reachability

Ajint does not silently install/enable `sshd` or open a firewall. Your target must already accept SSH on the host/port you intend to use.

## 3. Authenticate GitHub on the Linux machine

If GitHub CLI is already installed:

```bash
gh auth login
```

Ajint can install GitHub CLI on supported Linux environments, but authentication remains a one-time trust boundary. A securely provided `GH_TOKEN` or `AJINT_GITHUB_TOKEN` is also supported.

## 4. Install Ajint

For the public alpha, pin both the fetched script and Ajint's internal source ref:

```bash
curl -fsSL https://raw.githubusercontent.com/taufec/ajint/v0.1.0-alpha.1/install.sh | AJINT_REF=v0.1.0-alpha.1 bash
```

This keeps the installer and the templates it fetches on the same immutable release tag.

For a custom target:

```bash
curl -fsSL https://raw.githubusercontent.com/taufec/ajint/v0.1.0-alpha.1/install.sh | \
  BRIDGE_HOST=203.0.113.10 \
  BRIDGE_PORT=22 \
  BRIDGE_USER=root \
  BRIDGE_REPO=ajint-my-vps \
  AJINT_REF=v0.1.0-alpha.1 bash
```

## 5. Wait for Ajint's own acceptance result

A successful installer finishes with:

```text
AJINT_ACCEPTANCE=PASS
```

It also prints the private control repository URL and GitHub Actions acceptance run URL.

If acceptance does not pass, stop here and use `TROUBLESHOOTING.md`.

## 6. Connect the private control repository to ChatGPT

Authorize only the repository/account access you intend to use.

Before asking ChatGPT to execute anything, test connector capability without making a change:

> Inspect my Ajint private machine control repository. Tell me whether this ChatGPT environment can create or update repository files and trigger the required GitHub workflow. Do not change anything.

If ChatGPT can only read the repository, direct ChatGPT -> Ajint dispatch is unavailable in that environment. Ajint itself may still work; use a GitHub integration/agent with repository write capability or commit the request manually.

## 7. Run the first harmless command from ChatGPT

Use a low-impact request first:

> Using Ajint, run `hostname; whoami; uptime` on the connected Linux machine. Use the existing `linux.generic` route. Update `requests/task.json` with the request SHA-256 before changing the executable request file, then use the existing workflow. Return the workflow result, stdout, stderr, exit code and evidence verdict. Do not change Ajint architecture or routing.

The expected flow is:

```text
ChatGPT
  -> private Ajint control repo
  -> task manifest + request
  -> GitHub Actions
  -> policy gate
  -> SSH
  -> Linux
  -> evidence artifact
  -> ChatGPT
```

## 8. What success looks like

Do not accept only "the workflow passed" as proof of machine execution. Check:

- request/evidence identity matches the submitted request;
- evidence verdict is valid;
- remote exit code is `0`;
- stdout contains the machine's hostname/user/uptime;
- stderr is understood if non-empty.

## 9. Then move to real tasks

For impactful work, ask ChatGPT to separate diagnosis from mutation, preserve the current routing architecture, state the rollback path, execute through the appropriate Ajint lane, and verify the resulting machine state after the command finishes.
