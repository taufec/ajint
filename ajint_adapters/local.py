"""Platform-neutral local-runner adapter plumbing built on ``ajint_core``."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping, Any

from ajint_core import protocol


class AdapterError(ValueError):
    pass


CORE_REASON_MAP = {
    "AUTHOR_DENIED": "AUTHOR_NOT_ALLOWED",
    "INVALID_RUN_ID": "RUN_ID_INVALID",
    "CAPABILITY_DENIED": "CAPABILITY_NOT_ALLOWED",
    "MODE_DENIED": "MODE_INVALID",
    "INVALID_REQUEST_B64": "REQUEST_B64_INVALID",
    "REQUEST_HASH_MISMATCH": "REQUEST_SHA256_MISMATCH",
}


@dataclass(frozen=True)
class AdapterTask:
    issue_number: int
    run_id: str
    capability: str
    mode: str
    operation: str
    target: str
    command: str


def _adapter_reason(exc: protocol.BundleError) -> str:
    reason = str(exc)
    return CORE_REASON_MAP.get(reason, reason)


class LocalExecAdapter:
    """Validate local execution tasks while leaving OS execution outside core."""

    def __init__(
        self,
        *,
        capability: str,
        target_field: str,
        target: str,
        target_error: str,
        allowed_authors: Iterable[str],
    ) -> None:
        self.capability = capability
        self.target_field = target_field
        self.target = target
        self.target_error = target_error
        self.allowed_authors = frozenset(allowed_authors)

    def parse_issue(self, issue: Mapping[str, Any]) -> AdapterTask:
        if not protocol.is_run_issue_candidate(issue):
            raise AdapterError("NOT_RUN_ISSUE")
        try:
            envelope = protocol.validate_issue_envelope(
                issue, allowed_authors=self.allowed_authors
            )
            request = protocol.validate_request_task(
                envelope, allowed_capabilities={self.capability}
            )
        except protocol.BundleError as exc:
            raise AdapterError(_adapter_reason(exc)) from exc

        target = envelope.payload.get(self.target_field)
        if target != self.target:
            raise AdapterError(self.target_error)
        try:
            command = request.request.decode("utf-8", "strict")
        except UnicodeDecodeError as exc:
            raise AdapterError("REQUEST_UTF8_INVALID") from exc

        number = issue.get("number")
        if not isinstance(number, int):
            raise AdapterError("ISSUE_NUMBER_INVALID")
        return AdapterTask(
            number,
            request.run_id,
            request.capability,
            request.mode,
            request.operation,
            target,
            command,
        )

    @staticmethod
    def format_rejection(reason: str) -> str:
        return protocol.format_rejection(reason)

    @staticmethod
    def format_result(run_id: str, exit_code: int, output: str) -> str:
        return protocol.format_result(run_id, exit_code, output)

    @staticmethod
    def format_failure(run_id: str, reason: str, output: str = "") -> str:
        return protocol.format_failure(run_id, reason, output)


class FileResultStore:
    """Durable finished-result store used before publication to GitHub."""

    def __init__(self, root: Path) -> None:
        self.root = Path(root)
        self.results = self.root / "results"

    def path_for(self, issue_number: int) -> Path:
        return self.results / f"{issue_number}.txt"

    def persist(self, issue_number: int, text: str) -> None:
        self.results.mkdir(parents=True, exist_ok=True)
        path = self.path_for(issue_number)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(text)
        tmp.replace(path)

    def exists(self, issue_number: int) -> bool:
        return self.path_for(issue_number).exists()

    def read(self, issue_number: int) -> str:
        return self.path_for(issue_number).read_text()

    def delete(self, issue_number: int) -> None:
        self.path_for(issue_number).unlink(missing_ok=True)
