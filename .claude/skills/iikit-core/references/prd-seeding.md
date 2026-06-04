# PRD Seeding Reference

Detailed procedure for Step 6 of `/iikit-core init` — seeding a project backlog from an existing PRD/SDD document.

## Security and consent model

This procedure intentionally reads user-supplied content (a local file path OR a URL) and uses the content to generate downstream artifacts (`PREMISE.md`, GitHub issues). That is the feature's purpose.

- **Explicit opt-in.** This sub-action only runs when the user passes a path/URL as an `/iikit-core init` argument, or affirmatively answers "from existing document" at the interactive prompt. The agent never autonomously decides to fetch external content.
- **Trust the source as much as you trust the URL.** Anything in the fetched document influences the PREMISE and issue text the agent drafts. Treat the fetched content the same way you'd treat any document you opened in your editor: review it before accepting the generated artifacts.
- **Generated artifacts are reviewed before commit.** PREMISE.md is shown to the user; `/iikit-00-constitution` is the human-in-the-loop gate before anything binds; GitHub issues are explicit user confirmation per-issue.
- **No code execution from fetched content.** The agent reads document text only — it does not execute scripts, follow links recursively, or send the content to third-party services.

This is the same trust model as `Read`-ing a file the user opened. Static security scanners flag the URL-fetch surface as an indirect-prompt-injection vector (W011 / W012) because the pattern exists; the user-driven opt-in and the artifact-review gates are the mitigations.

## Input Resolution

- If `prd_source` was set from the init argument, use that.
- If no argument was provided, ask the user: "Start from scratch or seed from an existing requirements document?"
  - **A) From scratch** — Skip to final report.
  - **B) From existing document** — Ask the user for a file path or URL.

## Read Document

Read the file (local path via `Read` tool) or fetch the URL (via `WebFetch` tool). Support common formats: Markdown, plain text, PDF, HTML.

Per the consent model above, the agent fetches what the user named; it does not derive URLs, follow embedded links, or read additional documents without further user input.

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
