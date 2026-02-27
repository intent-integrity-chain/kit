# Ambiguity Taxonomies

Per-artifact scanning categories for structured ambiguity detection. Used by the Clarify skill during Step 1 (Scan for Ambiguities).

## Spec (`spec.md`)

- Functional Scope: core goals, out-of-scope declarations, user roles
- Domain & Data Model: entities, identity rules, state transitions, scale
- Interaction & UX: critical journeys, error/empty/loading states, accessibility
- Non-Functional: performance, scalability, reliability, observability, security, compliance
- Integrations: external APIs, data formats, protocol assumptions
- Edge Cases: negative scenarios, rate limiting, conflict resolution
- Constraints: technical constraints, rejected alternatives
- Terminology: canonical terms, deprecated synonyms
- Completion Signals: acceptance criteria testability, measurable DoD

## Plan (`plan.md`)

- Framework Choice: rationale, alternatives considered, migration risk
- Architecture: component boundaries, data flow, failure modes
- Trade-offs: performance vs. complexity, build vs. buy, consistency vs. availability
- Scalability: bottleneck awareness, horizontal/vertical limits
- Dependency Risks: version pinning, license compatibility, maintenance status
- Integration Points: API contracts, protocol assumptions, error propagation

## Checklist (`checklists/*.md`)

- Threshold Appropriateness: are numeric thresholds realistic and measurable?
- Missing Checks: gaps in coverage for the spec requirements
- False Positives: checks that would pass for wrong reasons
- Prioritization: are critical checks distinguishable from nice-to-haves?

## Testify (`features/*.feature`)

- Scenario Precision: are Given/When/Then steps unambiguous?
- Missing Paths: unhappy paths, edge cases, boundary conditions
- Given/When/Then Completeness: missing preconditions, unclear actions, vague expectations
- Data Variety: are test data examples representative?

## Tasks (`tasks.md`)

- Dependency Correctness: are blockers accurate? circular dependencies?
- Ordering: does the sequence make implementation sense?
- Scope: are tasks appropriately sized? any too large or too small?
- Parallelization: are parallel markers (`[P]`) accurate?

## Constitution (`CONSTITUTION.md`)

- Principle Clarity: are principles actionable or vague?
- Threshold Specificity: are numeric gates defined (e.g., "high coverage" → what number)?
- Conflict Resolution: do any principles contradict each other?
- Completeness: are there governance areas not covered?
- Enforcement Gaps: which principles lack verification mechanisms?
