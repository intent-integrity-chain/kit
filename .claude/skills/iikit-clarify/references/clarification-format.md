# Clarification Q&A Format

## Format

Each clarification entry follows this pattern:

```
- Q: <question text> -> A: <answer text> [<ref1>, <ref2>, ...]
```

### References

The bracketed list at the end traces the Q&A back to the spec items it clarifies. Valid reference types:

| Prefix | Meaning | Example |
|--------|---------|---------|
| `FR-`  | Functional Requirement | `FR-001` |
| `US-`  | User Story | `US-2` |
| `SC-`  | Success Criterion | `SC-003` |

Every Q&A entry MUST include at least one reference.

## Examples

### Single reference

```markdown
- Q: How long should sessions last? -> A: 24 hours with refresh tokens [FR-012]
```

### Multiple references

```markdown
- Q: How do story cards map to columns? -> A: Columns are Todo / In Progress / Done based on task completion state [FR-001, FR-003, US-2]
```

### New item created by clarification

If the answer leads to creating a new requirement or story, reference the newly created ID:

```markdown
- Q: Are offline capabilities required? -> A: No, online-only for MVP [FR-015]
```

### Cross-cutting clarification

If the answer affects multiple items across categories:

```markdown
- Q: Should the pipeline and board share the same data source? -> A: Yes, both read from tasks.md [FR-002, FR-008, US-1, US-3]
```

## Full Section Example

```markdown
## Clarifications

### Session 2026-02-10

- Q: How do story cards map to columns? -> A: Columns are Todo / In Progress / Done [FR-001, US-2]
- Q: When does the dashboard launch? -> A: Only during implementation phase [FR-005, SC-001]
- Q: When is a story "In Progress" vs "Done"? -> A: Todo = 0 tasks checked. In Progress >= 1. Done = all checked [FR-003, FR-004, US-1]

### Session 2026-02-12

- Q: Should errors show inline or as toasts? -> A: Inline within the affected component [FR-010, US-4]
```

## Parsing

Parsers should extract references with:

```
/\[((?:(?:FR|US|SC)-\w+(?:,\s*)?)+)\]\s*$/
```

This captures the trailing `[...]` bracket and splits on `, ` to get individual IDs.
