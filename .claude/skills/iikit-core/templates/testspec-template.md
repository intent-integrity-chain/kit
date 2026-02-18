# Test Specifications: [Feature Name]

**Generated**: [timestamp]
**Feature**: `spec.md` | **Plan**: `plan.md`

## TDD Assessment

**Determination**: [mandatory | optional | forbidden]
**Confidence**: [high | medium | low]
**Evidence**: [quoted constitutional statements or "No TDD indicators found"]
**Reasoning**: [explanation of determination]

---

<!--
DO NOT MODIFY TEST ASSERTIONS

These test specifications define the expected behavior derived from requirements.
During implementation:
- Fix code to pass tests, don't modify test assertions
- Structural changes (file organization, naming) are acceptable with justification
- Logic changes to assertions require explicit justification and re-review

If requirements change, re-run /iikit-05-testify to regenerate test specs.
-->

## From spec.md (Acceptance Tests)

### TS-001: [Test Name]

**Source**: spec.md:[section]:[requirement-id]
**Type**: acceptance
**Priority**: P1

**Given**: [precondition]
**When**: [action]
**Then**: [expected outcome]

**Traceability**: FR-XXX, SC-XXX, US-XXX-scenario-X

---

## From plan.md (Contract Tests)

### TS-XXX: [Test Name]

**Source**: plan.md:[section]:[contract-id]
**Type**: contract
**Priority**: P1

**Given**: [precondition]
**When**: [action]
**Then**: [expected outcome]

**Traceability**: [contract reference]

---

## From data-model.md (Validation Tests)

### TS-XXX: [Test Name]

**Source**: data-model.md:[entity]:[constraint]
**Type**: validation
**Priority**: P2

**Given**: [precondition]
**When**: [action]
**Then**: [expected outcome]

**Traceability**: [entity constraint reference]

---

## Summary

| Source | Count | Types |
|--------|-------|-------|
| spec.md | X | acceptance |
| plan.md | X | contract |
| data-model.md | X | validation |
| **Total** | **X** | |
