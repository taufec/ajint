# Troubleshooting

## `GitHub authentication is required`

Run `gh auth login`, or securely provide `GH_TOKEN` / `AJINT_GITHUB_TOKEN`. Do not paste long-lived tokens into public logs or repository files.

## `SSH_MODE_UNSUPPORTED`

Ajint could not establish that the target supports the current inbound SSH mode. Confirm the target has a reachable SSH server and that the host/port are correct. Restricted or sleeping environments may not support this mode.

## Public IP detection is wrong

Set `BRIDGE_HOST` explicitly. Ajint otherwise attempts to detect a public IPv4 address for convenience.

## Acceptance workflow does not appear

Confirm the generated private control repository has GitHub Actions enabled and that the authenticated GitHub account is allowed to create/dispatch workflows.

## Acceptance workflow fails at SSH

Check the host, port, configured user, firewall/security-group rules and SSH server. Host-key verification failures should be investigated instead of bypassed.

## Policy gate rejects the request

Read the exact `POLICY_GATE=DENY` reason. Common causes are an unknown capability, wrong lane, stale request hash, a more-specific route marker, or a diagnosis request that changes protected policy/architecture files.

Do not disable the gate merely to make a task run. Fix the manifest/request/routing mismatch.

## ChatGPT can read the control repo but cannot dispatch

The ChatGPT/GitHub connection may have read-only repository capability even though Ajint itself is healthy. Verify whether the integration can create/update files and trigger the workflow. If not, use a write-capable GitHub integration/agent or manual Git commit path.

## Workflow says success but result is suspicious

Inspect the artifact, remote exit code, stdout, stderr, request hash and evidence verdict. For state-changing commands, separately verify the actual machine postcondition.
