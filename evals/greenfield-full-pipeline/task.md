# Greenfield Full Pipeline: Team Standup Bot

## Problem/Feature Description

A mid-size software company (80 engineers across 12 teams) wants to replace their daily standup meetings with an asynchronous bot. Each morning, team members answer three questions in Slack. The bot collects responses, identifies blockers, and posts a team summary. Managers can view summaries across teams.

Your job is to produce the specification, plan, test specifications, and task breakdown for this feature.

## Output Specification

Produce the following files in order:
1. `specs/009-standup-bot/spec.md` — feature specification
2. `specs/009-standup-bot/plan.md` — technical implementation plan
3. `specs/009-standup-bot/research.md` — technology decisions
4. `specs/009-standup-bot/data-model.md` — entity definitions
5. `specs/009-standup-bot/tests/features/*.feature` — BDD test specifications (one or more files)
6. `specs/009-standup-bot/tasks.md` — dependency-ordered task breakdown

## Input Files

The following files are provided as inputs. Extract them before beginning.

=============== FILE: CONSTITUTION.md ===============
# Project Constitution v1.0.0

## Principles

### P1: Test-Driven Development
Test-first development MUST be used for all features. Test specifications MUST be written before implementation begins. Implementation tasks MUST reference test spec IDs. Test assertions MUST NOT be modified to match buggy code — fix the code, not the tests.

### P2: Privacy by Default
User response data MUST NOT be accessible to anyone outside the user's team unless the user explicitly opts in. Cross-team summaries MUST show only aggregated data (blocker counts, response rates), never individual responses.

### P3: Minimal Disruption
The bot MUST NOT send unsolicited messages outside configured hours. All notifications MUST respect user timezone and working hours. Users MUST be able to snooze or opt out of reminders without manager visibility into who opted out.

### P4: Incremental Delivery
Features MUST be deliverable in vertical slices. Each user story MUST be independently deployable.

## Amendment Procedure

Amendments require engineering lead approval and increment the minor version. P1 (TDD) and P2 (Privacy) are immutable principles.

=============== FILE: PREMISE.md ===============
# Project Premise

## What
An asynchronous standup bot for Slack that replaces synchronous daily meetings with structured text check-ins, blocker detection, and team summaries.

## Who
Primary users are individual contributors who submit standup responses. Secondary users are engineering managers and team leads who review summaries. Tertiary users are program managers who view cross-team blocker reports.

## Why
Synchronous standups consume 12 teams × 15 minutes × 5 days = 15 hours of meeting time per week. Teams across 4 time zones can't find a common meeting slot. Written responses are searchable and create an audit trail that verbal standups don't.

## Domain
Developer tooling, team communication, Slack integration

## Scope
Standup question prompts, response collection, blocker detection, team summaries, cross-team blocker dashboard. Excludes sprint planning, retrospectives, and project tracking integration.

=============== FILE: .specify/context.json ===============
{
  "tdd_determination": "mandatory",
  "active_feature": "009-standup-bot"
}

## Feature Description from the Engineering Lead

> "Here's what we need:
>
> **Daily check-in collection**: Every morning at a configured time (per team, respecting time zones), the bot DMs each team member with three questions: What did you do yesterday? What are you doing today? Any blockers? Team members respond in the DM thread. They have until noon their local time.
>
> **Blocker detection**: If someone mentions a blocker, the bot should tag it and include it in a special blockers section of the team summary. We want basic keyword detection — words like 'blocked', 'waiting on', 'stuck', 'need help', 'dependent on'.
>
> **Team summary**: After the collection window closes, the bot posts a summary to the team's standup channel. It should list who responded, what their updates are, and highlight any blockers. People who didn't respond should show as 'No response' — don't nag them.
>
> **Cross-team blocker view**: Managers should be able to type a slash command like `/blockers` and see all current blockers across their teams, grouped by team. This must only show the blocker text, not the full standup response, to respect the privacy of individual updates."
