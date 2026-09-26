# Regression Reference

This directory documents regression expectations for the public stable line.

Current baseline:

- release: `0.1.0-alpha.1`;
- transport: GitHub Actions -> SSH;
- supported Linux targets and release gates remain those documented by the existing project tests and compatibility docs.

Downstream/private historical-task audits are useful evidence, but they are not automatically tests of this public release. A future public runtime migration should promote relevant compatibility cases into executable public-core regression tests as part of that release.
