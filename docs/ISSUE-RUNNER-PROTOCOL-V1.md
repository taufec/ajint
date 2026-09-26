# Ajint Issue Runner Protocol v1

Protocol identifier: `issue-runner.v1`.

This document defines the platform-neutral contract extracted from the proven downstream Ajint Issue Runner. It does not migrate the public runtime transport by itself. The public `0.1.0-alpha.1` Actions -> SSH behavior remains unchanged until a separately reviewed release changes it.

## Common core

The `ajint_core.protocol` module owns only semantics that can be shared across Linux, macOS, Windows and Android/Termux adapters:

- exact `AJINT_RUN` issue candidate filtering (excluding pull requests)
- GitHub issue envelope validation
- run id, capability, mode and operation validation
- base64 request decoding plus SHA-256 integrity verification
- read/write target repository rules
- progress and heartbeat payload formatting
- terminal result/failure markers
- deterministic repository lock-key naming

The shared module contains no service-manager calls, OS lock primitive, process launching, shell execution or machine-specific filesystem path.

## Envelope

An Issue Runner task is represented by an `AJINT_RUN` issue whose JSON body contains, for an executable request:

- `run_id`
- `capability`
- `mode`: `execute` or `diagnose`
- `operation`: `read` or `write`
- `request_b64`
- `request_sha256`
- `target_repo` for write operations only

Adapters decide which authors and capabilities are allowed. The common core validates the envelope and returns a normalized task; it does not execute it.

## Lifecycle wire markers

Adapters can render lifecycle state using the shared formatting contract:

- `AJINT_PROGRESS run_id=... state=... heartbeat=... elapsed=...`
- `AJINT_RESULT run_id=... exit_code=...`
- `AJINT_FAILED run_id=... reason=...`
- `AJINT_REJECTED reason=...`

Heartbeat payload fields are `run_id`, `state`, `heartbeat_epoch`, `elapsed_seconds` and `detail`.

## Concurrency boundary

The core exposes a deterministic repository-specific lock key such as `taufec--chat-ledger.lock`. The lock implementation is deliberately outside the common core. Linux may use one primitive while macOS, Windows or Termux adapters may use another, as long as they preserve the same per-repository serialization contract for writes.

## Compatibility source

The v1 contract is derived from the currently deployed `taufec/ajint-machine-admin` Issue Runner behavior verified during Phase 1 and Phase 2. Public core tests preserve the request validation, lifecycle marker and lock-key semantics without importing VPS-only implementation details.
