"""Cross-platform contract shared by Ajint Issue Runner adapters."""

from __future__ import annotations

import base64
import hashlib
import json
import re
from dataclasses import dataclass
from typing import Any, Iterable, Mapping

PROTOCOL_VERSION = "issue-runner.v1"
RUN_ID = re.compile(r"^run-[a-z0-9][a-z0-9-]{15,79}$")
TARGET_REPO = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")


class BundleError(ValueError):
    pass


@dataclass(frozen=True)
class IssueEnvelope:
    run_id: str
    capability: str
    mode: str
    payload: Mapping[str, Any]


@dataclass(frozen=True)
class ExecTask:
    run_id: str
    capability: str
    mode: str
    operation: str
    target_repo: str | None
    request: bytes


def validate_issue_envelope(issue: Mapping[str, Any], *, allowed_authors: Iterable[str]) -> IssueEnvelope:
    author = ((issue.get("user") or {}).get("login") or "")
    if author not in set(allowed_authors):
        raise BundleError("AUTHOR_DENIED")
    try:
        payload = json.loads(issue.get("body") or "")
    except json.JSONDecodeError as exc:
        raise BundleError("INVALID_JSON") from exc
    if not isinstance(payload, dict):
        raise BundleError("INVALID_JSON")

    run_id = payload.get("run_id", "")
    if not isinstance(run_id, str) or not RUN_ID.fullmatch(run_id):
        raise BundleError("INVALID_RUN_ID")
    capability = payload.get("capability")
    if not isinstance(capability, str) or not capability:
        raise BundleError("CAPABILITY_REQUIRED")
    mode = payload.get("mode")
    if mode not in {"execute", "diagnose"}:
        raise BundleError("MODE_DENIED")
    return IssueEnvelope(run_id, capability, mode, payload)


def validate_exec_task(
    envelope: IssueEnvelope, *, allowed_capabilities: Iterable[str]
) -> ExecTask:
    if envelope.capability not in set(allowed_capabilities):
        raise BundleError("CAPABILITY_DENIED")
    payload = envelope.payload
    operation = payload.get("operation")
    if operation not in {"read", "write"}:
        raise BundleError("OPERATION_REQUIRED")
    try:
        request = base64.b64decode(payload["request_b64"], validate=True)
    except (KeyError, TypeError, ValueError) as exc:
        raise BundleError("INVALID_REQUEST_B64") from exc
    if hashlib.sha256(request).hexdigest() != payload.get("request_sha256"):
        raise BundleError("REQUEST_HASH_MISMATCH")

    target_repo = payload.get("target_repo")
    if operation == "write":
        if not isinstance(target_repo, str) or not TARGET_REPO.fullmatch(target_repo):
            raise BundleError("TARGET_REPO_REQUIRED")
    elif target_repo is not None:
        raise BundleError("READ_TARGET_REPO_FORBIDDEN")

    return ExecTask(
        envelope.run_id,
        envelope.capability,
        envelope.mode,
        operation,
        target_repo,
        request,
    )


def heartbeat_payload(
    run_id: str,
    state: str,
    *,
    heartbeat_epoch: int,
    elapsed_seconds: float,
    detail: str = "",
) -> dict[str, Any]:
    return {
        "run_id": run_id,
        "state": state,
        "heartbeat_epoch": int(heartbeat_epoch),
        "elapsed_seconds": round(max(0.0, elapsed_seconds), 3),
        "detail": detail,
    }


def format_progress(
    run_id: str,
    state: str,
    *,
    heartbeat_epoch: int,
    elapsed_seconds: float,
    latest_output: str = "",
    detail: str = "",
) -> str:
    detail_part = f" detail={detail}" if detail else ""
    latest = (latest_output or "(no output yet)")[-900:]
    return (
        f"AJINT_PROGRESS run_id={run_id} state={state} heartbeat={int(heartbeat_epoch)} "
        f"elapsed={max(0.0, elapsed_seconds):.1f}s{detail_part}\n\n"
        f"```text\n{latest}\n```"
    )


def format_result(run_id: str, exit_code: int, output: str) -> str:
    return f"AJINT_RESULT run_id={run_id} exit_code={exit_code}\n\n```text\n{output[-3500:]}\n```"


def format_failure(run_id: str, reason: str, output: str = "") -> str:
    suffix = f"\n\n```text\n{output[-3000:]}\n```" if output else ""
    return f"AJINT_FAILED run_id={run_id} reason={reason}{suffix}"


def lock_key_for_repo(target_repo: str) -> str:
    if not TARGET_REPO.fullmatch(target_repo):
        raise BundleError("TARGET_REPO_REQUIRED")
    return target_repo.replace("/", "--") + ".lock"
