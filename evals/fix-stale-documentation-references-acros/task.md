# Fix Stale Documentation References Across IIKit

## Problem/Feature Description

Our documentation is currently out of sync with the actual implementation. Several key changes have been shipped to IIKit—most significantly the testify skill now outputs Gherkin `.feature` files instead of the old `test-specs.md` file—but none of the documentation has been updated to reflect this. Anyone reading our docs right now gets incorrect information about where test specifications live, what commands to run, and how the workflow stages are named.

On top of the testify output format change, the phase numbering and skill names are inconsistent. Some docs still call commands `/iikit-plan` and `/iikit-tasks` (the old names), the framework principles document lists `clarify` and `bugfix` as numbered pipeline phases when they're actually utilities, and the `testified` stage that now exists in the state machine isn't documented in the API reference at all.

## Expected Behavior

After this fix, all documentation should accurately describe the current system:

- References to `tests/test-specs.md` should be updated to `tests/features/*.feature` (the actual output of the testify skill)
- A new `testified` feature stage (the state between `planned` and `tasks-ready` when `.feature` files exist but no `tasks.md` yet) should be documented in the API reference stage table
- `FRAMEWORK-PRINCIPLES.md` should clearly distinguish utilities (clarify, bugfix, core) from numbered pipeline phases, with accurate skill command names (e.g. `/iikit-02-plan`, `/iikit-07-implement`)
- Phase and section numbers in cross-referenced docs should match the actual skill numbers
- Old command names like `/iikit-plan` and `/iikit-tasks` should be updated to their current equivalents
- The `clarify` skill documentation should drop the mention of a 5-question cap per run, since that restriction was removed

## Acceptance Criteria

- `tests/test-specs.md` is no longer referenced anywhere in the documentation; all references point to `tests/features/*.feature` files
- The API reference includes a Feature Stages table that covers all stages from `specified` through `complete`, including the new `testified` stage
- `FRAMEWORK-PRINCIPLES.md` separates utilities from numbered phases and uses current skill command names
- The `tile.json` version and `README.md` "What's New" heading are updated to reflect the new release
