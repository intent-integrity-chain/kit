# Fix Post-Publish Verification Tests After v2.6.0 Routing Refactor

## Problem/Feature Description

Since v2.6.0, all workflow step routing for the intent-integrity-kit tile was centralized into a single `next-step.sh` script. Before this change, each SKILL.md file's "Next Steps" section would hardcode specific references like "REQUIRED by constitution: run testify" or explicitly list `iikit-04-testify` and `iikit-06-analyze` as next steps. After the refactor, SKILL.md files simply say "run next-step.sh" and let the script decide what comes next based on project state.

The post-publish verification tests in `tests/run-tile-tests.sh` are now failing in CI because they still check for the old hardcoded patterns that no longer exist in the SKILL.md files. The tests need to be updated to verify the new delegation pattern.

## Expected Behavior

The post-publish verification tests should be updated to validate the new architecture:

- Tests that previously checked for hardcoded `testify` or `analyze` references in SKILL.md files should instead verify that those SKILL.md files delegate to `next-step.sh` in their "Next Steps" section.
- The TDD routing logic (i.e., the rule that testify is required or optional based on project config) should be verified by checking that `next-step.sh` itself contains the testify routing logic — not by checking SKILL.md directly.
- The test for Tasks skill (`iikit-05-tasks`) that checked whether it hardcoded an analyze reference should instead verify it delegates to `next-step.sh`.

## Acceptance Criteria

- `test_tdd_conditional_next_steps` passes with updated assertions that match the v2.6.0 delegation pattern
- Plan and checklist SKILL.md checks verify delegation to `next-step.sh` (not hardcoded step mentions)
- The testify routing assertion checks `next-step.sh` for the routing logic instead of SKILL.md
- `test_skill_numbering_consistency` passes with updated Tasks skill check that verifies `next-step.sh` delegation
