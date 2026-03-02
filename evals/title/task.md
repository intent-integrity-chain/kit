# Title

Clarifications should be visible from anywhere in the dashboard, not just the Clarify tab

## Problem/Feature Description

Right now, if someone wants to check the clarification Q&As for a pipeline run, they have to navigate to the "Clarify" tab. But when you're looking at the pipeline view or the board, there's no quick way to see if any clarifications exist or what they say—you have to manually switch tabs.

It would be really useful to have a persistent indicator somewhere on the dashboard that shows when clarifications are available, so users don't miss them while reviewing pipeline status. Ideally, you could see the Q&As without leaving your current view.

## Expected Behavior

- A small button should appear somewhere unobtrusive on the dashboard (e.g., a corner of the screen) whenever there are clarifications for the current pipeline run. It should show the total number of clarifications at a glance.
- Clicking that button should open an overlay or panel showing all the clarification Q&A entries, organized by session, without navigating away from the current view.
- The panel should be dismissible (clicking the button again closes it).
- When users click the clarification count badge on a pipeline phase node, it should also open this panel—instead of switching to the Clarify tab.
- When there are no clarifications, the button should not be shown.

## Acceptance Criteria

- A persistent clarification indicator appears on the dashboard and shows the correct total count of clarifications when data is loaded.
- Clicking the indicator opens a slide-out or overlay panel with all Q&A entries grouped by session; clicking again closes it.
- Clicking the clarify badge on a pipeline phase node opens the same panel rather than switching tabs.
- The indicator is hidden when no clarifications exist for the current pipeline run.
