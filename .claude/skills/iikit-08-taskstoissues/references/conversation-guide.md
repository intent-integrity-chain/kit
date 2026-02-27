# Conversation Guide

Patterns for interactive sessions where the skill asks the user questions and integrates answers.

## Presenting Options

For multiple-choice questions, use this pattern:

1. **Analyze options** and determine the most suitable based on best practices, risk reduction, and project alignment
2. **State recommendation prominently**:
   ```
   **Recommended:** Option [X] - <reasoning>
   ```
3. **Render options table**:

   | Option | Description | Implications |
   |--------|-------------|--------------|
   | A | First option | Trade-offs |
   | B | Second option | Trade-offs |
   | C | Third option | Trade-offs |
   | Short | Provide a different short answer | |

4. **Accept flexible responses**: letter ("A"), affirmation ("yes", "recommended"), or custom text

## Gap Resolution Pattern (checklist, clarify)

When a gap or ambiguity is identified:

```markdown
---
Gap N of M: [Item ID]
---

**Missing Requirement:**
[Quote the checklist item or ambiguous spec text]

**Why This Matters:**
[Brief risk explanation if left unspecified]

**Suggested Options:**

| Option | Description | Implications |
|--------|-------------|--------------|
| A | [First reasonable default] | [Trade-offs] |
| B | [Alternative approach] | [Trade-offs] |
| C | [Another option] | [Trade-offs] |
| Skip | Leave unspecified for now | Will remain as gap |

**Your choice (A/B/C/Skip/Custom):** _
```

After user responds:
- A/B/C: update the target artifact (spec.md, checklist, etc.)
- Skip: leave as-is, continue to next
- Custom: integrate user's text

Show confirmation of what was added/changed after each resolution.

## Sequential Questioning Loop

When asking multiple questions one at a time:

1. Present exactly ONE question per turn
2. Use the options table format above
3. After user answers: validate, record, move to next
4. **Stop conditions**: all critical items resolved, user signals done ("stop", "done", "proceed"), or maximum question count reached
5. **Save after each integration** to minimize context loss risk

## Session Recording

When recording Q&A in a spec or artifact:
```
- Q: <question> -> A: <final answer> [REF-001, REF-002]
```
- References MUST list affected artifact items
- Group under dated session heading: `### Session YYYY-MM-DD`
