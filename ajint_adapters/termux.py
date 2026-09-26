"""Android/Termux adapter primitives.

Termux-specific locking lives here intentionally; ``ajint_core`` remains free
of OS lock/service assumptions.
"""

from __future__ import annotations

from contextlib import contextmanager
from pathlib import Path
from typing import Iterable, Iterator, TextIO

from .local import LocalExecAdapter


class TermuxExecAdapter(LocalExecAdapter):
    def __init__(self, *, target_device: str, allowed_authors: Iterable[str]) -> None:
        super().__init__(
            capability="android.termux.exec",
            target_field="target_device",
            target=target_device,
            target_error="TARGET_DEVICE_INVALID",
            allowed_authors=allowed_authors,
        )


class TermuxWriteLock:
    def __init__(self, root: Path, target_device: str) -> None:
        safe_target = target_device.replace("/", "--")
        self.path = Path(root) / "locks" / f"device--{safe_target}.write.lock"

    @contextmanager
    def acquire(self) -> Iterator[None]:
        import fcntl

        self.path.parent.mkdir(parents=True, exist_ok=True)
        handle: TextIO = self.path.open("w")
        try:
            fcntl.flock(handle, fcntl.LOCK_EX)
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)
            handle.close()
