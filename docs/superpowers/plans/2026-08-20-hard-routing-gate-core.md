# Hard Routing Gate Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote the existing hard routing gate into Ajint core templates and installer without replacing existing execution lanes.

**Architecture:** Add policy and validator templates in front of the existing admin/parallel workflows. Installer copies gate code and task manifest, seeds machine-specific policy defaults only when absent, and preserves the SSH execution scripts.

**Tech Stack:** Bash, Python 3 standard library, GitHub Actions, GitHub CLI.

**Spec:** `docs/superpowers/specs/2026-08-20-hard-routing-gate-core-design.md`

## Global Constraints
- Existing admin and parallel execution architecture remains intact.
- Core defaults must remain machine-agnostic.
- Existing machine-specific route and known-good files must not be overwritten on reinstall.
- Tests must fail before implementation and pass afterward.

---

### Task 1: Template gate behavior
**Files:** create `tests/test-hard-routing-gate-template.sh`, `template/scripts/policy_gate.py`, `template/scripts/evidence_validator.py`, `template/policy/routes.json`, `template/policy/known-good.json`, `template/requests/task.json`.
- [ ] Write the failing contract/behavior test.
- [ ] Run it and confirm it fails because gate template files are absent.
- [ ] Add the minimum gate templates.
- [ ] Re-run and confirm gate behavior passes.

### Task 2: Workflow wiring
**Files:** modify `template/.github/workflows/admin.yml`, `template/.github/workflows/parallel.yml`.
- [ ] Make the contract test require policy gate before remote execution.
- [ ] Add policy gate and evidence-verdict steps.
- [ ] Re-run the contract test.

### Task 3: Installer promotion
**Files:** modify `install.sh`, `.github/workflows/test.yml`.
- [ ] Make the contract test require installer deployment and policy preservation semantics.
- [ ] Update installer copy/seed logic and acceptance task hash.
- [ ] Add the new test to core CI.
- [ ] Run all existing and new tests plus `git diff --check`.
- [ ] Push feature branch, open PR, wait for CI, merge only if green.
