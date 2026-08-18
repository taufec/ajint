# Ajint Parallel Orchestrator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add bounded parallel delegation and sequential wave orchestration while keeping ChatGPT as the sole reasoning layer.

**Architecture:** One request primitive executes over SSH and writes isolated evidence. Wave and batch scripts compose that primitive without adding any AI runtime. A dispatch file is the only automatic batch trigger so multi-file batch preparation is atomic from the execution point of view.

**Tech Stack:** Bash, GitHub Actions, SSH, coreutils.

**Spec:** `docs/superpowers/specs/2026-08-18-parallel-orchestrator-design.md`

## Global Constraints

- No Hermes runtime.
- No external LLM API or AI CLI.
- No autonomous AI workers or swarm.
- Preserve the existing single-request flow.
- Default maximum parallel requests per wave is 4.

---

### Task 1: Executable behavior tests

**Files:**
- Create: `tests/test-orchestrator.sh`
- Create: `.github/workflows/test.yml`

**Interfaces:**
- Consumes: future `template/scripts/run-request.sh`, `run-wave.sh`, `run-orchestrator.sh`, `run-dispatch.sh`.
- Produces: regression coverage for evidence capture, true concurrent fan-out, wave ordering, failure gating, and dispatch validation.

- [ ] Write tests before production scripts.
- [ ] Run CI and verify RED because `run-request.sh` does not exist.
- [ ] Keep the fake SSH transport local; do not require VPS secrets in tests.

### Task 2: Single-request primitive

**Files:**
- Create: `template/scripts/run-request.sh`
- Modify: `template/scripts/run-admin.sh`

**Interfaces:**
- `bash run-request.sh REQUEST RESULT_DIR`
- Returns the remote exit code and writes `stdout.txt`, `stderr.txt`, `exit-code.txt`, `request-sha256.txt`, `request-name.txt`.

- [ ] Implement isolated temporary key and known-host files.
- [ ] Preserve strict SSH options.
- [ ] Make `run-admin.sh` a compatibility wrapper using `result/`.
- [ ] Run tests.

### Task 3: Parallel wave executor

**Files:**
- Create: `template/scripts/run-wave.sh`

**Interfaces:**
- `bash run-wave.sh WAVE_DIR RESULT_DIR`
- Runs all top-level `.sh` requests concurrently, bounded by `AJINT_MAX_PARALLEL` default 4.
- Produces `summary.tsv` with `worker`, `exit_code`, `sha256`.

- [ ] Reject empty waves and waves over the cap.
- [ ] Launch all accepted requests before waiting.
- [ ] Wait for every worker and preserve every result.
- [ ] Return non-zero if any worker fails.
- [ ] Run tests.

### Task 4: Sequential orchestration and dispatch

**Files:**
- Create: `template/scripts/run-orchestrator.sh`
- Create: `template/scripts/run-dispatch.sh`
- Create: `template/.github/workflows/parallel.yml`

**Interfaces:**
- `bash run-orchestrator.sh BATCH_DIR RESULT_DIR`
- `bash run-dispatch.sh DISPATCH_FILE`

- [ ] Sort wave directories lexically.
- [ ] Run each wave sequentially and stop after the first failed wave.
- [ ] Aggregate overall `summary.tsv` with wave and worker columns.
- [ ] Validate dispatch ids against `[A-Za-z0-9._-]+` and reject `.` / `..`.
- [ ] Trigger the Actions workflow only when `requests/dispatch.txt` changes.
- [ ] Upload `result/` even on failure.
- [ ] Run tests.

### Task 5: Installer and documentation

**Files:**
- Modify: `install.sh`
- Modify: `README.md`

**Interfaces:**
- Fresh installs copy both single and parallel execution layers into the private control repo.

- [ ] Copy all new scripts and `parallel.yml` during install.
- [ ] Do not pre-create `dispatch.txt`, avoiding an accidental install-time batch run.
- [ ] Document batch/wave/dispatch usage and ChatGPT-only commander model.
- [ ] Run full tests and shell syntax checks.
