# Spec-to-Plan Phase Separation: IoT Fleet Management

## Problem/Feature Description

A logistics company operates a fleet of 2,000 delivery trucks, each equipped with GPS trackers and engine telemetry sensors. They need a feature that lets dispatchers monitor vehicle health in real time and receive alerts when a truck needs maintenance. The engineering team has already set up their project governance (constitution) and now needs to go from a raw feature description to a technical plan.

Your job is to produce both the feature specification and the technical plan, in that order.

## Output Specification

Produce the following files:
- `specs/005-fleet-health/spec.md` — the feature specification
- `specs/005-fleet-health/plan.md` — the technical implementation plan
- `specs/005-fleet-health/research.md` — technology decisions with rationale
- `specs/005-fleet-health/data-model.md` — entity definitions with fields and relationships

## Input Files

The following files are provided as inputs. Extract them before beginning.

=============== FILE: CONSTITUTION.md ===============
# Project Constitution v1.0.0

## Preamble

This constitution governs all development on the Fleet Operations Platform.

## Principles

### P1: Data Integrity First
All telemetry data MUST be stored with full provenance (device ID, timestamp, ingestion timestamp). Data loss is unacceptable — the system MUST guarantee at-least-once delivery for all sensor readings.

### P2: Operational Continuity
The platform MUST degrade gracefully under partial failure. Loss of a single component MUST NOT cause system-wide outage. All alerting paths MUST have a fallback channel.

### P3: Auditability
Every alert generated MUST be traceable to the specific telemetry readings that triggered it. Alert suppression decisions MUST be logged with rationale.

### P4: Testing Philosophy
Test-driven development is OPTIONAL for this project. Teams MAY write tests before or after implementation, but all features MUST have test coverage before merge.

## Amendment Procedure

Amendments require CTO approval and increment the minor version number. Breaking changes to principles increment the major version.

=============== FILE: PREMISE.md ===============
# Project Premise

## What
A fleet operations platform that ingests real-time vehicle telemetry, monitors fleet health, and automates maintenance scheduling for delivery logistics companies.

## Who
Primary users are fleet dispatchers who monitor 50-200 vehicles per shift. Secondary users are maintenance coordinators who schedule repairs. Tertiary users are fleet managers who review trends.

## Why
Unplanned breakdowns cost $2,500 per incident in towing, delayed deliveries, and emergency repairs. Preventive maintenance based on actual telemetry (not fixed schedules) reduces breakdowns by 40% in industry studies. Current monitoring is manual — dispatchers check a spreadsheet updated twice daily.

## Domain
Fleet management, vehicle telematics, predictive maintenance, logistics operations

## Scope
Real-time telemetry ingestion, health scoring, threshold-based alerts, maintenance recommendation engine. Excludes route optimization, driver behavior scoring, and fuel management.

=============== FILE: .specify/context.json ===============
{
  "tdd_determination": "optional",
  "active_feature": "005-fleet-health"
}

## Feature Description from the Product Manager

The PM's description (from a stakeholder meeting):

> "Dispatchers need to see which trucks are healthy and which ones need attention, right on their dashboard. Each truck sends GPS coordinates and engine data — things like oil pressure, coolant temperature, engine RPM, and battery voltage — every 30 seconds. We want a health score for each truck, like a simple red/yellow/green indicator.
>
> When a truck's health drops to yellow, the dispatcher should get a notification. When it goes red, we need an urgent alert that also goes to the maintenance coordinator. The maintenance coordinator should be able to see the history of readings that led to the alert, so they can decide what kind of repair is needed.
>
> We also want to be able to set custom thresholds — like, some trucks are older and their normal oil pressure is lower than newer ones. The dispatcher should be able to adjust the thresholds per truck or per truck model.
>
> Oh, and one more thing — we need to handle the case where a truck stops sending data. If we don't hear from a truck for 5 minutes, that should show up as a 'connection lost' status, not just a stale green indicator."
