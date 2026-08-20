# Upgrade Ajint

Ajint's installer is designed to be re-run. It updates Ajint-managed control-plane files while preserving unrelated repository history and does not intentionally overwrite existing custom route/known-good policy files.

## Before upgrading

1. Record the currently working Ajint version/tag/commit.
2. Confirm you have independent SSH/recovery access to the machine.
3. Review release notes and security-sensitive changes.
4. Back up any custom policy or workflow changes that overlap Ajint-managed files.

## Upgrade using an immutable release

Once release tags are published, prefer fetching the installer from the exact target tag instead of mutable `main`.

Example shape:

```bash
curl -fsSL https://raw.githubusercontent.com/taufec/ajint/vX.Y.Z/install.sh | AJINT_REF=vX.Y.Z bash
```

Use the exact version shown in the release notes.

## Development upgrade

Using `main` tracks current development and can change between runs:

```bash
curl -fsSL https://raw.githubusercontent.com/taufec/ajint/main/install.sh | bash
```

Use this only when you intentionally want the development snapshot.

## Verify

An upgrade is not complete until the installer acceptance test passes and prints `AJINT_ACCEPTANCE=PASS`.

If a regression is found, use Git history to restore the last known-good Ajint core/control-plane state and re-run verification instead of force-pushing over unrelated history.
