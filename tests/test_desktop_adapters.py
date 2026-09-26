import base64
import hashlib
import importlib
import json
import pathlib
import sys
import tempfile
import unittest


class DesktopAdapterContractTests(unittest.TestCase):
    def issue(self, capability, *, target="devbox", request=b"echo ok\n", operation="read", **extra):
        payload = {
            "run_id": "run-desktop-contract-20260926",
            "capability": capability,
            "mode": "diagnose",
            "operation": operation,
            "target_device": target,
            "request_b64": base64.b64encode(request).decode(),
            "request_sha256": hashlib.sha256(request).hexdigest(),
        }
        payload.update(extra)
        return {
            "number": 77,
            "title": "AJINT_RUN",
            "user": {"login": "taufec"},
            "body": json.dumps(payload),
        }

    def test_macos_adapter_uses_common_request_contract(self):
        module = importlib.import_module("ajint_adapters.macos")
        adapter = module.MacOSExecAdapter(target_device="devbox", allowed_authors={"taufec"})
        task = adapter.parse_issue(self.issue("macos.exec"))
        self.assertEqual(task.target, "devbox")
        self.assertEqual(task.command, "echo ok\n")
        self.assertEqual(task.operation, "read")

    def test_windows_adapter_uses_common_request_contract(self):
        module = importlib.import_module("ajint_adapters.windows")
        adapter = module.WindowsExecAdapter(target_device="devbox", allowed_authors={"taufec"})
        task = adapter.parse_issue(self.issue("windows.exec"))
        self.assertEqual(task.target, "devbox")
        self.assertEqual(task.command, "echo ok\n")
        self.assertEqual(task.operation, "read")

    def test_desktop_adapters_reject_ambiguous_repository_target(self):
        local = importlib.import_module("ajint_adapters.local")
        for module_name, cls_name, capability in (
            ("ajint_adapters.macos", "MacOSExecAdapter", "macos.exec"),
            ("ajint_adapters.windows", "WindowsExecAdapter", "windows.exec"),
        ):
            with self.subTest(module=module_name):
                module = importlib.import_module(module_name)
                adapter = getattr(module, cls_name)(target_device="devbox", allowed_authors={"taufec"})
                with self.assertRaisesRegex(local.AdapterError, "TARGET_REPO_FORBIDDEN"):
                    adapter.parse_issue(self.issue(capability, target_repo="taufec/ajint"))

    def test_desktop_adapters_reject_unsafe_configured_targets(self):
        for module_name, cls_name in (
            ("ajint_adapters.macos", "MacOSExecAdapter"),
            ("ajint_adapters.windows", "WindowsExecAdapter"),
        ):
            with self.subTest(module=module_name):
                module = importlib.import_module(module_name)
                with self.assertRaisesRegex(ValueError, "TARGET_DEVICE_INVALID"):
                    getattr(module, cls_name)(target_device="../escape", allowed_authors={"taufec"})

    @unittest.skipUnless(sys.platform == "darwin", "native macOS evidence only")
    def test_macos_executor_and_lock_on_native_runner(self):
        module = importlib.import_module("ajint_adapters.macos")
        outcome = module.MacOSShellExecutor(timeout_seconds=5)(
            "printf ok; printf err >&2; exit 3"
        )
        self.assertEqual(outcome.exit_code, 3)
        self.assertEqual(outcome.stdout, "ok")
        self.assertEqual(outcome.stderr, "err")
        with tempfile.TemporaryDirectory() as td:
            lock = module.MacOSWriteLock(pathlib.Path(td), "devbox")
            with lock.acquire():
                self.assertTrue(lock.path.exists())

    @unittest.skipUnless(sys.platform == "win32", "native Windows evidence only")
    def test_windows_executor_and_lock_on_native_runner(self):
        module = importlib.import_module("ajint_adapters.windows")
        outcome = module.WindowsPowerShellExecutor(timeout_seconds=5)(
            "[Console]::Out.Write('ok'); [Console]::Error.Write('err'); exit 3"
        )
        self.assertEqual(outcome.exit_code, 3)
        self.assertEqual(outcome.stdout, "ok")
        self.assertEqual(outcome.stderr, "err")
        with tempfile.TemporaryDirectory() as td:
            lock = module.WindowsWriteLock(pathlib.Path(td), "devbox")
            with lock.acquire():
                self.assertTrue(lock.path.exists())

    def test_os_primitives_remain_outside_common_core(self):
        protocol = importlib.import_module("ajint_core.protocol")
        core = pathlib.Path(protocol.__file__).read_text()
        for forbidden in ("fcntl", "msvcrt", "subprocess", "powershell.exe", "/bin/zsh"):
            self.assertNotIn(forbidden, core)


if __name__ == "__main__":
    unittest.main()
