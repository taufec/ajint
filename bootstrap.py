#!/usr/bin/env python3
"""Dependency-light bootstrap for Ajint when curl is unavailable."""
import os
import subprocess
import tempfile
import urllib.request

ref = os.environ.get("AJINT_REF", "main")
url = f"https://raw.githubusercontent.com/taufec/ajint/{ref}/install.sh"

fd, path = tempfile.mkstemp(prefix="ajint-install-", suffix=".sh")
os.close(fd)
try:
    with urllib.request.urlopen(url, timeout=30) as response, open(path, "wb") as fh:
        fh.write(response.read())
    os.chmod(path, 0o700)
    raise SystemExit(subprocess.call(["bash", path], env=os.environ.copy()))
finally:
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
