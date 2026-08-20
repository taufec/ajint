# Uninstall / Revoke Ajint Access

Ajint does not need a resident daemon on the target in the current SSH architecture. Revocation therefore focuses on removing the SSH authorization and disabling/removing the private GitHub control plane.

## 1. Keep independent machine access

Before removing anything, make sure you have another tested SSH/recovery path. Do not remove the only key that can recover the machine.

## 2. Remove the Ajint SSH authorization

Ajint-created public keys carry a comment marker in this form:

```text
ajint:<github-owner>/<control-repo>
```

Back up `~/.ssh/authorized_keys`, identify the exact Ajint line by that marker, and remove only that line. Do not delete unrelated SSH keys.

## 3. Disable the GitHub control plane

In the private machine control repository, disable GitHub Actions or remove the Ajint workflow/secret access. If the repository is no longer needed, archive or delete it only after confirming no other automation depends on it.

## 4. Remove GitHub Actions secrets

Remove the Ajint machine connection secrets from the control repository if the repository will remain.

## 5. Verify revocation

A previously valid Ajint workflow should no longer be able to authenticate to the machine. Confirm this intentionally from a safe test rather than assuming that deleting a file was sufficient.
