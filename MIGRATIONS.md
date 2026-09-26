# Migrations

## Current release

There is no runtime migration in this documentation baseline. Public Ajint remains `0.1.0-alpha.1`.

## Future release policy

When a downstream architecture is promoted into public Ajint:

1. identify the exact protocol/runtime boundary that changes;
2. document backward compatibility and intentionally retired behavior;
3. provide migration steps for affected users/tasks only;
4. run regression and compatibility checks;
5. publish an explicit version/release.

Working historical tasks should not be rewritten merely because an experimental downstream implementation is newer.
