# Hard Routing Gate Core Design

## Goal
Promote the proven Ajint machine-control hard routing gate into Ajint core templates so new or updated control repos can receive deterministic policy enforcement without replacing Ajint's SSH execution architecture.

## Scope
- Keep existing `admin` and `parallel` execution lanes.
- Add template policy registry, known-good state, task manifest, policy gate, and evidence validator.
- Wire policy checks in front of execution.
- Make `install.sh` deploy the gate.
- Preserve machine-specific `policy/routes.json` and `policy/known-good.json` when they already exist.
- Refresh `requests/task.json` during install so the installer's acceptance request has the correct SHA-256.
- Do not add Vellum- or machine-specific routes to core defaults.

## Hard rules
1. Existing registered route must be used.
2. Higher-priority specific routes beat generic routes through marker enforcement.
3. Verified known-good state is surfaced by the gate before execution.
4. Diagnosis mode rejects mutations to protected architecture files.
5. Evidence validator returns `UNCONFIRMED` unless the execution evidence chain is complete.

## Rollback
All work lands through one feature PR. Reverting the merge commit restores the previous Ajint core template and installer behavior.
