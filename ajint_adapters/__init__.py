"""OS/device adapter layer for Ajint local Issue Runners."""

from .local import AdapterError, AdapterTask, FileResultStore, LocalExecAdapter
from .termux import TermuxExecAdapter, TermuxWriteLock

__all__ = [
    "AdapterError",
    "AdapterTask",
    "FileResultStore",
    "LocalExecAdapter",
    "TermuxExecAdapter",
    "TermuxWriteLock",
]
