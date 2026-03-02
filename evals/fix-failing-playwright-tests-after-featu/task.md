# Fix Failing Playwright Tests After Feature Sort Order Change

## Problem Description

Our Playwright test suite is currently failing after a recent change (BUG-10) that modified how `listFeatures()` orders features in the dashboard. Previously, features were listed in reverse-alphabetical order (so `002-payments` appeared first, then `001-auth`). After BUG-10, features are now sorted by last-active modification time (most recently touched first).

This is a problem because many of our dashboard tests rely on selecting a specific feature by its dropdown index to run assertions against rich fixture data (the `001-auth` feature has the full set of stories, clarification sessions, checklist items, etc.). With the old alphabetical ordering, `001-auth` was reliably at index 1. With the new mtime-based ordering, the position depends on which feature was most recently modified—which is not deterministic across test environments.

The tests are consistently failing because they assume `001-auth` is at index 1 in the feature selector dropdown, but it's no longer guaranteed to be there.

## Expected Behavior

The Playwright test suite should pass reliably regardless of environment. Tests that need to operate on the rich `001-auth` fixture should be able to select it consistently. The fix should ensure:

- The test fixture setup produces a deterministic feature ordering that matches the new mtime-based sort in `listFeatures()`
- All test cases that select features by index use the correct index for the current ordering
- Visual snapshot tests that involve nondeterministic UI elements (like force-directed graphs) should have an appropriate tolerance for pixel-level differences

## Acceptance Criteria

- All 94 Playwright tests pass consistently
- Tests that select the `001-auth` feature (rich fixture with full story data, clarification sessions, etc.) do so with the correct index under mtime-sorted ordering
- The `002-payments` feature (minimal fixture) is reliably at the expected index
- Story map screenshot comparisons do not fail due to minor layout variations from the force-directed graph rendering
