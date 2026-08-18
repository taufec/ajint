# Ajint Parallel Orchestrator Design

## Goal

Keep ChatGPT as the only reasoning layer while Ajint executes multiple deterministic VPS tasks in parallel and returns structured evidence for the next ChatGPT decision.

## Constraints

- No Hermes runtime.
- No external LLM API or AI CLI.
- No autonomous AI workers and no swarm spawning.
- Existing single-request `requests/current.sh` flow stays compatible.
- Parallel execution must be bounded, auditable, fail-closed between waves, and use the existing SSH security posture.

## Architecture

A batch lives under `requests/batches/<batch-id>/`. Each immediate subdirectory is a wave such as `10-inspect` or `20-verify`. Shell requests inside one wave run concurrently. Waves run in lexical order, and a failed wave prevents later waves from running.

`requests/dispatch.txt` is the atomic trigger. ChatGPT may create or edit all batch files over several commits without execution; only the final dispatch-file change starts the batch.

Execution layers:

1. `run-request.sh`: one SSH request, isolated temporary SSH material, per-worker evidence.
2. `run-wave.sh`: bounded fan-out of all `.sh` requests in one wave and per-wave aggregation.
3. `run-orchestrator.sh`: sequential wave control, failure gate, overall summary.
4. `run-dispatch.sh`: validates batch id and resolves the selected batch.
5. `parallel.yml`: GitHub Actions transport and artifact upload.

## Evidence

Each worker produces stdout, stderr, exit code, request SHA-256, and request name. The orchestrator produces a tab-separated summary with wave, worker, exit code, and SHA-256 plus the selected batch and overall exit code.

## Reliability Rules

- Default maximum parallel requests per wave: 4.
- A wave exceeding the configured cap is rejected rather than queued silently.
- All workers already started in a wave are allowed to finish so evidence is complete.
- Any non-zero worker makes the wave fail.
- No later wave runs after a failed wave.
- Conflicting writes must be placed in separate waves; production mutation/deploy should normally be a single-worker wave.

## Compatibility

`run-admin.sh` remains the entry point for the original single-request workflow but delegates execution to the shared `run-request.sh` primitive.
