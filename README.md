# Intent Integrity Kit

**Closing the intent-to-code chasm**

An AI coding assistant toolkit that preserves your intent from idea to implementation, with cryptographic verification at each step. Compatible with Claude Code, OpenAI Codex, Google Gemini, and OpenCode.

## What is Intent Integrity?

When you tell an AI what you want, there's a gap between your *intent* and the *code* it produces. Requirements get lost, assumptions slip in, tests get modified to match bugs. The **Intent Integrity Chain** is a methodology to close that chasm.

IIKit implements this chain:

```
Intent ──▶ Spec ──▶ Test ──▶ Code
       ↑       ↑        ↑
       │       │        └── hash verified (no tampering)
       │       └─────────── Given/When/Then locked
       └─────────────────── clarified until aligned
```

**Key principle**: No part of the chain validates itself. Tests are locked before implementation. If tests need to change, you go back to the spec.

## Quick Start

### Installation

```bash
# Install via Tessl
tessl install intent-integrity-chain/kit
```

> **Don't have Tessl?** Install it first: `npm install -g @tessl/cli`

### Your First Project

```bash
# 1. Launch your AI assistant
claude          # or: codex, gemini, opencode

# 2. Define project governance
/iikit-00-constitution

# 3. Specify a feature
/iikit-01-specify Build a CLI task manager with add, list, complete commands

# 4. Plan the implementation
/iikit-03-plan

# 5. Generate tests from requirements
/iikit-05-testify

# 6. Break into tasks
/iikit-06-tasks

# 7. Implement (with integrity verification)
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
│  2. /iikit-02-clarify       →  Resolve ambiguities (max 5 questions)       │
│  3. /iikit-03-plan          →  Technical plan (HOW - frameworks, etc.)     │
│  4. /iikit-04-checklist     →  Quality checklists (unit tests for English) │
│  5. /iikit-05-testify       →  Test specs from requirements (TDD)          │
│  6. /iikit-06-tasks         →  Task breakdown                              │
│  7. /iikit-07-analyze       →  Cross-artifact consistency check            │
│  8. /iikit-08-implement     →  Execute with integrity verification         │
│  9. /iikit-09-taskstoissues →  Export to GitHub Issues                     │
└────────────────────────────────────────────────────────────────────────────┘
```

## Assertion Integrity: How Tests Stay Locked

The core of IIKit is preventing circular verification - where AI modifies tests to match buggy code.

### How It Works

1. **`/iikit-05-testify`** generates tests from your spec's Given/When/Then scenarios
2. A SHA256 hash of all assertions is stored in `context.json` and as a git note
3. **`/iikit-08-implement`** verifies the hash before writing any code
4. If assertions were modified, implementation is **blocked**

```
╭─────────────────────────────────────────────────────────────────────────╮
│  ASSERTION INTEGRITY CHECK                                              │
├─────────────────────────────────────────────────────────────────────────┤
│  Context hash:  valid                                                   │
│  Git note:      valid                                                   │
│  Git diff:      clean                                                   │
│  TDD status:    mandatory                                               │
├─────────────────────────────────────────────────────────────────────────┤
│  Overall:       PASS                                                    │
╰─────────────────────────────────────────────────────────────────────────╯
```

### If Requirements Change

1. Update `spec.md` with new requirements
2. Re-run `/iikit-05-testify` to regenerate tests
3. New hash is stored, implementation proceeds

This ensures test changes are **intentional** and traceable to requirement changes.

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

**Constitution is tech-agnostic.** It survives framework migrations.

## Tessl Integration

IIKit uses [Tessl](https://tessl.io) tiles for AI-optimized library documentation.

During `/iikit-03-plan`:
- Searches and installs tiles for your tech stack
- Documents findings in `research.md`

During `/iikit-08-implement`:
- Queries `mcp__tessl__query_library_docs` before writing library code
- Uses current APIs, not outdated training data

## Project Structure

```
your-project/
├── .specify/
│   └── memory/
│       └── constitution.md      # Project governance
├── specs/
│   └── NNN-feature-name/
│       ├── spec.md              # Feature specification
│       ├── plan.md              # Implementation plan
│       ├── tasks.md             # Task breakdown
│       ├── research.md          # Tech research + tiles
│       ├── data-model.md        # Data structures
│       ├── contracts/           # API contracts
│       ├── checklists/          # Quality checklists
│       └── tests/
│           └── test-specs.md    # Locked test specifications
├── tessl.json                   # Installed tiles
└── AGENTS.md                    # Agent instructions
```

## Supported Agents

| Agent | Instructions File |
|-------|-------------------|
| Claude Code | `CLAUDE.md` -> `AGENTS.md` |
| OpenAI Codex | `AGENTS.md` |
| Google Gemini | `GEMINI.md` -> `AGENTS.md` |
| OpenCode | `AGENTS.md` |

## Learn More

- [Intent Integrity Chain explained](https://github.com/jbaruch/intent-integrity-chain) - The methodology behind IIKit
- [Back to the Future of Software](https://speaking.jbaru.ch/DVCzoZ/back-to-the-future-of-software-how-to-survive-ai-with-intent-integrity-chain) - Conference talk on IIC

## License

MIT License - See [LICENSE](LICENSE) for details.
