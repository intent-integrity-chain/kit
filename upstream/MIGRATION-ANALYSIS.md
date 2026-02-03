# Intent Integrity Kit to Claude Skills Migration Analysis

Research analysis for migrating GitHub intent-integrity-kit agents to Claude skills while preserving slash commands, handoffs, and workflow orchestration.

---

## Executive Summary

Migration is **FEASIBLE** with straightforward architecture. Claude skills are an open standard supported by Claude Code, OpenAI Codex CLI, and Gemini CLI.

**Core insight:** Constitution is a PROJECT ARTIFACT (like `spec.md`), not framework rules. The `/iikit-00-constitution` skill creates it; all other skills load and validate against it.

**Success criteria:**

1. Every skill loads constitution first—non-negotiable
2. Self-validating skills check their own prerequisites (matches original intent-integrity-kit pattern)
3. Critical gate skills (plan, analyze, implement) halt on constitution violations
4. File-based state persistence via `.specify/context.json`
5. Cross-platform agent files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) reference project constitution

**Migration order:** constitution skill → agent files → specify → clarify → plan → checklist → tasks → analyze → implement → taskstoissues

**Note:** Migration order follows the actual intent-integrity-kit workflow: Constitution → Specify → Clarify → Plan → Checklist → Tasks → Analyze → Implement

**Timeline:** 6 weeks across 6 phases

| Phase | Weeks | Focus |
|-------|-------|-------|
| 1 | 1 | Foundation (constitution, agent files, hooks) |
| 2 | 2-3 | Specification & Clarification |
| 3 | 4 | Planning & Tasks |
| 4 | 5 | Analysis & Implementation |
| 5 | 5-6 | Integration & Polish |
| 6 | 6 | Testing & Validation |

---

## Prerequisites

**Source materials required:**

| Item | Location | Notes |
|------|----------|-------|
| Intent Integrity Kit Template | `IIKit_Template_v0_0_90.zip` | Contains all agent files, scripts, templates |
| GitHub Repository | https://github.com/github/intent-integrity-kit | Reference documentation and latest updates |

**Extracted source structure:**

```
IIKit_Template_v0_0_90/
├── .github/
│   ├── agents/                    # Agent files (9 total)
│   │   ├── iikit-00-constitution.agent.md
│   │   ├── iikit-01-specify.agent.md
│   │   ├── iikit-02-clarify.agent.md
│   │   ├── iikit-03-plan.agent.md
│   │   ├── iikit-04-checklist.agent.md
│   │   ├── iikit-05-tasks.agent.md
│   │   ├── iikit-06-analyze.agent.md
│   │   ├── iikit-07-implement.agent.md
│   │   └── iikit-05-taskstoissues.agent.md
│   └── prompts/                   # Prompt stubs (trigger only, ~30 bytes each)
│       └── iikit.*.prompt.md
├── .specify/
│   ├── memory/
│   │   └── constitution.md        # TEMPLATE with placeholders
│   ├── scripts/bash/
│   │   ├── common.sh              # Shared functions
│   │   ├── check-prerequisites.sh # Validation + JSON context output
│   │   ├── create-new-feature.sh  # Branch creation + feature numbering
│   │   ├── setup-plan.sh          # Plan initialization
│   │   └── update-agent-context.sh# Updates CLAUDE.md/AGENTS.md dynamically
│   └── templates/
│       ├── spec-template.md       # ~4KB
│       ├── plan-template.md       # ~4KB
│       ├── tasks-template.md      # ~9KB
│       ├── checklist-template.md  # ~1KB
│       └── agent-file-template.md # ~500B
└── .vscode/
    └── settings.json
```

---

## Source: Intent Integrity Kit Architecture

### Nine-Agent Workflow

Implements Constitution → Specify → Clarify → Plan → Tasks → Analyze → Implement pipeline:

| Agent | Size | Purpose | Key Output |
|-------|------|---------|------------|
| iikit-00-constitution | 5.2KB | Create project governance principles | `.specify/memory/constitution.md` |
| iikit-01-specify | 12.8KB | Feature specs from natural language | `spec.md`, branches, validation checklist |
| iikit-02-clarify | 11.3KB | Structured questioning (max 5: 3 initial + 2 follow-up) | Clarification answers in spec |
| iikit-03-plan | 3.1KB | Technical architecture decisions | `plan.md`, `research.md`, `data-model.md`, `contracts/` |
| iikit-04-checklist | 16.8KB | "Unit Tests for English"—validates REQUIREMENTS quality, not implementation | `checklists/*.md` |
| iikit-05-tasks | 6.3KB | Executable work unit breakdown | `tasks.md` with phases |
| iikit-06-analyze | 7.2KB | Cross-artifact consistency validation | Validation report |
| iikit-07-implement | 7.5KB | TDD workflow + ignore file generation | Code + tests + .gitignore/.dockerignore |
| iikit-05-taskstoissues | 1.1KB | Export tasks to GitHub Issues | GitHub Issues |

### Key Mechanisms

**Handoffs via YAML frontmatter:**

```yaml
# From iikit-01-specify.agent.md
---
description: Create or update the feature specification...
handoffs: 
  - label: Build Technical Plan
    agent: iikit-03-plan
    prompt: Create a plan for the spec. I am building with...
  - label: Clarify Spec Requirements
    agent: iikit-02-clarify
    prompt: Clarify specification requirements
    send: true
---
```

**Workflow chaining systems:**

1. Script-based validation: `check-prerequisites.sh --json` outputs `{"FEATURE_DIR":"...", "AVAILABLE_DOCS":[...]}`
2. Template references: Each agent loads templates from `.specify/templates/`
3. Inline checklist gating: Quality validation embedded in agent flow
4. Branch-based feature detection: `git branch --show-current` → `001-feature-name` parsing

**File topology:**

```
project-root/
├── specs/                           # Feature specs (NOT under .specify/)
│   └── NNN-feature/
│       ├── spec.md
│       ├── plan.md
│       ├── tasks.md
│       ├── data-model.md
│       ├── research.md
│       ├── quickstart.md
│       ├── contracts/
│       │   ├── api-spec.json
│       │   └── signalr-spec.md
│       └── checklists/
│           └── requirements.md
└── .specify/
    ├── memory/
    │   └── constitution.md
    ├── scripts/bash/
    └── templates/
```

**Note:** Feature specs live at `specs/NNN-feature/`, NOT `.specify/specs/`. The `.specify/` directory contains only memory, scripts, and templates.

---

## Target: Claude Skills Reference

### Single-File-Plus-Directory Model

YAML frontmatter controls behavior:

```yaml
---
name: skill-name          # Creates /slash-command (lowercase, hyphens, max 64 chars)
description: When to use  # Critical for auto-triggering (max 1024 chars)
disable-model-invocation: true  # Forces explicit user invocation
context: fork             # Creates ISOLATED subagent (blank context, NOT inherited)
allowed-tools:            # Tool restrictions (Claude-specific)
  - Read
  - Grep
  - Bash(git:*)
model: claude-sonnet-4-20250514  # Override default model
user-invocable: false     # Only Claude can invoke (for background knowledge skills)
agent: Explore            # Subagent type: Explore, Plan, or custom
argument-hint: "feature name"  # Autocomplete hint
---
```

**Constraints:**

- Name limit: 64 characters (lowercase, numbers, hyphens only)
- Description limit: 1024 characters per skill
- Context budget: ~15,000 characters for all skill descriptions combined (run `/context` to check)
- No direct skill-to-skill invocation—orchestration via conversation or agent file

**Arguments:**

- `$ARGUMENTS` — all arguments as single string
- `$1`, `$2`, `$ARGUMENTS[N]` — positional arguments

**Progressive disclosure:** Metadata (~100 tokens/skill) → Instructions (<5K tokens) → Resources (on-demand)

**Directory structure:**

```
.claude/skills/
  skill-name/
    SKILL.md
    scripts/
    references/
    assets/
```

### Context Fork Semantics

**Warning:** Despite suggesting Unix fork() behavior, `context: fork` creates an **isolated subagent with blank context**—it does not inherit the parent conversation. Results are summarized and returned.

Use for: Research or exploration where verbose intermediate context shouldn't pollute main conversation.

Do NOT use when: Skills need access to prior conversation history or state from earlier workflow phases.

### Subagent Resume

Subagents can be resumed via `agentId`, maintaining full context from previous interactions. Each execution stores transcripts in `agent-{agentId}.jsonl`.

**Caveat:** Known bugs where user prompts may not be properly stored in transcript files, degrading resume experience after 2-3 resumes.

### Hook Events (Claude-specific)

Available hooks: `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, `UserPromptSubmit`, `Notification`, `PreCompact`, `SessionStart`, `SessionEnd`, `PermissionRequest`

Hooks exist at two levels: global (in `settings.json`) and agent-scoped (in skill frontmatter).

---

## Feature Mapping

### Direct Equivalents

| Intent Integrity Kit | Claude Skills |
|----------|---------------|
| `/iikit-01-specify` | `name: iikit-specify` |
| `.github/prompts/*.prompt.md` | `.claude/skills/*/SKILL.md` |
| `.specify/scripts/` | `scripts/` + Bash tool |
| `$ARGUMENTS` | `$ARGUMENTS` (same), plus `$1`, `$2` for positional |
| Project constitution | Same location—skill creates it, agent files reference it |
| `check-prerequisites.sh` | Self-validating skills (inline bash checks) |

### Requires Adaptation

| Intent Integrity Kit Feature | Claude Skills Adaptation |
|------------------|--------------------------|
| Sequential gating | Self-validating skills + `disable-model-invocation: true` |
| Script-driven context discovery | Inline bash: `` !`find specs -name "spec.md"` `` |
| Branch-based feature detection | `` !`git branch --show-current` `` + prefix-based lookup |
| Template loading | Store in `references/` directory |
| Cross-artifact consistency | Dedicated `/analyze` skill with comparison instructions |
| `[NEEDS CLARIFICATION]` markers | Include syntax in skill instructions |
| Checklist tracking | Embed markdown checklists in skill output |
| Script JSON output | Persistent `.specify/context.json` file |

### Gaps

| Gap | Severity | Workaround |
|-----|----------|------------|
| Automatic feature numbering | Medium | Bash: scan existing, increment |
| Cross-platform scripts | Medium | Accept Unix-only or document WSL requirement |
| Description length constraints | Medium | Move details to SKILL.md body; description for triggers only |
| Context budget for many skills | Medium | Consolidate related skills; prioritize core workflow |

**Token budget estimate:**

| Skill | Description Length | Est. Tokens |
|-------|-------------------|-------------|
| iikit-constitution | ~80 chars | ~20 |
| iikit-specify | ~120 chars | ~30 |
| iikit-clarify | ~100 chars | ~25 |
| iikit-plan | ~90 chars | ~23 |
| iikit-checklist | ~110 chars | ~28 |
| iikit-tasks | ~85 chars | ~21 |
| iikit-analyze | ~95 chars | ~24 |
| iikit-implement | ~100 chars | ~25 |
| iikit-taskstoissues | ~75 chars | ~19 |
| **TOTAL** | **~855 chars** | **~215 tokens** |

Budget: ~15,000 chars available. Using ~855 chars (5.7%). **SAFE.**

### Portability Matrix

| Feature | Portable? | Notes |
|---------|-----------|-------|
| SKILL.md format | ✅ Yes | Open standard (Claude, Codex, Gemini) |
| `$ARGUMENTS` | ✅ Yes | Works everywhere |
| Self-validating skills | ✅ Yes | Bash `cat` works everywhere |
| `.specify/context.json` | ✅ Yes | File-based state |
| `allowed-tools` | ❌ Claude-only | Ignored by other platforms |
| `user-invocable` | ❌ Claude-only | Ignored by other platforms |
| Hook system | ❌ Claude-only | Backstop layer, not primary enforcement |
| ChatGPT Code Interpreter | ❌ No custom skills | Internal skills only |

---

## Migration Architecture

### Recommended Directory Structure

```
project/
├── CLAUDE.md                      # Claude Code: references project constitution
├── AGENTS.md                      # OpenAI Codex: same role
├── GEMINI.md                      # Gemini CLI: same role
├── .claude/
│   ├── settings.json              # Global hooks (Claude-specific)
│   └── skills/
│       ├── iikit-constitution/
│       │   ├── SKILL.md
│       │   └── references/
│       │       └── constitution-template.md
│       ├── iikit-specify/
│       │   ├── SKILL.md
│       │   └── references/
│       │       └── spec-template.md
│       ├── iikit-clarify/
│       │   ├── SKILL.md
│       │   └── references/
│       │       └── question-format.md
│       ├── iikit-plan/
│       │   ├── SKILL.md
│       │   └── references/
│       │       └── plan-template.md
│       ├── iikit-checklist/
│       │   ├── SKILL.md
│       │   └── references/
│       │       └── checklist-template.md
│       ├── iikit-tasks/
│       │   ├── SKILL.md
│       │   └── references/
│       │       └── tasks-template.md
│       ├── iikit-analyze/
│       │   └── SKILL.md
│       ├── iikit-implement/
│       │   └── SKILL.md
│       └── iikit-taskstoissues/
│           └── SKILL.md
├── specs/                             # Feature specs at ROOT (not under .specify/)
│   └── NNN-feature/
│       ├── spec.md
│       ├── plan.md
│       ├── tasks.md
│       └── checklists/
└── .specify/
    ├── memory/
    │   └── constitution.md        # PROJECT ARTIFACT: created by /iikit-00-constitution
    ├── scripts/bash/              # KEEP HERE for portability
    │   ├── common.sh
    │   ├── check-prerequisites.sh
    │   ├── create-new-feature.sh
    │   ├── setup-plan.sh
    │   └── update-agent-context.sh
    ├── templates/                 # Source templates (copied to skill references)
    └── context.json               # File-based state persistence
```

### Constitution Enforcement

**The constitution is a PROJECT ARTIFACT, not framework rules.** IIKit provides a template with placeholders. Users run `/iikit-00-constitution` to create their project's specific governance principles.

**Enforcement hierarchy:**

| Layer | Scope | Portable? |
|-------|-------|-----------|
| Skill constitution loading | Every skill | ✅ Yes |
| Skill output validation | Every skill | ✅ Yes |
| `PreToolUse` hook | Edit\|Write operations | ❌ Claude-only |
| Agent file reminder | Session context | ⚠️ Platform-specific |

**Per-skill requirements:**

| Skill | Critical Gate? | Enforcement |
|-------|----------------|-------------|
| iikit-constitution | No | Validates structure completeness |
| iikit-specify | No | Requirements don't contradict principles |
| iikit-clarify | No | Questions respect constraints |
| iikit-plan | **YES** | **STOP if tech decisions violate principles** |
| iikit-checklist | No | Items verify compliance |
| iikit-tasks | No | Task order respects principles (e.g., TDD) |
| iikit-analyze | **YES** | **Report all violations** |
| iikit-implement | **YES** | **STOP before every file write** |
| iikit-taskstoissues | No | Include constitutional context |

**Token cost:** ~2-3K tokens per skill invocation for constitution loading. Accepted tradeoff for governance strength.

### Self-Validating Skills

Each skill checks its own prerequisites—this is the primary enforcement mechanism. Users invoke the skill they want, get feedback if prerequisites are missing. No orchestrator needed.

**Two validation approaches (use BOTH):**

1. **context.json check** (fast, in-memory state):
```bash
cat .specify/context.json | jq -r '.artifacts.spec // empty'
```

2. **Script check** (thorough, filesystem verification):
```bash
.specify/scripts/bash/check-prerequisites.sh --json
```

**Recommendation:** Check context.json first for speed; fall back to script if context.json missing or stale.

```yaml
# .claude/skills/iikit-03-plan/SKILL.md
---
name: iikit-plan
description: Create technical architecture from specification
disable-model-invocation: true
---

# Intent Integrity Kit Plan

## Prerequisites Check

1. First, try context.json (fast path):
   ```bash
   SPEC_PATH=$(cat .specify/context.json 2>/dev/null | jq -r '.artifacts.spec // empty')
   ```

2. If empty or file missing, use script (creates context.json if needed):
   ```bash
   .specify/scripts/bash/check-prerequisites.sh --json
   ```

3. If no spec.md found, STOP and tell user:
   "No specification found. Run /iikit-01-specify first."

## Then proceed with planning...
```

### Cross-Platform Agent Files

Platform-specific agent files reference the PROJECT's constitution AND include markers for dynamic tech stack updates:

```markdown
<!-- CLAUDE.md or AGENTS.md or GEMINI.md -->
# Intent Integrity Kit Workflow Rules

This project uses specification-driven development. The phases are:
1. specify → creates spec.md
2. clarify → resolves ambiguities (max 5 questions)
3. plan → creates plan.md (requires spec.md)
4. checklist → creates requirements checklists
5. tasks → creates tasks.md (requires plan.md)
6. analyze → validates cross-artifact consistency
7. implement → writes code (requires tasks.md + checklists pass)

Never skip phases. Each /iikit-* command validates its prerequisites.
Read .specify/memory/constitution.md for this project's governing principles.

<!-- IIKIT-TECH-START -->
<!-- Tech stack will be inserted here by /iikit-03-plan -->
<!-- IIKIT-TECH-END -->
```

Agent files are reminders, not enforcement—they provide context but can't block operations.

**IMPORTANT:** The `<!-- IIKIT-TECH-START -->` and `<!-- IIKIT-TECH-END -->` markers MUST be present for `update-agent-context.sh` to function.

### Context Passing

**Environment variable override (CRITICAL for non-git repos):**

```bash
# SPECIFY_FEATURE env var overrides git branch detection
# Set in shell BEFORE invoking agent
export SPECIFY_FEATURE="003-user-auth"

# Scripts check this FIRST, then fall back to git
get_current_branch() {
    if [[ -n "${SPECIFY_FEATURE:-}" ]]; then
        echo "$SPECIFY_FEATURE"
        return
    fi
    # Then check git if available...
}
```

**Use cases:**
- Non-git repositories
- CI/CD pipelines where git context unavailable
- Manual override when working across multiple features

**Persistent `.specify/context.json` file** that skills read and write:

```json
{
  "version": "1.0",
  "currentFeature": "003-user-auth",
  "featureDir": "specs/003-user-auth",
  "phase": "plan",
  "artifacts": {
    "spec": "specs/003-user-auth/spec.md",
    "plan": null,
    "tasks": null,
    "research": null,
    "dataModel": null
  },
  "clarifications": {
    "sessionCount": 1,
    "questionsAsked": 3,
    "pendingFollowUps": 0,
    "lastSession": "2025-01-27T10:30:00Z"
  },
  "checklists": {
    "requirements.md": {"total": 8, "completed": 8, "status": "pass"},
    "ux.md": {"total": 12, "completed": 10, "status": "incomplete"}
  },
  "constitution": {
    "path": ".specify/memory/constitution.md",
    "version": "1.0",
    "validated": true
  },
  "lastUpdated": "2025-01-27T10:30:00Z",
  "updatedBy": "iikit-plan"
}
```

**Schema notes:**
- `version`: Schema version for forward compatibility
- `featureDir`: Resolved path (eliminates repeated lookups)
- `clarifications`: Tracks question budget (max 5 total)
- `checklists`: Cached status for implement gating
- `constitution.validated`: Confirms constitution exists and is parseable
- `updatedBy`: Audit trail for debugging

**Initial creation:** `iikit-specify` creates context.json when creating a new feature. Other skills update their relevant sections.

### Hook-Based Validation (Claude-specific)

Hooks provide automated validation as defense-in-depth. They are NOT the primary enforcement mechanism—skills must validate independently for portability.

**Global hooks** in `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".specify/scripts/bash/validate-constitution.sh \"$TOOL_INPUT\""
          }
        ]
      }
    ]
  }
}
```

**Agent-scoped hooks** in skill frontmatter (Claude Code 2.1+):

```yaml
---
name: iikit-implement
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: ".specify/scripts/bash/check-tests-exist.sh"
---
```

### Agent Context Update Mechanism

The `update-agent-context.sh` script dynamically modifies platform-specific agent files (CLAUDE.md, AGENTS.md, GEMINI.md) based on the tech stack in `plan.md`. This MUST be preserved in migration.

**Marker-based editing:**

```markdown
<!-- IIKIT-TECH-START -->
This project uses:
- Python 3.11 with FastAPI
- PostgreSQL 15
- Redis for caching
<!-- IIKIT-TECH-END -->
```

**Behavior:**
- Script detects which AI agent is in use
- Updates ONLY content between markers
- Preserves manual additions outside markers
- Adds new technologies from current plan without duplicating

**Called by:** `/iikit-03-plan` after Phase 1 (Design & Contracts)

```bash
# From iikit-03-plan.agent.md
.specify/scripts/bash/update-agent-context.sh copilot
```

### Checklist Lifecycle Across Agents

Checklists are created and consumed by multiple agents—migration must preserve this coordination:

| Agent | Creates | Reads | Marks Complete | Purpose |
|-------|---------|-------|----------------|---------|
| iikit-specify | `checklists/requirements.md` | — | — | Spec quality validation |
| iikit-checklist | `checklists/[domain].md` | — | — | Domain-specific requirements quality |
| **User (manual)** | — | — | **YES** | Human verifies requirements quality |
| iikit-implement | — | ALL `checklists/*.md` | — | **GATES implementation** until pass |

**IMPORTANT:** Checklist items are marked complete MANUALLY by the user, not by any agent. The checklists validate REQUIREMENTS quality—only a human can verify "Is this requirement clear enough?"

**Implement gating behavior:**

```markdown
1. Scan FEATURE_DIR/checklists/ for all .md files
2. For each checklist, count:
   - Total items: Lines matching `- [ ]` or `- [X]` or `- [x]`
   - Completed: Lines matching `- [X]` or `- [x]`
   - Incomplete: Lines matching `- [ ]`
3. If ANY checklist has incomplete items:
   - Display status table
   - STOP and ask: "Some checklists are incomplete. Proceed anyway? (yes/no)"
   - Wait for explicit user response
4. Only proceed after user confirmation or all checklists pass
```

**Checklist concept ("Unit Tests for English"):**

Checklists validate REQUIREMENTS quality, not implementation correctness:
- ✅ "Are hover state requirements consistent across all interactive elements?" [Consistency]
- ✅ "Is 'prominent display' quantified with specific sizing/positioning?" [Clarity]
- ❌ NOT "Verify the button clicks correctly" (this tests implementation)
- ❌ NOT "Confirm the API returns 200" (this tests implementation)

### Ignore File Generation (Implement)

The implement agent generates platform-appropriate ignore files based on detected tech stack. Migration must preserve this:

**Detection logic:**
- Check if git repo → create/verify `.gitignore`
- Check if Dockerfile exists or Docker in plan.md → create/verify `.dockerignore`
- Check if .eslintrc* exists → create/verify `.eslintignore`
- Check if eslint.config.* exists → ensure config's `ignores` entries cover required patterns
- Similar for: `.prettierignore`, `.npmignore`, `.terraformignore`, `.helmignore`

**Patterns by technology (from plan.md tech stack):**
- **Node.js/TypeScript**: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
- **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `dist/`, `*.egg-info/`
- **Java**: `target/`, `*.class`, `*.jar`, `.gradle/`, `build/`
- **C#/.NET**: `bin/`, `obj/`, `*.user`, `*.suo`, `packages/`
- **Go**: `*.exe`, `*.test`, `vendor/`, `*.out`
- **Rust**: `target/`, `debug/`, `release/`, `*.rs.bk`
- **Universal**: `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.swp`, `.vscode/`, `.idea/`

**Behavior:** If ignore file exists, verify it contains essential patterns and append only missing critical patterns.

### Error Handling Patterns

Every skill must handle these error conditions gracefully:

| Condition | Detection | Response |
|-----------|-----------|----------|
| Git unavailable | `git rev-parse 2>/dev/null` fails | Check `SPECIFY_FEATURE` env var; if unset, prompt user to set it |
| Constitution missing | File not found at `.specify/memory/constitution.md` | STOP with "Run /iikit-00-constitution first" |
| Constitution malformed | Missing required sections (Principles, Constraints) | STOP with specific parsing error, suggest manual fix |
| context.json missing | File not found | Create with defaults (iikit-specify) or STOP with prerequisite error (other skills) |
| context.json corrupted | JSON parse fails | Backup corrupted file, recreate from filesystem scan |
| Feature directory missing | `specs/NNN-*` not found | STOP with "Run /iikit-01-specify first" |
| User declines checklist bypass | Response is "no" or empty | STOP gracefully: "Implementation paused. Complete checklists and re-run /iikit-07-implement" |
| Spec has `[NEEDS CLARIFICATION]` | Grep finds markers | Warn user, suggest `/iikit-02-clarify` before proceeding |

**Recovery script:** Skills can call `check-prerequisites.sh --repair` to attempt automatic recovery:
- Rebuilds context.json from filesystem
- Validates constitution structure
- Reports unrecoverable errors

---

## Migration Plan

### Source-to-Target File Mapping

| Source (intent-integrity-kit) | Target (Claude Skills) |
|-------------------|------------------------|
| `.github/agents/iikit-00-constitution.agent.md` | `.claude/skills/iikit-00-constitution/SKILL.md` |
| `.github/agents/iikit-01-specify.agent.md` | `.claude/skills/iikit-01-specify/SKILL.md` |
| `.github/agents/iikit-02-clarify.agent.md` | `.claude/skills/iikit-02-clarify/SKILL.md` |
| `.github/agents/iikit-03-plan.agent.md` | `.claude/skills/iikit-03-plan/SKILL.md` |
| `.github/agents/iikit-04-checklist.agent.md` | `.claude/skills/iikit-04-checklist/SKILL.md` |
| `.github/agents/iikit-05-tasks.agent.md` | `.claude/skills/iikit-05-tasks/SKILL.md` |
| `.github/agents/iikit-06-analyze.agent.md` | `.claude/skills/iikit-06-analyze/SKILL.md` |
| `.github/agents/iikit-07-implement.agent.md` | `.claude/skills/iikit-07-implement/SKILL.md` |
| `.github/agents/iikit-05-taskstoissues.agent.md` | `.claude/skills/iikit-05-taskstoissues/SKILL.md` |
| `.specify/memory/constitution.md` | `.claude/skills/iikit-00-constitution/references/constitution-template.md` |
| `.specify/templates/*.md` | `.claude/skills/*/references/` |
| `.specify/scripts/bash/*.sh` | Keep in `.specify/scripts/bash/` (portability) |

### Phase 1: Foundation (Week 1)

**Scope:** Directory structure, constitution skill, agent files, context schema

**Deliverables:**

- `iikit-constitution` skill with template
- `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` (with tech stack markers)
- `.claude/settings.json` with `PreToolUse` hooks
- `.specify/context.json` schema documentation
- Error handling utilities in `check-prerequisites.sh`

**Acceptance criteria:**
- [ ] `/iikit-00-constitution` creates valid constitution from template
- [ ] Agent files include `IIKIT-TECH-START/END` markers
- [ ] PreToolUse hook validates constitution exists
- [ ] context.json schema documented with all fields

**Key distinction:** The TEMPLATE (with `[PRINCIPLE_1_NAME]` placeholders) goes into skill references. The PROJECT's actual constitution is created when user runs `/iikit-00-constitution`.

### Phase 2: Specification & Clarification (Weeks 2-3)

**Dependencies:** Phase 1 complete

**Skills to migrate:**

1. **iikit-specify** (12.8KB) — Branch name generation, prefix-based feature numbering, validation checklist, max 3 `[NEEDS CLARIFICATION]` markers, **creates context.json**
2. **iikit-clarify** (11.3KB) — Sequential questioning (max 5: 3 initial + 2 follow-up), recommendations, records in spec `## Clarifications` section, **updates context.json clarifications**

**Git integration:** Branch creation, automatic feature numbering, prefix-based feature lookup, `SPECIFY_FEATURE` env var support

**Acceptance criteria:**
- [ ] `/iikit-01-specify` creates feature branch, spec.md, and context.json
- [ ] `/iikit-02-clarify` respects 5-question limit across sessions
- [ ] Both skills load and validate constitution

### Phase 3: Planning & Tasks (Week 4)

**Dependencies:** Phase 2 complete

**Skills to migrate:**

1. **iikit-plan** (3.1KB) — **CRITICAL GATE**, research phase, design artifacts, agent context update
2. **iikit-checklist** (16.8KB) — "Unit Tests for English"—validates REQUIREMENTS quality (completeness, clarity, consistency), NOT implementation
3. **iikit-tasks** (6.3KB) — User story phases, task ID format (`T001 [P] [US1]`), parallel markers

**Acceptance criteria:**
- [ ] `/iikit-03-plan` updates CLAUDE.md/AGENTS.md/GEMINI.md via update-agent-context.sh
- [ ] `/iikit-04-checklist` creates domain-specific checklists, updates context.json
- [ ] `/iikit-05-tasks` generates correctly formatted task IDs

### Phase 4: Analysis & Implementation (Week 5)

**Dependencies:** Phase 3 complete

**Skills to migrate:**

1. **iikit-analyze** (7.2KB) — **CRITICAL GATE**, cross-artifact consistency, read-only analysis
2. **iikit-implement** (7.5KB) — **CRITICAL GATE**, checklist gating, TDD enforcement, ignore file generation
3. **iikit-taskstoissues** (1.1KB) — GitHub Issues export

**Acceptance criteria:**
- [ ] `/iikit-06-analyze` detects spec↔plan↔tasks inconsistencies
- [ ] `/iikit-07-implement` halts on incomplete checklists (prompts user)
- [ ] `/iikit-07-implement` generates appropriate ignore files
- [ ] `/iikit-05-taskstoissues` creates properly formatted GitHub issues

### Phase 5: Integration & Polish (Week 5-6)

**Dependencies:** Phases 2-4 complete

**Template verification:**

| Source | Target | Used By | Phase |
|--------|--------|---------|-------|
| `spec-template.md` | `iikit-specify/references/` | iikit-specify | 2 |
| `plan-template.md` | `iikit-plan/references/` | iikit-plan | 3 |
| `tasks-template.md` | `iikit-tasks/references/` | iikit-tasks | 3 |
| `checklist-template.md` | `iikit-checklist/references/` | iikit-checklist | 3 |
| `question-format.md` | `iikit-clarify/references/` | iikit-clarify | 2 |

**Note:** Templates are copied to skill references DURING their respective phase migrations, not as a separate step.

**Handoff migration:** Original YAML handoffs become cross-references in skill instructions:

```markdown
## Next Steps

After completing the specification, you can:
- Run `/iikit-02-clarify` if any `[NEEDS CLARIFICATION]` markers exist
- Run `/iikit-03-plan` to create the technical implementation plan

These skills will validate that this spec exists before proceeding.
```

### Phase 6: Testing & Validation (Week 6)

**Test categories:**

1. **Unit tests (per skill):**
   - Constitution loading succeeds/fails correctly
   - Prerequisites validation catches missing artifacts
   - Output format matches expected templates
   - context.json updates correctly

2. **Integration tests (workflow):**
   - Full Constitution→Implement pipeline completes
   - Checklist gating blocks implement when incomplete
   - Agent context update modifies all platform files
   - Prefix-based feature lookup works across branches

3. **Edge cases:**
   - Missing prerequisites (each combination)
   - Corrupted context.json (skill recreates it)
   - Non-git repository (SPECIFY_FEATURE env var)
   - User declines checklist bypass
   - Constitution violation detection

4. **Cross-platform validation:**
   - OpenAI Codex CLI: Portable features only
   - Gemini CLI: Portable features only
   - Document Claude-specific vs portable features

**Acceptance criteria:**
- [ ] All 9 skills pass unit tests
- [ ] End-to-end workflow completes without manual intervention
- [ ] Artifact formats match original intent-integrity-kit output
- [ ] Context budget under 15,000 characters (run `/context`)
- [ ] Portable features work on Codex and Gemini CLIs

---

## Risk Assessment

### High

| Risk | Mitigation | Status |
|------|------------|--------|
| Workflow enforcement regression | Self-validating skills + `disable-model-invocation` + agent file backstop | ✅ Addressed |
| Context loss between sessions | Persistent `.specify/context.json` with full schema | ✅ Addressed |
| Template fidelity drift | Exact template content in `references/` + explicit formatting instructions | ✅ Addressed |
| Context budget exhaustion | Token budget calculated: 5.7% used. SAFE. | ✅ Resolved |
| Constitution token overhead | ~2-3K tokens × 9 skills. Accepted tradeoff. | ✅ Accepted |

### Medium

| Risk | Mitigation | Status |
|------|------------|--------|
| Script failures on Windows | Document WSL requirement; scripts stay in `.specify/scripts/bash/` | ✅ Addressed |
| Skill description collisions | Use `disable-model-invocation` liberally, specific descriptions | ✅ Addressed |
| `context: fork` misuse | Document blank context behavior; avoid for state-dependent skills | ✅ Documented |
| Description length overflow | Move details to SKILL.md body | ✅ Addressed |
| Subagent resume degradation | Use file-based state (context.json) as primary persistence | ✅ Addressed |
| Phase ordering errors | Phases reordered to match actual workflow | ✅ Fixed |

### Low

| Risk | Mitigation | Status |
|------|------------|--------|
| Multi-platform compatibility | Core SKILL.md format is open standard; Claude-specific features documented | ✅ Addressed |

---

## Appendix A: Script Dependencies

| Script | Used By | Can Inline? |
|--------|---------|-------------|
| `common.sh` | All scripts | Yes |
| `check-prerequisites.sh` | plan, tasks, implement | Yes—self-validation pattern |
| `create-new-feature.sh` | specify | Partially—branch logic can inline |
| `setup-plan.sh` | plan | Yes |
| `update-agent-context.sh` | plan | No—modifies CLAUDE.md/AGENTS.md dynamically |

**Recommendation:** Keep scripts in `.specify/scripts/bash/` for portability. Skills call them via Bash tool.

---

## Appendix B: Pattern Reference

### Self-Validation Pattern

Every skill must validate prerequisites AND load constitution:

```markdown
---
name: iikit-plan
description: Create technical implementation plan from feature specification
---

## Constitution Loading (REQUIRED)

Before ANY action, load and internalize the project constitution:

1. Read constitution:
   ```bash
   cat .specify/memory/constitution.md
   ```

2. If file doesn't exist:
   ```
   ERROR: Project constitution not found at .specify/memory/constitution.md
   
   STOP - Cannot proceed without constitution.
   Run /iikit-00-constitution first to define project principles.
   ```

3. Parse all principles, constraints, and governance rules.

4. **Validation commitment:** Every output will be validated against each principle before being written.

## Prerequisites Check

1. Run: `.specify/scripts/bash/check-prerequisites.sh --json`
2. Parse JSON output for `FEATURE_DIR` and `AVAILABLE_DOCS`
3. If error or missing `spec.md`:
   ```
   ERROR: spec.md not found in feature directory.
   Run /iikit-01-specify first to create the feature specification.
   ```

## Instructions

[... skill-specific content ...]

## Output Validation (REQUIRED)

Before writing ANY artifact:

1. Review output against EACH constitutional principle
2. If ANY violation detected:
   - STOP immediately
   - State: "CONSTITUTION VIOLATION: [Principle Name]"
   - Explain: What specifically violates the principle
   - Suggest: Compliant alternative approach
   - DO NOT proceed with "best effort" or workarounds
3. If compliant, proceed and note: "Validated against constitution v[VERSION]"
```

**Order of operations:** Load constitution → Validate exists → Check prerequisites → Execute skill logic → Validate outputs → Write artifacts

### Task Format Pattern

From `iikit-05-tasks.agent.md`:

```markdown
- [ ] T001 Create project structure per implementation plan
- [ ] T005 [P] Implement authentication middleware in src/middleware/auth.py
- [ ] T012 [P] [US1] Create User model in src/models/user.py
- [ ] T014 [US1] Implement UserService in src/services/user_service.py
```

Components: `- [ ]` checkbox → `T###` ID → `[P]` parallel marker (optional) → `[US#]` story label → Description with file path

### Feature Numbering Pattern

```bash
# Find highest feature number across all sources
git fetch --all --prune
# Remote branches
git ls-remote --heads origin | grep -E 'refs/heads/[0-9]+-<short-name>$'
# Local branches  
git branch | grep -E '^[* ]*[0-9]+-<short-name>$'
# Specs directories (note: specs/ at repo root, NOT .specify/specs/)
ls -d specs/[0-9]+-* 2>/dev/null
# Use max + 1
```

### Prefix-Based Feature Lookup

**Critical behavior:** Multiple branches can work on the same feature spec. The scripts use PREFIX matching, not exact branch name matching:

```bash
# From common.sh - find_feature_dir_by_prefix()
# Branch "004-fix-bug" and "004-add-tests" both map to specs/004-*

# Extract numeric prefix from branch (e.g., "004" from "004-whatever")
if [[ "$branch_name" =~ ^([0-9]{3})- ]]; then
    local prefix="${BASH_REMATCH[1]}"
    # Search for directories that start with this prefix
    for dir in "$specs_dir"/"$prefix"-*; do
        # Returns first match
    done
fi
```

**Implications for migration:**
- Skills must use same prefix-based lookup logic
- Multiple branches (e.g., `004-fix-bug`, `004-add-feature`) share same spec directory
- Only one spec directory per numeric prefix is allowed

### Clarification Question Format

Max 5 questions total: 3 initial contextual questions + 2 optional follow-ups. Each question includes a **recommendation**:

```markdown
## Question [N]: [Topic]

**Context**: [Quote relevant spec section]

**What we need to know**: [Specific question]

**Recommended:** Option [X] - [Brief reasoning why this is best choice]

**Suggested Answers**:

| Option | Answer | Implications |
|--------|--------|--------------|
| A      | [First answer] | [Impact] |
| B      | [Second answer] | [Impact] |
| C      | [Third answer] | [Impact] |
| Custom | Provide your own | [Instructions] |

You can reply with the option letter (e.g., "A"), accept the recommendation by saying "yes" or "recommended", or provide your own short answer.
```

**Question limits:**
- Initial questions: Up to 3 (skip if already clear from $ARGUMENTS)
- Follow-up questions: Up to 2 more (only if ≥2 scenario classes remain unclear)
- Total cap: 5 questions per `/iikit-02-clarify` session

### Implement Checklist Gating

```markdown
| Checklist | Total | Completed | Incomplete | Status |
|-----------|-------|-----------|------------|--------|
| ux.md     | 12    | 12        | 0          | ✓ PASS |
| test.md   | 8     | 5         | 3          | ✗ FAIL |

If any checklist incomplete:
- Display table
- STOP and ask: "Some checklists are incomplete. Proceed anyway? (yes/no)"
- Wait for explicit user response
```

### Constitution Validation Script

`.specify/scripts/bash/validate-constitution.sh`:

```bash
#!/bin/bash
# Called by PreToolUse hook before Edit|Write|Bash operations

TOOL_INPUT="$1"
CONSTITUTION=".specify/memory/constitution.md"

if [[ ! -f "$CONSTITUTION" ]]; then
  echo "ERROR: No project constitution found at $CONSTITUTION"
  echo "Run /iikit-00-constitution first to define project principles."
  exit 1
fi

# Log operation for audit trail
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | PRE_TOOL | $TOOL_INPUT" >> .specify/audit.log

exit 0
```
