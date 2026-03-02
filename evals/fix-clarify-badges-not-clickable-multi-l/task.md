# Fix: Clarify Badges Not Clickable + Multi-line Q&A Entries Not Parsed

## Problem/Feature Description

In the IIKit dashboard, each pipeline phase node can display a "clarify" badge (e.g., `?5`) showing how many clarification questions have been filed for that phase. These badges appear on the pipeline bar, but clicking them currently does nothing — they're purely decorative. Users expect that clicking a clarify badge would take them directly to the Clarify view panel so they can review the questions and answers, the same way other pipeline elements navigate to relevant panels.

Additionally, when agents generate clarification Q&A entries in spec files, they sometimes wrap long question text across multiple lines, with the `-> A:` answer appearing on a continuation line rather than the same line as `Q:`. The current parser only handles the case where the question and answer are on a single line (`- Q: question text -> A: answer`). Multi-line entries are being silently dropped, so clarifications written by agents in a natural wrapping style don't appear in the dashboard at all.

## Expected Behavior

- Clicking a clarify badge on a pipeline phase node should navigate the user to the Clarify view panel (the same panel reachable via the main tab navigation).
- The click should be independent of the phase node itself — clicking the badge should NOT also trigger the phase node's own click behavior (switching to that phase's tab).
- The `parseClarifications` function should handle clarification entries where the question text spans multiple lines, with `-> A:` appearing on a later continuation line. These multi-line entries should be parsed correctly and appear in the dashboard just like single-line entries.

## Acceptance Criteria

- Clarify badge elements on pipeline nodes respond to clicks and navigate to the clarify view.
- Clicking a clarify badge does not simultaneously switch to the pipeline node's associated phase tab.
- Multi-line clarification entries (where the question wraps and `-> A:` appears on the next line) are correctly parsed and displayed in the clarify panel.
- Reference tags (e.g., `[FR-001, US-002]`) on multi-line answer entries are extracted correctly, same as for single-line entries.
