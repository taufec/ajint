import base64
import hashlib
import importlib
import json
import pathlib
import unittest


class CoreProtocolTests(unittest.TestCase):
    def protocol(self):
        try:
            return importlib.import_module("ajint_core.protocol")
        except ModuleNotFoundError as exc:
            self.fail(f"missing common core module: {exc}")

    def issue(self, request=b"echo ok\n", **extra):
        body = {
            "run_id": "run-core-contract-20260926a",
            "capability": "vps.exec",
            "mode": "diagnose",
            "operation": "read",
            "request_b64": base64.b64encode(request).decode(),
            "request_sha256": hashlib.sha256(request).hexdigest(),
        }
        body.update(extra)
        return {"number": 1, "user": {"login": "taufec"}, "body": json.dumps(body)}

    def test_protocol_version_boundary(self):
        protocol = self.protocol()
        self.assertEqual(protocol.PROTOCOL_VERSION, "issue-runner.v1")

    def test_proven_read_contract_is_accepted(self):
        protocol = self.protocol()
        envelope = protocol.validate_issue_envelope(self.issue(), allowed_authors={"taufec"})
        task = protocol.validate_exec_task(envelope, allowed_capabilities={"vps.exec"})
        self.assertEqual(task.run_id, "run-core-contract-20260926a")
        self.assertEqual(task.operation, "read")
        self.assertIsNone(task.target_repo)
        self.assertEqual(task.request, b"echo ok\n")

    def test_write_requires_target_repo(self):
        protocol = self.protocol()
        envelope = protocol.validate_issue_envelope(
            self.issue(operation="write"), allowed_authors={"taufec"}
        )
        with self.assertRaisesRegex(protocol.BundleError, "TARGET_REPO_REQUIRED"):
            protocol.validate_exec_task(envelope, allowed_capabilities={"vps.exec"})

    def test_request_hash_mismatch_is_rejected(self):
        protocol = self.protocol()
        envelope = protocol.validate_issue_envelope(
            self.issue(request_sha256="0" * 64), allowed_authors={"taufec"}
        )
        with self.assertRaisesRegex(protocol.BundleError, "REQUEST_HASH_MISMATCH"):
            protocol.validate_exec_task(envelope, allowed_capabilities={"vps.exec"})

    def test_progress_and_heartbeat_match_downstream_semantics(self):
        protocol = self.protocol()
        heartbeat = protocol.heartbeat_payload(
            "run-core-contract-20260926a",
            "RUNNING",
            heartbeat_epoch=1790430000,
            elapsed_seconds=2.5,
            detail="accepted",
        )
        self.assertEqual(
            heartbeat,
            {
                "run_id": "run-core-contract-20260926a",
                "state": "RUNNING",
                "heartbeat_epoch": 1790430000,
                "elapsed_seconds": 2.5,
                "detail": "accepted",
            },
        )
        rendered = protocol.format_progress(
            "run-core-contract-20260926a",
            "RUNNING",
            heartbeat_epoch=1790430000,
            elapsed_seconds=2.5,
            latest_output="phase-one",
            detail="accepted",
        )
        self.assertIn(
            "AJINT_PROGRESS run_id=run-core-contract-20260926a state=RUNNING",
            rendered,
        )
        self.assertIn(
            "heartbeat=1790430000 elapsed=2.5s detail=accepted",
            rendered,
        )
        self.assertIn("phase-one", rendered)

    def test_terminal_markers_match_downstream_semantics(self):
        protocol = self.protocol()
        result = protocol.format_result(
            "run-core-contract-20260926a", 0, "ok\n=== STDERR ===\n"
        )
        self.assertTrue(
            result.startswith(
                "AJINT_RESULT run_id=run-core-contract-20260926a exit_code=0"
            )
        )
        failure = protocol.format_failure(
            "run-core-contract-20260926a", "TASK_TIMEOUT", "partial"
        )
        self.assertTrue(
            failure.startswith(
                "AJINT_FAILED run_id=run-core-contract-20260926a reason=TASK_TIMEOUT"
            )
        )

    def test_lock_key_is_repo_specific_and_platform_neutral(self):
        protocol = self.protocol()
        self.assertEqual(
            protocol.lock_key_for_repo("taufec/chat-ledger"),
            "taufec--chat-ledger.lock",
        )
        self.assertNotEqual(
            protocol.lock_key_for_repo("taufec/chat-ledger"),
            protocol.lock_key_for_repo("taufec/ajint-machine-admin"),
        )

        source = pathlib.Path(protocol.__file__).read_text()
        for forbidden in ("fcntl", "systemctl", "/var/lib/", "/usr/local/"):
            self.assertNotIn(forbidden, source)


    def test_run_issue_candidate_filter_matches_downstream(self):
        protocol = self.protocol()
        self.assertTrue(protocol.is_run_issue_candidate({"title": "AJINT_RUN"}))
        self.assertFalse(protocol.is_run_issue_candidate({"title": "OTHER"}))
        self.assertFalse(
            protocol.is_run_issue_candidate(
                {"title": "AJINT_RUN", "pull_request": {"url": "https://example.invalid"}}
            )
        )

    def test_rejection_marker_matches_downstream(self):
        protocol = self.protocol()
        self.assertEqual(
            protocol.format_rejection("REQUEST_HASH_MISMATCH"),
            "AJINT_REJECTED reason=REQUEST_HASH_MISMATCH",
        )


if __name__ == "__main__":
    unittest.main()
