# Network and Privacy Notes

Ajint is a control plane that necessarily communicates with external services. This document describes the current installer/execution path so users can understand where data may travel.

## GitHub

Ajint uses GitHub for the private machine control repository, Actions workflows, repository secrets, workflow dispatch/results and artifacts. Request content committed to the private control repository and workflow evidence are therefore handled by GitHub under the user's GitHub configuration and terms.

Do not place passwords, private keys, long-lived tokens or unnecessary sensitive application data inside request files or command output.

## SSH target

GitHub-hosted Actions runners connect to the configured Linux host/port over SSH. The target address and SSH host-key material are stored as repository Actions secrets by the installer.

## Public IP detection

If `BRIDGE_HOST` is not set, the current installer attempts to discover a public IPv4 address using `https://api.ipify.org`. Set `BRIDGE_HOST` explicitly if you do not want this convenience lookup or if automatic detection is incorrect for the environment.

## Package/bootstrap downloads

Depending on the machine, installation may contact Linux package repositories, GitHub, raw GitHub content endpoints and GitHub CLI release infrastructure to obtain required tools/files.

## Artifacts

Execution evidence can include stdout, stderr, exit code and request identity/hash data. Commands should be designed so secrets are not printed into evidence artifacts.

Users are responsible for assessing whether their own commands, target data and third-party service configuration meet their privacy, compliance and retention requirements.
