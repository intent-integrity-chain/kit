# Model Recommendations by Phase

**Expires**: 2026-03-06
**Last researched**: 2026-02-20

When this file is expired, the agent MUST do a fresh web search for current model rankings (speed, reasoning, cost) and update the recommendations and expiration date (+2 weeks).

## Detection

Check environment variables to determine the agent:
- `CLAUDECODE=1` → Claude Code
- `GEMINI_CLI=1` → Gemini CLI
- `CODEX_CLI=1` → Codex
- Otherwise → unknown (show generic suggestion)

## Phase-to-Model Mapping

Phases are grouped by reasoning demand:

**Light (fast/cheap model preferred):**
- `/iikit-core` (init, status, help)
- `/iikit-04-checklist` (scoring against spec)
- `/iikit-09-taskstoissues` (mechanical issue creation)

**Medium (balanced model):**
- `/iikit-01-specify` (structured extraction from description)
- `/iikit-02-clarify` (targeted questions)
- `/iikit-05-testify` (test spec generation)
- `/iikit-06-tasks` (task breakdown)
- `/iikit-bugfix` (bug analysis + task generation)

**Heavy (strongest model preferred):**
- `/iikit-00-constitution` (governance design, premise authoring)
- `/iikit-03-plan` (architecture, tech selection, data model)
- `/iikit-07-analyze` (cross-artifact consistency)
- `/iikit-08-implement` (code generation, parallel orchestration)

## Agent-Specific Recommendations

### Claude Code

| Tier | Model | Switch command |
|------|-------|----------------|
| Light | Haiku | `/model haiku` |
| Medium | Sonnet | `/model sonnet` |
| Heavy | Opus | `/model opus` |

### Gemini CLI

| Tier | Model | Switch command |
|------|-------|----------------|
| Light | Gemini 2.5 Flash | `/model gemini-2.5-flash` |
| Medium | Gemini 2.5 Pro | `/model gemini-2.5-pro` |
| Heavy | Gemini 2.5 Pro | `/model gemini-2.5-pro` |

### Codex

| Tier | Model | Switch command |
|------|-------|----------------|
| Light | codex-mini | CLI flag: `--model codex-mini` |
| Medium | o4-mini | CLI flag: `--model o4-mini` |
| Heavy | o3 | CLI flag: `--model o3` |

### Unknown Agent

Show generic suggestion: "Consider using a stronger/faster model for this phase."

## Suggestion Format

When suggesting the next step, append a model hint:

```
Next: /iikit-03-plan
Tip: This phase benefits from deep reasoning. Switch to [model]: [command]
```

Only suggest if the current model tier doesn't match the recommended tier for the next phase. If already on the right tier or higher, skip the suggestion.
