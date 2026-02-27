# IIKit Dashboard

**Watch your AI agent develop features in real time.**

The IIKit dashboard is a static HTML file generated from your project's specification artifacts. It visualizes every phase of the IIKit workflow with live updates as artifacts change on disk.

> **History**: The dashboard was originally a standalone package ([iikit-dashboard](https://github.com/intent-integrity-chain/iikit-dashboard)). As of v2.0.0 it generates a static HTML file instead of running a server, and the generator has been folded into IIKit core. The standalone repo is archived.

## Usage

The dashboard launches automatically early in the IIKit workflow — no manual setup needed.

You can also generate it standalone:

```bash
node src/generate-dashboard.js /path/to/project
```

The output is a single `.specify/dashboard.html` file. Open it in any browser.

## Views

The pipeline bar at the top shows all nine IIKit workflow phases. Click any phase to see its visualization:

| Phase | View |
|-------|------|
| **Constitution** | Radar chart of governance principles with obligation levels (MUST / SHOULD / MAY) and version timeline |
| **Spec** | Story map with swim lanes by priority + interactive force-directed requirements graph (US / FR / SC nodes and edges) with detail side-panel |
| ~~Clarify~~ | _Not a pipeline phase node._ Clarify is a utility — its output surfaces as amber `?N` badges on the pipeline nodes of the artifacts that have open questions. `N` counts `- Q:` items (not session headings). Clicking a badge opens the FAB panel (see below). |
| **Plan** | Tech context key-value pairs, interactive file-structure tree (existing vs. planned files), rendered architecture diagram, and Tessl tile cards with live eval scores |
| **Checklist** | Progress rings per checklist file with color coding (red/yellow/green), gate traffic light (OPEN/BLOCKED), and accordion detail view with CHK IDs and tag badges |
| **Testify** | Assertion integrity seal (Verified/Tampered/Missing), Sankey traceability diagram (Requirements → Test Specs → Tasks), test pyramid, and gap highlighting for untested requirements |
| **Tasks** | Redirects to the Implement board (tasks are managed there) |
| **Analyze** | Health gauge (0-100) with four weighted factors, coverage heatmap (Tasks/Tests/Plan per requirement), and sortable/filterable severity table of analysis findings |
| **Implement** | Kanban board with cards sliding Todo → In Progress → Done as the agent checks off tasks, with collapsible per-story task lists |

## Features

- **Live updates** — all views refresh in real time via file watcher as project files change
- **Pipeline navigation** — phase nodes show status (complete / in-progress / skipped / not started) with progress percentages. Nodes with open clarification questions display an amber `?N` badge (where `N` counts `- Q:` items, not session headings); clicking the badge opens the FAB panel.
- **Clarify FAB button** — a floating action button in the bottom-right corner showing `?N` (total open `- Q:` items across all artifacts). Clicking it opens a slide-out panel listing Q&A entries grouped by clarification session, with clickable spec-item references that navigate to the corresponding view.
- **Cross-panel navigation** — Cmd/Ctrl+click any FR, US, SC, or task identifier to jump to its linked panel
- **Feature selector** — dropdown to switch between features in `specs/`, sorted by last-active mtime (file modification time of artifacts)
- **Project label** — header shows the project directory name with full path on hover
- **Integrity badges** — shows whether test assertions have been tampered with (verified / tampered / missing)
- **Tessl eval scores** — Plan view tile cards display live eval data when available
- **Activity indicator** — green dot pulses in the header when files are actively changing
- **Three-state theme** — cycles System (OS preference) → Light → Dark
- **Zero build step** — single HTML file with inline CSS and JS

## Artifact Sources

| File | Purpose |
|------|---------|
| `CONSTITUTION.md` | Governance principles and obligation levels |
| `specs/<feature>/spec.md` | User stories, requirements, success criteria, and clarification Q&A |
| `specs/<feature>/plan.md` | Tech stack, file structure, and architecture diagram |
| `specs/<feature>/research.md` | Research decisions (displayed as tooltips in Plan view) |
| `specs/<feature>/tasks.md` | Task checkboxes grouped by `[US1]`, `[US2]` tags |
| `specs/<feature>/checklists/*.md` | Checklist items with completion status, CHK IDs, and category groupings |
| `specs/<feature>/tests/features/*.feature` | Gherkin test specifications for the Testify traceability view |
| `specs/<feature>/context.json` | Assertion hash for integrity verification |
| `specs/<feature>/analysis.md` | Consistency analysis findings, coverage, and metrics |
| `tessl.json` | Installed Tessl tiles for the Plan dependency panel |
