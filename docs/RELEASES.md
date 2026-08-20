# Release Lifecycle

Ajint uses Semantic Versioning.

## Current maturity

Current source version: **0.1.0-alpha.1**

Status: **Developer Preview / Alpha**

Alpha means the core works, but interfaces, setup, routing policy and operational behavior may still change. It should not be presented as production-stable.

## Maturity labels

### Alpha

Use for early adopters and controlled testing. Breaking changes are allowed. Documentation and compatibility coverage are still expanding.

### Beta

Use only after clean end-to-end onboarding is reproducible across multiple environments, upgrade/uninstall/recovery paths are proven, compatibility documentation is broader, and security/operational docs are complete enough for independent users.

### Stable / 1.0.0

Use when the public operational contract is intended to remain backward compatible except through documented major-version changes.

## Release procedure

1. Update `VERSION` and `CHANGELOG.md`.
2. Run all CI tests.
3. Run a real internet -> GitHub Actions -> SSH -> target -> evidence acceptance test on supported targets.
4. Review security-sensitive diffs.
5. Merge through protected `main`.
6. Create an immutable Git tag such as `v0.1.0-alpha.1` from the verified commit.
7. Publish a GitHub pre-release for alpha/beta versions.
8. Change public install examples from mutable `main` to the immutable tag before announcing the release.

Do not call a source snapshot a released version until the tag points to the verified commit.
