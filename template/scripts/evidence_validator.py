#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 2:
        print("usage: evidence_validator.py evidence.json", file=sys.stderr)
        return 64

    evidence = json.loads(Path(sys.argv[1]).read_text())
    required = ("request_commit", "route", "workflow", "run_id", "exit_code", "result_present")
    missing = [k for k in required if k not in evidence or evidence[k] in (None, "")]

    if missing or evidence.get("result_present") is not True:
        print("VERDICT=UNCONFIRMED missing=" + ",".join(missing or ["result_present"]))
        return 0

    try:
        rc = int(evidence["exit_code"])
    except Exception:
        print("VERDICT=UNCONFIRMED missing=valid_exit_code")
        return 0

    print("VERDICT=PASS" if rc == 0 else "VERDICT=FAIL")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
