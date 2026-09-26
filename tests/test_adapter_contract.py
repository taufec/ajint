import base64
import hashlib
import importlib
import json
import pathlib
import tempfile
import unittest


class AdapterContractTests(unittest.TestCase):
    def issue(self, *, target="s21", request=b"printf ok\n", operation="read"):
        payload = {
            "run_id": "run-adapter-contract-20260926",
            "capability": "android.termux.exec",
            "mode": "diagnose",
            "operation": operation,
            "target_device": target,
            "request_b64": base64.b64encode(request).decode(),
            "request_sha256": hashlib.sha256(request).hexdigest(),
        }
        return {
            "number": 42,
            "title": "AJINT_RUN",
            "user": {"login": "taufec"},
            "body": json.dumps(payload),
        }

    def test_generic_request_validation_leaves_target_policy_to_adapter(self):
        protocol = importlib.import_module("ajint_core.protocol")
        envelope = protocol.validate_issue_envelope(
            self.issue(operation="write"), allowed_authors={"taufec"}
        )
        task = protocol.validate_request_task(
            envelope, allowed_capabilities={"android.termux.exec"}
        )
        self.assertEqual(task.operation, "write")
        self.assertIsNone(task.target_repo)
        self.assertEqual(task.request, b"printf ok\n")

    def adapter(self):
        module = importlib.import_module("ajint_adapters.termux")
        return module.TermuxExecAdapter(
            target_device="s21", allowed_authors={"taufec"}
        )

    def test_termux_adapter_accepts_proven_device_contract(self):
        task = self.adapter().parse_issue(self.issue())
        self.assertEqual(task.issue_number, 42)
        self.assertEqual(task.target, "s21")
        self.assertEqual(task.command, "printf ok\n")
        self.assertEqual(task.operation, "read")

    def test_target_device_is_adapter_owned(self):
        module = importlib.import_module("ajint_adapters.local")
        with self.assertRaisesRegex(module.AdapterError, "TARGET_DEVICE_INVALID"):
            self.adapter().parse_issue(self.issue(target="mimax"))

    def test_utf8_is_adapter_boundary(self):
        module = importlib.import_module("ajint_adapters.local")
        with self.assertRaisesRegex(module.AdapterError, "REQUEST_UTF8_INVALID"):
            self.adapter().parse_issue(self.issue(request=b"\xff"))

    def test_wire_markers_are_delegated_to_common_core(self):
        protocol = importlib.import_module("ajint_core.protocol")
        adapter = self.adapter()
        self.assertEqual(
            adapter.format_rejection("TARGET_DEVICE_INVALID"),
            protocol.format_rejection("TARGET_DEVICE_INVALID"),
        )
        self.assertEqual(
            adapter.format_result("run-adapter-contract-20260926", 0, "ok"),
            protocol.format_result("run-adapter-contract-20260926", 0, "ok"),
        )

    def test_result_store_round_trip(self):
        local = importlib.import_module("ajint_adapters.local")
        with tempfile.TemporaryDirectory() as td:
            store = local.FileResultStore(pathlib.Path(td))
            store.persist(42, "AJINT_RESULT test")
            self.assertTrue(store.exists(42))
            self.assertEqual(store.read(42), "AJINT_RESULT test")
            store.delete(42)
            self.assertFalse(store.exists(42))

    def test_termux_lock_primitive_stays_outside_common_core(self):
        protocol = importlib.import_module("ajint_core.protocol")
        termux = importlib.import_module("ajint_adapters.termux")
        with tempfile.TemporaryDirectory() as td:
            lock = termux.TermuxWriteLock(pathlib.Path(td), "s21")
            self.assertEqual(lock.path.name, "device--s21.write.lock")
            with lock.acquire():
                self.assertTrue(lock.path.exists())

        core_source = pathlib.Path(protocol.__file__).read_text()
        adapter_source = pathlib.Path(termux.__file__).read_text()
        self.assertNotIn("fcntl", core_source)
        self.assertIn("fcntl", adapter_source)

    def test_adapters_do_not_duplicate_hash_or_base64_validation(self):
        local = importlib.import_module("ajint_adapters.local")
        termux = importlib.import_module("ajint_adapters.termux")
        source = pathlib.Path(local.__file__).read_text() + pathlib.Path(termux.__file__).read_text()
        self.assertNotIn("import base64", source)
        self.assertNotIn("import hashlib", source)


if __name__ == "__main__":
    unittest.main()
