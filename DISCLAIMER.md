# Ajint Operational Disclaimer

Ajint is privileged remote-execution software. It can cause real changes on a connected machine because approved requests are executed through SSH as the configured operating-system user.

Ajint is provided under the MIT License on an **AS IS** basis, without warranties. The MIT License contains the project's license-level warranty and liability disclaimer. This document adds operational context for users; it does not replace the license and is not legal advice.

## Risks you must understand

Commands executed through Ajint may, depending on the permissions of the configured SSH user:

- delete or overwrite files;
- stop services or make a system unavailable;
- change network, firewall, package or operating-system configuration;
- expose secrets through command output or artifacts;
- incur infrastructure, bandwidth, cloud or third-party costs;
- cause data loss or other operational damage.

## Before using Ajint

Use backups and recovery procedures appropriate to the machine. Prefer least-privilege accounts instead of `root` when practical. Test high-impact commands in a disposable or non-production environment first. Review AI-generated commands before execution when the impact is material.

Ajint's routing and evidence controls reduce specific classes of mistakes; they do **not** turn arbitrary shell execution into a sandbox and do not guarantee that a permitted command is safe.

Third-party services used by Ajint, including GitHub, GitHub Actions, hosting providers and network services, have their own terms, limits, availability and security properties.
