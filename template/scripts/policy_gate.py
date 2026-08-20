#!/usr/bin/env python3
import argparse, hashlib, json
from pathlib import Path


def die(code, msg):
    print(f"POLICY_GATE=DENY reason={msg}")
    raise SystemExit(code)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--lane", required=True)
    ap.add_argument("--request", required=True)
    ap.add_argument("--routes", required=True)
    ap.add_argument("--known-good", required=True)
    ap.add_argument("--changed-files")
    a = ap.parse_args()

    manifest = json.loads(Path(a.manifest).read_text())
    cfg = json.loads(Path(a.routes).read_text())
    known = json.loads(Path(a.known_good).read_text()) if Path(a.known_good).exists() else {}
    routes = cfg.get("routes", {})
    capability = manifest.get("capability")
    mode = manifest.get("mode")

    if capability not in routes:
        die(65, "UNKNOWN_CAPABILITY")

    route = routes[capability]
    expected = route.get("lane")
    if a.lane != expected:
        die(66, f"ROUTE_MISMATCH expected={expected} got={a.lane}")

    req = Path(a.request)
    actual_hash = hashlib.sha256(req.read_bytes()).hexdigest()
    if manifest.get("request_sha256") != actual_hash:
        die(67, "REQUEST_HASH_MISMATCH")

    payload = req.read_text(errors="replace").lower()
    for cap, rcfg in routes.items():
        if cap == capability:
            continue
        if rcfg.get("priority", 0) <= route.get("priority", 0):
            continue
        for marker in rcfg.get("specific_markers", []):
            if marker.lower() in payload:
                die(68, f"SPECIFIC_ROUTE_MARKER capability={cap} marker={marker}")

    if mode == "diagnose" and a.changed_files:
        changed = [x.strip() for x in Path(a.changed_files).read_text().splitlines() if x.strip()]
        protected = cfg.get("protected_during_diagnosis", [])
        bad = [p for p in changed if any(p == pref or p.startswith(pref) for pref in protected)]
        if bad:
            die(69, "ARCHITECTURE_MUTATION_DURING_DIAGNOSIS files=" + ",".join(bad))

    kg = known.get(capability)
    kg_note = (
        f" last_known_pass={kg.get('last_pass_run')}"
        if isinstance(kg, dict) and kg.get("verified")
        else ""
    )
    print(f"POLICY_GATE=PASS capability={capability} lane={a.lane}{kg_note}")


if __name__ == "__main__":
    main()
