# Intent Integrity Kit

**Closing the intent-to-code chasm**

An AI coding assistant toolkit that preserves your intent from idea to implementation, with cryptographic verification at each step. Compatible with Claude Code, OpenAI Codex, Google Gemini, and OpenCode.

## What's New in v2.2.0

- **Pre-commit BDD runner enforcement**: When `.feature` files exist, code commits are mechanically gated — agents can no longer bypass the BDD verification chain by writing plain tests. Three gates: step definitions exist, runner dependency in project dep files, `verify-steps.sh` dry-run passes. Covers all 8 supported frameworks.

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
/iikit-03-plan

# 6. Generate tests from requirements
/iikit-05-testify

# 7. Break into tasks
/iikit-06-tasks

# 8. Implement (with integrity verification)
/iikit-08-implement
```

## The Workflow

Each phase builds on the previous. Never skip phases.

```
┌────────────────────────────────────────────────────────────────────────────┐
│  /iikit-core              →  Initialize project, status, help              │
├────────────────────────────────────────────────────────────────────────────┤
│  0. /iikit-00-constitution  →  Project governance (tech-agnostic)          │
│  1. /iikit-01-specify       →  Feature specification (WHAT, not HOW)       │
│  2. /iikit-02-clarify       →  Resolve ambiguities until spec is clear     │
│  3. /iikit-03-plan          →  Technical plan (HOW - frameworks, etc.)     │
│  4. /iikit-04-checklist     →  Quality checklists (unit tests for English) │
│  5. /iikit-05-testify       →  Gherkin .feature files from requirements     │
│  6. /iikit-06-tasks         →  Task breakdown                              │
│  7. /iikit-07-analyze       →  Cross-artifact consistency check            │
│  8. /iikit-08-implement     →  Execute with integrity verification         │
│  9. /iikit-09-taskstoissues →  Export to GitHub Issues                     │
└────────────────────────────────────────────────────────────────────────────┘
```

## BDD Verification Chain: How Tests Stay Locked

The core of IIKit is preventing circular verification — where AI modifies tests to match buggy code.

### How It Works

1. **`/iikit-05-testify`** generates Gherkin `.feature` files from your spec's Given/When/Then scenarios
2. A SHA256 hash of all step lines (across all `.feature` files) is stored in `context.json` and as a git note
3. **`/iikit-08-implement`** enforces the full BDD chain before marking any task complete:
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
2. Re-run `/iikit-05-testify` to regenerate `.feature` files
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
| Added/removed requirements | `/iikit-03-plan` then `/iikit-06-tasks` |
| Changed acceptance criteria (Given/When/Then) | `/iikit-05-testify` (re-generates .feature files, re-locks hash) |
| Clarified wording only | Nothing — downstream artifacts still valid |

### Changing the technical plan (plan.md, research.md)

**Option A — Re-run:** `/iikit-03-plan` detects the existing plan.md, shows a semantic diff of tech stack and architecture changes, and flags breaking changes with downstream impact.

**Option B — Edit directly:** Edit `plan.md` or `research.md` for targeted changes (swap a library, update a version, add a design decision).

**What to re-run after:**

| What changed | Re-run |
|--------------|--------|
| Swapped a framework/library | `/iikit-06-tasks` (tasks may differ) |
| Changed data model | `/iikit-05-testify` then `/iikit-06-tasks` |
| Added a design constraint | `/iikit-04-checklist` (new quality checks) |
| Minor version bump | Nothing |

### Changing tasks (tasks.md)

Re-run `/iikit-06-tasks`. It preserves `[x]` completion status on existing tasks, maps old task IDs to new ones by similarity, and warns about changes to already-completed tasks.

### Quick reference: "I want to change X, what do I run?"

```
Changed requirements?        → edit spec.md → /iikit-03-plan → /iikit-06-tasks
Changed acceptance criteria?  → edit spec.md → /iikit-05-testify
Changed tech stack?           → /iikit-03-plan (or edit plan.md) → /iikit-06-tasks
Changed a library?            → edit research.md → /iikit-06-tasks
Need more quality checks?     → /iikit-04-checklist
Everything looks wrong?       → /iikit-07-analyze (finds inconsistencies)
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
| `/iikit-03-plan` | Discovers and installs tiles for your tech stack |
| `/iikit-08-implement` | Queries `mcp__tessl__query_library_docs` before writing library code |

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
- **Mechanical enforcement** - Prerequisite gating, pre-commit hooks, and hash verification replace cooperative compliance — the agent can't skip phases or tamper with artifacts
- **Tessl integration** - Distribution via tile registry plus runtime library knowledge during implementation

## Learn More

- [Dashboard views and features](DASHBOARD.md) - Visual dashboard documentation
- [GitHub Spec-Kit](https://github.com/github/spec-kit) - The original specification-driven development framework
- [Intent Integrity Chain explained](https://github.com/jbaruch/intent-integrity-chain) - The methodology behind IIKit
- [Back to the Future of Software](https://speaking.jbaru.ch/DVCzoZ/back-to-the-future-of-software-how-to-survive-ai-with-intent-integrity-chain) - Conference talk on IIC

## License

MIT License - See [LICENSE](https://github.com/intent-integrity-chain/kit/blob/main/LICENSE) for details.
