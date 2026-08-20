# Security Policy

Ajint is a privileged remote-execution control plane. Security reports involving command execution, credential exposure, workflow bypass, request-integrity bypass, host-key verification, secret handling or authorization boundaries are treated as security-sensitive.

## Supported versions

| Version | Status |
| --- | --- |
| `0.1.x-alpha` | Developer preview; security fixes are best-effort on the latest source/release |
| Older development snapshots | Not supported |

Until Ajint reaches a stable release, users should expect security-related behavior and interfaces to change.

## Reporting a vulnerability

Do not publish secrets, private keys, tokens, exploit payloads or machine-identifying sensitive data in a public issue.

If GitHub private vulnerability reporting is available for this repository, use it. Otherwise contact the repository maintainer privately through the GitHub account associated with this repository before disclosing exploit details publicly.

A useful report includes:

- affected Ajint version, tag or commit;
- affected workflow or script;
- prerequisites required to exploit the issue;
- expected versus observed security boundary;
- a minimal reproduction that does not expose real credentials;
- whether the issue can execute commands, bypass routing, alter evidence, leak secrets or affect host-key validation.

## Security boundaries

Read `docs/SECURITY-MODEL.md` before deploying Ajint. In particular, anyone who can modify an executable request in the private machine control repository may be able to execute commands with the configured SSH user's privileges if other controls allow that request to run.
