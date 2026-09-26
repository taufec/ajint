# ADR 0001: Stable public core and downstream iterations

**Status:** Accepted  
**Date:** 2026-09-26

## Decision

`taufec/ajint` is the stable/public Ajint line. Private control-plane and device repositories may iterate ahead, behind or divergently while ideas are being proven.

A downstream improvement does not become public Ajint merely because it is newer. Promotion into this repository requires a separate compatibility, migration, regression, version and release decision.

## Consequences

- Public documentation describes released behavior, not the newest private experiment.
- Device repositories can evolve without forcing premature public migrations.
- Future promotion has an explicit review boundary and rollback point.
