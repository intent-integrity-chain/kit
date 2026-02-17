# Constitution Loading Procedure

## Basic Loading (most skills)

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
