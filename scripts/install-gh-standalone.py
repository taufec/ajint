#!/usr/bin/env python3
"""Install official GitHub CLI precompiled Linux binary without a package manager."""
from __future__ import annotations

import hashlib
import json
import os
import pathlib
import platform
import shutil
import sys
import tarfile
import tempfile
import urllib.request

API = os.environ.get('AJINT_GH_RELEASE_API', 'https://api.github.com/repos/cli/cli/releases/latest')
INSTALL_DIR = pathlib.Path(os.environ.get('AJINT_GH_INSTALL_DIR', '/usr/local/bin'))


def open_url(url: str):
    req = urllib.request.Request(url, headers={'User-Agent': 'Ajint/gh-bootstrap'})
    return urllib.request.urlopen(req, timeout=45)


def main() -> int:
    machine = platform.machine().lower()
    arch_map = {
        'x86_64': 'amd64', 'amd64': 'amd64',
        'aarch64': 'arm64', 'arm64': 'arm64',
        'i386': '386', 'i686': '386', 'x86': '386',
    }
    arch = arch_map.get(machine)
    if not arch:
        print(f'ERROR: unsupported Linux architecture for standalone gh: {machine}', file=sys.stderr)
        return 2

    with open_url(API) as response:
        release = json.load(response)
    suffix = f'_linux_{arch}.tar.gz'
    assets = [a for a in release.get('assets', []) if a.get('name', '').endswith(suffix)]
    if len(assets) != 1:
        print(f'ERROR: could not uniquely locate official gh asset for linux/{arch}', file=sys.stderr)
        return 3
    asset = assets[0]

    with tempfile.TemporaryDirectory(prefix='ajint-gh-') as td:
        archive = pathlib.Path(td) / asset['name']
        with open_url(asset['browser_download_url']) as response, archive.open('wb') as fh:
            shutil.copyfileobj(response, fh)

        digest = asset.get('digest') or ''
        if digest.startswith('sha256:'):
            actual = hashlib.sha256(archive.read_bytes()).hexdigest()
            expected = digest.split(':', 1)[1]
            if actual != expected:
                print('ERROR: standalone gh SHA-256 verification failed', file=sys.stderr)
                return 4

        with tarfile.open(archive, 'r:gz') as tf:
            members = [m for m in tf.getmembers() if m.isfile() and m.name.endswith('/bin/gh')]
            if len(members) != 1:
                print('ERROR: official gh archive does not contain one bin/gh', file=sys.stderr)
                return 5
            source = tf.extractfile(members[0])
            if source is None:
                print('ERROR: could not read gh from archive', file=sys.stderr)
                return 6
            INSTALL_DIR.mkdir(parents=True, exist_ok=True)
            target = INSTALL_DIR / 'gh'
            tmp_target = INSTALL_DIR / '.gh.ajint.tmp'
            with tmp_target.open('wb') as fh:
                shutil.copyfileobj(source, fh)
            tmp_target.chmod(0o755)
            os.replace(tmp_target, target)

    print(str(INSTALL_DIR / 'gh'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
