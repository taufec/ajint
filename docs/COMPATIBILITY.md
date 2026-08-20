# Compatibility

Ajint's current primary execution mode is GitHub-hosted Actions -> inbound SSH -> Linux target.

## Verified targets

| Target | Status | Evidence expectation |
| --- | --- | --- |
| Debian 13 (trixie) | E2E tested | Installer acceptance must reach GitHub Actions, SSH target and return artifact evidence |
| Ubuntu 24.04 LTS | E2E tested | Same release gate |

## Bootstrap paths present but not yet independently verified

The installer contains package-manager paths for `apt-get`, `apk`, `dnf` and `yum`. Presence of a bootstrap path is not the same as an E2E-supported platform claim.

A Linux distribution should only move into the verified table after a clean install and real GitHub Actions -> SSH -> evidence test passes.

## Execution-mode requirements

Current SSH mode needs:

- an SSH server already running on the target;
- a host/port reachable from GitHub-hosted runners;
- a supported shell/runtime path;
- an authenticated GitHub account able to create the private control repository, Actions workflows and secrets.

Sleeping, ephemeral, NAT-only or outbound-only environments may fail the current SSH preflight even if Ajint's files can be installed locally.

## ChatGPT / AI integration compatibility

Ajint is AI-agnostic, but direct dispatch requires the AI's GitHub integration to write/update the private control repository and trigger the expected workflow.

| Integration capability | Direct Ajint dispatch |
| --- | --- |
| Repository read only | No |
| Repository write, no workflow/action trigger path | Depends on control-repo trigger mechanism |
| Repository write + required workflow trigger path | Yes |
| Manual Git commit by operator | Yes, Ajint itself can still execute |

Always test the integration capability before assuming that an AI product can dispatch Ajint requests.
