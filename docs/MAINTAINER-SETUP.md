# Maintainer Repository Setup

Some release-safety controls live in GitHub repository settings rather than source code. They must be configured separately from the Ajint codebase.

## Recommended `main` protection

For the public Ajint core repository:

- require changes through pull requests;
- require the `Tests / shell-tests` check before merge;
- require conversations to be resolved before merge;
- block force pushes to `main`;
- block deletion of `main`;
- keep administrator bypass exceptional and auditable;
- for a solo-maintainer phase, a mandatory second human approval is optional, but CI should still be mandatory.

A branch showing as "protected" is not sufficient by itself. Verify that the required status check is actually configured and enforced.

## Release tags

Create release tags only from a verified `main` commit after CI and the real E2E release gate pass. Do not move published version tags to a different commit.

## GitHub Actions

Keep workflow permissions at minimum required scope. Pin third-party actions to reviewed immutable commit SHAs where practical. Review any change that broadens `permissions:` or introduces new secret exposure paths.

## Public/private split

The Ajint core repository may be public. Per-machine control repositories must remain private because they contain executable requests, machine-specific configuration and the workflow control surface.
