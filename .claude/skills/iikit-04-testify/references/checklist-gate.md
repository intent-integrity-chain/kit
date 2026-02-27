# Checklist Completion Gate

Used by: testify, tasks, analyze, implement

## Check Procedure

1. If `FEATURE_DIR/checklists/` exists and contains `.md` files:
   - Count `- [ ]` (unchecked) and `- [x]` (checked) items across all files
   - If any unchecked items remain:
     ```
     WARNING: Checklists incomplete (X/Y items checked, Z%).
     Recommend running /iikit-03-checklist to resolve.
     Continue anyway? [y/N]
     ```
   - If user declines: stop and suggest `/iikit-03-checklist`
2. If no checklists directory exists: proceed silently (checklists are optional)

## Gate Strength

- **Soft gate** (testify, tasks, analyze): warn and ask
- **Hard gate** (implement): MUST be 100% complete; ask user to confirm if incomplete
