# Contributing to Ajint

Ajint is currently an early developer preview. Small, reviewable changes with explicit tests are preferred over large rewrites.

## Development rules

1. Create a feature or fix branch from `main`.
2. Keep privileged execution behavior explicit. Do not silently broaden permissions, sudo policy, network exposure or credential scope.
3. Add or update tests for behavior changes.
4. Run the repository test workflow before merge.
5. Document user-visible changes in `CHANGELOG.md`.
6. Do not commit tokens, private keys, passwords, `.env` files, real hostnames/IPs or private control-repository artifacts.

## Pull requests

A good pull request states:

- the problem being solved;
- the security/operational impact;
- what changed;
- how it was tested;
- rollback considerations when relevant.

Changes to routing, evidence validation, SSH execution, installer trust boundaries or GitHub Actions permissions deserve extra scrutiny because they can change the effective security boundary of Ajint.
