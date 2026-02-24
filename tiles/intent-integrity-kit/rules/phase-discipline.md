---
alwaysApply: true
---

# Phase Discipline

- NEVER write production code without `spec.md`, `plan.md`, and `tasks.md` in place
- NEVER skip phases — each `/iikit-*` skill validates its own prerequisites; if it blocks, run the prerequisite phase first
- When `.feature` files exist for a feature, ALWAYS ensure step definitions and a BDD runner dependency are present before committing code
- Use `/iikit-core status` to check what's done and what's next
