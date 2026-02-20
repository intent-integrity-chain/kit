# Constitution & Premise Loading Procedure

## Premise Loading (all skills)

Read `PREMISE.md` if it exists. This provides app-wide context: what the project is, who it's for, the domain, and the high-level vision. Use it to inform decisions across all phases — feature scoping, architectural choices, naming conventions, and priority judgments. If missing: proceed without it (not required, but strongly recommended).

## Constitution Loading (most skills)

1. Read `CONSTITUTION.md` — if missing, ERROR with `Run: /iikit-00-constitution`
2. Parse all principles, constraints, and governance rules
3. Note all MUST, MUST NOT, SHALL, REQUIRED, NON-NEGOTIABLE statements

## Enforcement Mode (plan, implement)

In addition to basic loading:

1. **Extract enforcement rules** — build checklist from normative statements:
   ```
   CONSTITUTION ENFORCEMENT RULES:
   [MUST] Use TDD - write tests before implementation
   [MUST NOT] Use external dependencies without justification
   ```

2. **Declare hard gate**:
   ```
   CONSTITUTION GATE ACTIVE
   Extracted X enforcement rules
   ANY violation will HALT with explanation
   ```

3. **Before writing ANY file**: validate output against each principle. On violation: STOP, state the violated principle, explain what specifically violates it, suggest compliant alternative.

## Soft Loading (specify)

Constitution is recommended but not required for specify:
- If missing: WARNING recommending `/iikit-00-constitution`, then proceed
- If exists: parse and validate against principles

## Model Suggestions (all skills with Next Steps)

When suggesting the next step, also suggest the appropriate model per [model-recommendations.md](model-recommendations.md):

1. **Check expiration**: read the `Expires` date in model-recommendations.md. If expired, do a web search for current model rankings (speed, reasoning, cost) for each agent, update the file, and set a new expiration (+2 weeks).
2. **Detect agent**: check env vars (`CLAUDECODE=1`, `GEMINI_CLI=1`, etc.) to determine which agent is running.
3. **Look up the next phase's tier** (light/medium/heavy) and the agent-specific model + switch command.
4. **Append a model hint** to the Next Steps output, e.g.: `Tip: /iikit-03-plan benefits from deep reasoning. Switch to Opus: /model opus`
5. If the agent is unknown, show a generic suggestion: "Consider using a stronger model for this phase."
