# Checklist Item Examples

## Correct (testing REQUIREMENTS quality)

**UX Requirements Quality** (`ux.md`):
- "Are visual hierarchy requirements defined with measurable criteria?" [Clarity, Spec SFR-1]
- "Is the number and positioning of UI elements explicitly specified?" [Completeness]
- "Are interaction state requirements (hover, focus, active) consistently defined?" [Consistency]

**API Requirements Quality** (`api.md`):
- "Are error response formats specified for all failure scenarios?" [Completeness]
- "Are rate limiting requirements quantified with specific thresholds?" [Clarity]
- "Are authentication requirements consistent across all endpoints?" [Consistency]

**Security Requirements Quality** (`security.md`):
- "Are authentication requirements specified for all protected resources?" [Coverage]
- "Are data protection requirements defined for sensitive information?" [Completeness]
- "Is the threat model documented and requirements aligned to it?" [Traceability]

## Wrong (testing IMPLEMENTATION — never use these patterns)

- "Verify landing page displays 3 episode cards"
- "Test hover states work on desktop"
- "Confirm logo click navigates home"
- Any item starting with "Verify", "Test", "Confirm", "Check" + implementation behavior
- References to code execution, user actions, system behavior

## Required Patterns

- "Are [requirement type] defined/specified/documented for [scenario]?"
- "Is [vague term] quantified/clarified with specific criteria?"
- "Are requirements consistent between [section A] and [section B]?"
- "Does the spec define [missing aspect]?"
