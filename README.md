# Intent Integrity Kit

**Closing the intent-to-code chasm**

An AI coding assistant toolkit that preserves your intent from idea to implementation, with cryptographic verification at each step. Compatible with Claude Code, OpenAI Codex, Google Gemini, and OpenCode.

## What's New in v2.7.2

- **27 bug fixes** from E2E testing across 12 projects (101 phases, 596 unit tests, 32 integration tests — all green).
- **Clarification badge fix**: Badges now count `- Q:` items (not session headings), and track clarifications on checklist, analyze, and tasks phases (were hardcoded to 0).
- **Dashboard resilience**: Generates without CONSTITUTION.md (was hard-fail exit 3), handles ESM projects with `type:module`.
- **Testified stage**: New `testified` feature stage between `planned` and `tasks-ready` when .feature files exist but no tasks.md.
- **Pre-commit softened**: Missing step_definitions and BDD runner dependency are now warnings, not commit blockers.
- **Bugfix task percentage**: Adding T-B bugfix tasks no longer decreases the implementation progress percentage.
- **Spec quality penalty**: Template specs with `[PLACEHOLDER]` brackets score lower to prevent false quality signals.
- **Next-step consistency**: `alt_steps` includes `/iikit-clarify` when constitution exists, status mode produces same alts as phase-based mode, `ready_for` clamped to agree with `next_step`.
- **Branch numbering**: Current branch excluded from auto-numbering; `create-new-feature.sh` warns when constitution missing.
- **Phase 00 on main**: Constitution phase no longer requires a feature branch.

### v2.6.0

- **Externalized next-step state machine**: All 12 skills, session hooks, and status queries now call a single `next-step.sh` script — one source of truth for workflow transitions, model tier suggestions, and `/clear` recommendations. Eliminates 12 independent copies of next-step logic that drifted out of sync.
- **Mandatory/optional path clarity**: Mandatory path is `00→01→02→[04 if TDD]→05→07`. Steps 03 (checklist), 06 (analyze), and 08 (tasks-to-issues) are optional and appear as `alt_steps` in the JSON output.
- **Model tier in status output**: `check-prerequisites.sh --phase status --json` now includes `model_tier` field, codified from `model-recommendations.md`.
- **Clear recommendations**: Each transition includes `clear_before`/`clear_after` flags based on context consumption patterns.

### v2.5.1

- **Clarify next-step fix**: Clarify now uses feature state to determine the correct next-step suggestion instead of hardcoded phase logic.

### v2.5.0

- **Generic clarify utility**: `/iikit-clarify` is now a standalone utility that can run after any phase on any artifact — spec, plan, checklist, testify, tasks, or constitution. Auto-detects the most recent artifact; override with an argument (e.g., `/iikit-clarify plan`). Per-artifact ambiguity taxonomies guide targeted questions.
- **Full skill renumbering**: Clarify extracted from the numbered sequence. New numbering: 02-plan, 03-checklist, 04-testify, 05-tasks, 06-analyze, 07-implement, 08-taskstoissues.
- **Dashboard clarification badges**: Pipeline nodes show `?N` amber badges when clarification sessions exist for that artifact. Clarify is no longer a pipeline phase — it's a utility visible through per-artifact badges.

### v2.0.0 (breaking)

- **BDD verification chain**: Testify generates standard Gherkin `.feature` files (replaces `test-specs.md`). The implement skill enforces a full red-green-verify cycle: hash integrity → step coverage → RED → GREEN → step quality.
- **3 new verification scripts**: `verify-steps.sh` (dry-run coverage for 8 BDD frameworks), `verify-step-quality.sh` (AST-based analysis detecting empty/tautological assertions), `setup-bdd.sh` (auto-scaffolding).
- **Static dashboard**: Real-time kanban board as a static HTML file (replaces the old server process). No ports, no pidfiles, no `npx`.
- **Cross-artifact traceability**: Analyze skill verifies `@FR-XXX` tags in `.feature` files trace to `spec.md` requirements.

[Full changelog →](https://github.com/intent-integrity-chain/kit/blob/main/CHANGELOG.md)

## What is Intent Integrity?

When you tell an AI what you want, there's a gap between your *intent* and the *code* it produces. Requirements get lost, assumptions slip in, tests get modified to match bugs. The **Intent Integrity Chain** is a methodology to close that chasm.

IIKit implements this chain:

```
Intent ──▶ Spec ──▶ .feature ──▶ Steps ──▶ Code
       ↑       ↑          ↑          ↑
       │       │          │          └── step quality verified (no assert True)
       │       │          └────────────── hash locked (no tampering)
       │       └───────────────────────── @FR-XXX tags traced
       └───────────────────────────────── clarified until aligned
```

**Key principle**: No part of the chain validates itself. `.feature` files are locked before implementation. Step definitions are verified for coverage and quality. If requirements change, you go back to the spec.

## Quick Start

### Installation

```bash
# Install via Tessl
tessl install tessl-labs/intent-integrity-kit
```

> **Don't have Tessl?** Install it first: `npm install -g @tessl/cli`

> **Note**: `tessl install` is the only supported installation method. During publish, shared reference and template files are copied into each skill for self-containment. Cloning the repo directly does not produce self-contained skills.

### Your First Project

```bash
# 1. Launch your AI assistant
claude          # or: codex, gemini, opencode

# 2. Initialize the project
/iikit-core init

# 3. Define project governance
/iikit-00-constitution

# 4. Specify a feature
/iikit-01-specify Build a CLI task manager with add, list, complete commands

# 5. Plan the implementation
/iikit-02-plan

# 6. Generate tests from requirements
/iikit-04-testify

# 7. Break into tasks
/iikit-05-tasks

# 8. Implement (with integrity verification)
/iikit-07-implement
```

## The Workflow

Each phase builds on the previous. Never skip phases.

```
┌────────────────────────────────────────────────────────────────────────────┐
│  /iikit-core               →  Initialize project, status, help             │
│  /iikit-clarify            →  Resolve ambiguities (any artifact, any time) │
│  /iikit-bugfix             →  Report and fix bugs                          │
├────────────────────────────────────────────────────────────────────────────┤
│  0. /iikit-00-constitution →  Project governance (tech-agnostic)           │
│  1. /iikit-01-specify      →  Feature specification (WHAT, not HOW)        │
│  2. /iikit-02-plan         →  Technical plan (HOW - frameworks, etc.)      │
│  3. /iikit-03-checklist    →  Quality checklists (unit tests for English)  │
│  4. /iikit-04-testify      →  Gherkin .feature files from requirements     │
│  5. /iikit-05-tasks        →  Task breakdown                               │
│  6. /iikit-06-analyze      →  Cross-artifact consistency check             │
│  7. /iikit-07-implement    →  Execute with integrity verification          │
│  8. /iikit-08-taskstoissues→  Export to GitHub Issues                      │
└────────────────────────────────────────────────────────────────────────────┘
```

## BDD Verification Chain: How Tests Stay Locked

The core of IIKit is preventing circular verification — where AI modifies tests to match buggy code.

### How It Works

1. **`/iikit-04-testify`** generates Gherkin `.feature` files from your spec's Given/When/Then scenarios
2. A SHA256 hash of all step lines (across all `.feature` files) is stored in `context.json` and as a git note
3. **`/iikit-07-implement`** enforces the full BDD chain before marking any task complete:
   - **Hash check**: `.feature` files not tampered since testify
   - **Step coverage**: `verify-steps.sh` — all Gherkin steps have matching step definitions (dry-run)
   - **RED phase**: Tests must fail before production code is written
   - **GREEN phase**: Tests must pass after production code is written
   - **Step quality**: `verify-step-quality.sh` — no empty bodies, no `assert True`, no missing assertions

```
╭─────────────────────────────────────────────────────────────────────────╮
│  BDD VERIFICATION CHAIN                                                 │
├─────────────────────────────────────────────────────────────────────────┤
│  .feature hash:    valid                                                │
│  Step coverage:    PASS (24/24 steps defined)                           │
│  Step quality:     PASS (0 empty, 0 tautological)                       │
│  TDD status:       mandatory                                            │
├─────────────────────────────────────────────────────────────────────────┤
│  Overall:          PASS                                                 │
╰─────────────────────────────────────────────────────────────────────────╯
```

### If Requirements Change

1. Update `spec.md` with new requirements
2. Re-run `/iikit-04-testify` to regenerate `.feature` files
3. New hash is stored, implementation proceeds

This ensures test changes are **intentional** and traceable to requirement changes.

## Iterating on Specs and Plans

The workflow is linear *the first time through*. After that, you'll often go back to refine things. Here's how.

### Changing requirements (spec.md)

**Option A — Re-run the skill:** `/iikit-01-specify` with updated description. It detects the existing spec.md, shows a semantic diff (added/removed/changed requirements), warns about downstream impact, and asks before overwriting.

**Option B — Edit directly:** Open `specs/NNN-feature/spec.md` and edit the markdown. This is fine for small tweaks (rewording a requirement, adding an edge case). Then re-run downstream phases to propagate changes.

**What to re-run after:**

| What changed | Re-run |
|--------------|--------|
| Added/removed requirements | `/iikit-02-plan` then `/iikit-05-tasks` |
| Changed acceptance criteria (Given/When/Then) | `/iikit-04-testify` (re-generates .feature files, re-locks hash) |
| Clarified wording only | Nothing — downstream artifacts still valid |

### Changing the technical plan (plan.md, research.md)

**Option A — Re-run:** `/iikit-02-plan` detects the existing plan.md, shows a semantic diff of tech stack and architecture changes, and flags breaking changes with downstream impact.

**Option B — Edit directly:** Edit `plan.md` or `research.md` for targeted changes (swap a library, update a version, add a design decision).

**What to re-run after:**

| What changed | Re-run |
|--------------|--------|
| Swapped a framework/library | `/iikit-05-tasks` (tasks may differ) |
| Changed data model | `/iikit-04-testify` then `/iikit-05-tasks` |
| Added a design constraint | `/iikit-03-checklist` (new quality checks) |
| Minor version bump | Nothing |

### Changing tasks (tasks.md)

Re-run `/iikit-05-tasks`. It preserves `[x]` completion status on existing tasks, maps old task IDs to new ones by similarity, and warns about changes to already-completed tasks.

### Quick reference: "I want to change X, what do I run?"

```
Changed requirements?        → edit spec.md → /iikit-02-plan → /iikit-05-tasks
Changed acceptance criteria?  → edit spec.md → /iikit-04-testify
Changed tech stack?           → /iikit-02-plan (or edit plan.md) → /iikit-05-tasks
Changed a library?            → edit research.md → /iikit-05-tasks
Need more quality checks?     → /iikit-03-checklist
Everything looks wrong?       → /iikit-06-analyze (finds inconsistencies)
```

**Rule of thumb:** Edit the artifact directly for small changes. Re-run the skill for significant changes — it shows you the diff and warns about downstream impact. Then cascade forward through the phases that depend on what you changed.

## Phase Separation

Understanding what belongs where is critical:

| Content Type | Constitution | Specify | Plan |
|--------------|:------------:|:-------:|:----:|
| Governance principles | ✓ | | |
| Quality standards | ✓ | | |
| User stories | | ✓ | |
| Requirements (functional) | | ✓ | |
| Acceptance criteria (Given/When/Then) | | ✓ | |
| **Technology stack** | | | ✓ |
| **Framework choices** | | | ✓ |
| Data models | | | ✓ |
| Architecture decisions | | | ✓ |

**Constitution is spec-agnostic.** It transcends individual features - that's why it lives at the root, not in `/specs`.

## Powered by Tessl

IIKit is distributed as a [Tessl](https://tessl.io) tile - a versioned package of AI-optimized context.

**What Tessl provides:**

- **Installation**: `tessl install tessl-labs/intent-integrity-kit` adds IIKit to any project
- **Runtime knowledge**: During implementation, IIKit queries the Tessl registry for current library APIs — so the AI uses 2026 React patterns, not 2023 training data
- **2000+ tiles**: Documentation, rules, and skills for major frameworks and libraries

**How IIKit uses Tessl:**

| Phase | What happens |
|-------|--------------|
| `/iikit-02-plan` | Discovers and installs tiles for your tech stack |
| `/iikit-07-implement` | Queries `mcp__tessl__query_library_docs` before writing library code |

## Project Structure

```
your-project/
├── CONSTITUTION.md              # Project governance (spec-agnostic)
├── AGENTS.md                    # Agent instructions
├── tessl.json                   # Installed tiles
├── .specify/                    # IIKit working directory
│   └── context.json             # Feature state
└── specs/
    └── NNN-feature-name/
        ├── spec.md              # Feature specification
        ├── plan.md              # Implementation plan
        ├── tasks.md             # Task breakdown
        ├── research.md          # Tech research + tiles
        ├── data-model.md        # Data structures
        ├── contracts/           # API contracts
        ├── checklists/          # Quality checklists
        └── tests/
            └── features/        # Locked Gherkin .feature files
```

## Supported Agents

| Agent | Instructions File |
|-------|-------------------|
| Claude Code | `CLAUDE.md` -> `AGENTS.md` |
| OpenAI Codex | `AGENTS.md` |
| Google Gemini | `GEMINI.md` -> `AGENTS.md` |
| OpenCode | `AGENTS.md` |

## Acknowledgments

IIKit builds on [GitHub Spec-Kit](https://github.com/github/spec-kit), which pioneered specification-driven development for AI coding assistants. The phased workflow, artifact structure, and checklist gating concepts originate from Spec-Kit.

IIKit extends Spec-Kit with:
- **Assertion integrity** - Cryptographic verification (hash-locked `.feature` files, pre-commit enforcement) to prevent circular validation where AI modifies tests to match buggy code
- **Skills instead of scripts** - Phases are Tessl skills (scoped context, prerequisite gating) rather than prompt-plus-script pairs, giving agents better adherence and context management
- **Tessl integration** - Distribution via tile registry plus runtime library knowledge during implementation

## Learn More

- [Dashboard views and features](DASHBOARD.md) - Visual dashboard documentation
- [GitHub Spec-Kit](https://github.com/github/spec-kit) - The original specification-driven development framework
- [Intent Integrity Chain explained](https://github.com/jbaruch/intent-integrity-chain) - The methodology behind IIKit
- [Back to the Future of Software](https://speaking.jbaru.ch/DVCzoZ/back-to-the-future-of-software-how-to-survive-ai-with-intent-integrity-chain) - Conference talk on IIC

## License

MIT License - See [LICENSE](https://github.com/intent-integrity-chain/kit/blob/main/LICENSE) for details.
