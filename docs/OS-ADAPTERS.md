# Ajint OS/device adapter boundary

Baseline: 2026-09-26, Phase 4A.

## Status

The stable public release remains `0.1.0-alpha.1` and its published installer still targets remote Linux through GitHub Actions -> SSH. Phase 4A does **not** change that release claim or installer.

This branch adds reusable adapter primitives for the future local/outbound Issue Runner family. The first concrete reference is Android + Termux because working downstream device runners already exist in `ajint-s21`, `ajint-mimax`, and `ajint-zf7`.

There is currently no verified Ajint macOS or Windows implementation in the project repositories. Those platforms are implementation targets, not supported-platform claims, until their adapters and lifecycle installers are tested.

## Layer ownership

| Layer | Owns | Must not own |
| --- | --- | --- |
| `ajint_core` | Issue envelope, request integrity, lifecycle wire markers, generic request validation | shell execution, OS locks, services, device targets |
| `ajint_adapters.local` | adapter target policy, UTF-8 command boundary, durable finished-result handoff | GitHub transport implementation, OS lock primitive |
| `ajint_adapters.termux` | `android.termux.exec`, Termux shell execution, `fcntl` write lock | common protocol semantics |
| installer/supervisor (later phase) | dependencies, boot/autostart, process supervision, local state paths | protocol reimplementation |

## Target-policy split

`validate_request_task()` validates capability, operation, base64 payload and SHA-256 integrity without assuming what a write target looks like.

`validate_exec_task()` remains the backward-compatible repository-target wrapper for the existing VPS contract: writes require `target_repo`; reads forbid it.

Device adapters call `validate_request_task()` and then enforce their own explicit target contract, such as `target_device=s21`.

## Durable local execution contract

The local runtime follows the recovery behavior proven by the S21 iteration:

1. If a finished result is already persisted, return it for publication and do not execute the command again.
2. Validate the issue through the shared core and adapter target policy.
3. Reads run without a write lock.
4. Writes acquire the OS/device adapter's write lock.
5. Execute through the OS adapter executor.
6. Persist the formatted result before attempting publication.
7. Delete the local result only after publication is acknowledged.

This prevents a temporary GitHub/network failure from turning a finished command into a duplicate execution after restart.

## Phase 4A evidence boundary

Unit/regression coverage verifies the shared adapter contract and Termux-specific primitives on CI/Linux. It does not by itself prove an Android phone is online, that Termux:Boot is installed, or that macOS/Windows are supported.

The downstream phone repositories remain the operational evidence for actual Termux lifecycle/recovery behavior until a later promotion phase wires a public installer and runs device E2E acceptance.
