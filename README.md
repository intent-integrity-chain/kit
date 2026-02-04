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
tessl install tessl-labs/intent-integrity-kit
```

> **Don't have Tessl?** Install it first: `npm install -g @tessl/cli`

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

**Constitution is spec-agnostic.** It transcends individual features - that's why it lives at the root, not in `/specs`.

## Powered by Tessl

IIKit is distributed as a [Tessl](https://tessl.io) tile - a versioned package of AI-optimized context.

**What Tessl provides:**

- **Installation**: `tessl install tessl-labs/intent-integrity-kit` adds IIKit to any project
- **Runtime knowledge**: During implementation, IIKit queries the Tessl registry for current library APIs - so the AI uses 2025 React patterns, not 2021 training data
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
            └── test-specs.md    # Locked test specifications
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
- **Assertion integrity** - Cryptographic verification to prevent circular validation
- **Intent Integrity Chain** - Theoretical framework connecting intent to implementation
- **Tessl integration** - Distribution via tile registry plus runtime library knowledge during implementation

## Learn More

- [GitHub Spec-Kit](https://github.com/github/spec-kit) - The original specification-driven development framework
- [Intent Integrity Chain explained](https://github.com/jbaruch/intent-integrity-chain) - The methodology behind IIKit
- [Back to the Future of Software](https://speaking.jbaru.ch/DVCzoZ/back-to-the-future-of-software-how-to-survive-ai-with-intent-integrity-chain) - Conference talk on IIC

## License

MIT License - See [LICENSE](LICENSE) for details.
