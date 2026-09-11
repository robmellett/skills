# Design doc sections

The catalogue. The frame is near-mandatory; everything after it is chosen by cost of error, not filled in by default. Examples come from a caching layer named RecencyBank sitting between a web server and Postgres.

## The frame — the first page

### Title

Short, distinctive, evocative of what the project does. `RecencyBank`, not `Project Flying Silver Horse`.

### Metadata

Author and contact, creation date, the authoritative URL (a shortlink if your org has them), status, and sign-offs with names and dates.

> **URL**: http://go/recency-bank-design
> **Author**: Michael Lynch (michael@example.com)
> **Created**: 2026-06-22
> **Status**: Approved — alan@ signed off 2026-07-14; betty@ signed off 2026-07-15

### Objective

One sentence, plain language, intelligible to any stakeholder.

> Improve application performance by adding a caching layer between the Trogdor web server and the Postgres database.

### Background

Why this project, why now, what problem it solves, what was already tried. Lead with the numbers that motivated it.

> When Trogdor launched in 2023, pages loaded in 100ms or less. Three years on, median page loads reach 600ms, and database lookups are 80% of that. 95% of lookups hit just 3% of rows — a pattern that benefits greatly from a memory-backed cache.

### Related documents

Test plans, functional specs, design docs for neighbouring systems, and the previous iteration of this design.

### Goals

The high-level benefits, tied back to the background. Benefits, never implementations.

> - Increase user-perceived responsiveness of the Trogdor web app
> - Reduce database server load

### Non-goals

What is explicitly out of scope, so readers stop assuming.

> - A general-purpose, reusable caching system
> - Location-aware caching for geographically distributed users

## The design

### Scenarios

Concrete journeys through the finished system, in steps.

> **Scenario: share a report via URL**
> 1. Bob creates a custom report in his KeyMetrics dashboard.
> 2. Bob clicks "Share > as URL".
> 3. Bob emails the URL to his teammate Charlie.
> 4. Charlie opens the link and sees an exact copy of Bob's report, read-only.

### Diagrams

Data flow, component fit, dependencies and callers, protocols between them. Editable formats only.

### Glossary

Terms a newer teammate or a reader outside the team would not know. Prefer defining a term inline at first use; reserve the glossary for terms that recur throughout.

### Constraints

Hard limits imposed from outside: budget, client requirements, infrastructure, existing dependencies.

> All servers are RISC-V, so all code and dependencies must run on RISC-V.

### Interfaces

How the system meets people and other systems. Sketch UIs loosely — a design doc is not the place to pin exact visual choices. For software, define the API, CLI or file format semantics.

> We will define a Go interface matching PostgresDB's API surface. RecencyBank implements it, wrapping the backing PostgresDB struct: it caches reads and forwards mutations to Postgres.

### Dependencies and infrastructure

Language, where the code runs, where data persists, third-party packages and services — and the reasoning for each.

Spend the words on the dependencies that are hard to change. Swapping languages or storage backends is a rewrite; swapping the transactional email provider is an afternoon.

> - **Language**: Go — widely used here, suited to highly parallel workloads.
> - **Third-party**: bbolt, a key-value store covering the features we need.

## The operational contract

### Service level objectives

Measurable targets, not adjectives. Cover uptime, latency and scale. Unlike an SLA there is no financial penalty attached, but the numbers end the ambiguity in "must be performant on mobile".

> - Trogdor 50th percentile latency for user-facing HTTP requests: ≤200ms
> - Postgres 50th percentile query latency: ≤80ms

### Monitoring and alerting

How the SLOs get measured in production, and what wakes someone up. How would you discover an outage? A severe slowdown?

> The following page the on-call engineer:
> - Trogdor 95th percentile latency for user-facing HTTP requests: ≥3s
> - Average Postgres CPU over a trailing 2m window: ≥90%

### Logging

What gets logged, at what levels, where it is stored, how long it is retained, who can read it, and what sensitive data must never appear.

> RecencyBank logs: its parameters, RAM capacity and usage at initialization; failures to persist values in memory; failures to invalidate the cache.

### Timeline

Milestones that deliver something a stakeholder can see, with dates. Front-load the parts that expose misunderstood requirements — a UI on dummy data before the real plumbing.

> - **M1 (2026-07-01)**: live in the test environment with hardcoded cached data
> - **M2 (2026-07-17)**: caching real data from Postgres
> - **M3 (2026-08-03)**: cache eviction and lifecycle rules enforced
> - **M4 (2026-08-22)**: fully deployed to production

## The risk sections

### Security

Which threats you considered, the attack surface, and where the trust boundaries sit.

> RecencyBank enforces no access control, so it must never accept requests from the public Internet. It runs on a segregated network, accepting requests only from the Trogdor web server and making outbound requests only to the Postgres server pool.

### Privacy

What sensitive data the system touches, retention, who has access, and the protections (encryption at rest and in transit).

> RecencyBank holds the same sensitive user data as Postgres and inherits its privacy policy. Engineers may access production only against a bug number, minimizing the user data any one person touches.

### Legal

For regulated domains, contractual obligations, or open-source licensing.

> **FizzleCorp contractual compliance**: our contract restricts creating new copies of FizzlePerfect™ user biometrics. Legal confirmed a caching layer falls within the contract's "storage layer" definition, so RecencyBank may cache this data without renegotiation.

## The living sections

### Open issues

One entry per unresolved question: the problem, the options, a proposed resolution, and the next step.

> **Open issue: RAM size for the cache**
> We need the RAM figure that minimizes total infrastructure cost across cache and database. Testing would tell us, but costs ~3.0 dev days to set up plus 0.75 per simulation.
> **Proposed**: provision 128 GB untested — probably close enough, and dev time costs more than RAM.
> **Next step**: ask the tech lead to weigh in.

### Resolved issues

Closed open issues, decision first, original discussion kept underneath for posterity.

> **Resolved: RAM size for the cache**
> **Decision**: provision 128 GB. If we miss the performance goals and RAM is the constraint, add more then — the dev cost of testing exceeds the cost of the extra RAM.
> [original discussion follows]

### Alternatives considered

The strong alternatives and why each was rejected. This pre-empts "why didn't you do X?" in review. Don't catalogue every idea anyone floated.

> - **Google Cloud Firestore as persistent storage**: durability and reliability were appealing, but platform lock-in and the difficulty of local testing ruled it out.
