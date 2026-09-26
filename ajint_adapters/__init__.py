"""OS/device adapter layer for Ajint local Issue Runners."""

from .local import (
    AdapterError,
    AdapterTask,
    CommandOutcome,
    FileResultStore,
    LocalExecAdapter,
    LocalTaskRuntime,
    PreparedResult,
)
from .termux import TermuxExecAdapter, TermuxWriteLock

__all__ = [
    "AdapterError",
    "AdapterTask",
    "CommandOutcome",
    "FileResultStore",
    "LocalExecAdapter",
    "LocalTaskRuntime",
    "PreparedResult",
    "TermuxExecAdapter",
    "TermuxWriteLock",
]
