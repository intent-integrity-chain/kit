# PRD Seeding Reference

Detailed procedure for Step 6 of `/iikit-core init` — seeding a project backlog from an existing PRD/SDD document.

## Input Resolution

- If `prd_source` was set from the init argument, use that.
- If no argument was provided, ask the user: "Start from scratch or seed from an existing requirements document?"
  - **A) From scratch** — Skip to final report.
  - **B) From existing document** — Ask the user for a file path or URL.

## Read Document

Read the file (local path via `Read` tool) or fetch the URL (via `WebFetch` tool). Support common formats: Markdown, plain text, PDF, HTML.

## Draft PREMISE.md

Before extracting features, synthesize the document into a `PREMISE.md` at the project root:
- **What**: one-paragraph description of the application/system
- **Who**: target users/personas
- **Why**: the problem being solved and the value proposition
- **Domain**: the business/technical domain and key terminology
- **High-level scope**: major system boundaries and components

Write the draft to `PREMISE.md`. Note to the user that `/iikit-00-constitution` will review and finalize it.

## Extract and Order Features

Parse the document and extract distinct features/epics. For each feature, extract:
- A short title (imperative, max 80 chars)
- A 1-3 sentence description
- Priority if mentioned (P1/P2/P3), default P2

Order in logical implementation sequence: foundational/core first (data models, auth, shared services), then backend, then frontend, then integration/polish. Dependency-providing features come earlier.

## Present for Reordering

Show the ordered features as a numbered table with columns: #, Title, Description, Priority, Rationale. Ask the user to confirm the order, reorder, remove, or add features. Wait for explicit confirmation before proceeding.

## Create Labels and Issues

Follow the commands and body template in [prd-issue-template.md](../templates/prd-issue-template.md). Create labels first (idempotent), then one issue per confirmed feature in the confirmed order. Use `gh` if available, otherwise `curl` the GitHub API.

## Final Report

List all created issues with their numbers and titles. Suggest `/iikit-00-constitution` as the next step, then `/iikit-01-specify #<issue-number>` to start specifying individual features.
