# Ajint Security Model

Ajint gives an AI or operator controlled remote hands on a Linux machine through GitHub Actions and SSH. It is a privileged execution adapter, not an AI safety sandbox.

## Trust path

```text
AI / operator
    -> GitHub account / integration
    -> private machine control repository
    -> GitHub Actions workflow
    -> Ajint policy gate
    -> SSH credential + pinned host key
    -> configured Linux user
    -> shell command
    -> result evidence
```

Compromise or misuse at several points in this chain can become machine compromise.

## Critical trust boundaries

### GitHub account and integration

An attacker who can obtain sufficient write/action access to the private control repository may be able to submit executable requests. Protect the GitHub account with strong authentication and review third-party app permissions.

### Private machine control repository

Treat it like an administrative interface, not an ordinary source repository. Do not make it public. Do not grant write access casually.

### GitHub Actions secrets

The SSH private key and connection details are stored as Actions secrets. Workflows should use minimum permissions and should not print secrets.

### SSH host identity

Ajint uses strict host-key checking. A host-key mismatch should fail closed instead of silently trusting a new machine.

### Configured Linux user

This is the effective machine privilege boundary. If configured as `root`, a successful request can potentially change the entire machine. Prefer a less privileged account when practical.

## What the hard routing gate protects

The current gate verifies declared capability, expected execution lane, request SHA-256 integrity, selected higher-priority route markers and diagnosis-time protected-file rules.

These controls can reject certain stale, misrouted or policy-inconsistent requests before SSH execution.

## What it does not protect

The routing gate is **not a shell sandbox**. A request that is correctly routed and passes the gate is still shell code. Ajint does not prove that the command is harmless, correct or economically safe.

Ajint also does not by itself prevent a correctly authorized command from deleting data, stopping services, exposing non-secret application data, or incurring third-party costs.

## Evidence model

Ajint records stdout, stderr, exit code and request identity/evidence for executed requests. Evidence helps determine what ran and whether the transport reported success. Evidence is not a proof that the machine's resulting state is correct; high-impact operations should include explicit post-change verification.

## Recommended deployment posture

- private control repository;
- least-privilege SSH user where practical;
- backups and recovery access independent of Ajint;
- reviewed GitHub app/integration access;
- required CI checks on Ajint core changes;
- test high-impact requests outside production first;
- verify postconditions instead of trusting exit code alone.
