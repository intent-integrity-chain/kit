# Project Governance Document for a Healthcare Data Platform

## Problem/Feature Description

A healthcare startup is building a HIPAA-compliant data analytics platform for hospital networks. The founding engineering team has been informally following some practices, but as they scale to 15 engineers, they need a formal governance document that all team members and AI coding assistants will follow. This document will serve as the authoritative source of non-negotiable development standards.

The CTO wants the document to capture the team's non-negotiable development standards.

## Output Specification

Produce a `CONSTITUTION.md` file at the project root, update `.specify/context.json` with any derived configuration, and write a brief `constitution-report.md`.

## Input Files

The following files are provided as inputs. Extract them before beginning.

=============== FILE: PREMISE.md ===============
# Project Premise

## What
A cloud-based analytics platform that ingests, processes, and visualizes de-identified patient data for hospital networks to improve clinical outcomes and operational efficiency.

## Who
Primary users are clinical data analysts and hospital administrators at mid-to-large hospital networks (500+ beds). Secondary users are compliance officers who need audit trails.

## Why
Hospital networks struggle with fragmented data across dozens of systems (EHR, billing, scheduling). Analysts spend 70% of their time on data collection and cleaning instead of insights. There is no HIPAA-compliant SaaS solution that handles the full pipeline from ingestion to visualization at the required scale.

## Domain
Healthcare IT, clinical analytics, HIPAA compliance

## Scope
Ingestion layer (HL7/FHIR adapters), data lake storage, anonymization pipeline, analytics query engine, dashboard visualization. Excludes EHR systems themselves and any direct patient interaction.

=============== FILE: .specify/context.json ===============
{}
