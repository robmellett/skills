---
name: design-doc
description: Write or review a software design doc before implementation — objective, goals, non-goals, interfaces, SLOs, security, open issues. Use when the user wants a design doc, technical design, RFC or architecture doc, or when a piece of work is big or risky enough that the irreversible decisions should be settled in writing before any code is written.
---

A design doc exists to settle the **one-way doors** — the decisions that are expensive or impossible to undo — with reviewers, before anyone writes code. It is not a description of the implementation: if you specify every detail, you have written the implementation during the design phase, which defeats the point.

Reference for every section, with examples: [`SECTIONS.md`](SECTIONS.md).
A complete worked doc, end to end: [`EXAMPLE.md`](EXAMPLE.md) — read it when you need the register and level of detail, not just the section list.

Reviewing a doc that already exists? Skip to [Reviewing](#reviewing-an-existing-doc).

## 1. Calibrate the investment

Answer these about the work:

- Will multiple people coordinate on it?
- Will it take more than three months of full-time development?
- Will it run in production for years?
- Does it cross team boundaries?
- Are the goals or requirements ambiguous?
- Could a catastrophic risk — security, legal, data loss — be prevented at design time?

One yes makes a doc likely worth the effort; two or more makes it almost certain. Zero yeses: say so in a sentence, offer a paragraph in the ticket instead, and write the doc anyway if the user still wants one.

The count also sets the weight. A single-team, single-quarter feature gets a one-pager. Cross-team, long-lived, or catastrophic-risk work gets a long doc with named sign-offs.

## 2. Place it and name its readers

Look for design docs already in the repo (`docs/`, `rfcs/`, `adr/`) and match their location, filename pattern and section conventions. Absent a convention, write to `docs/design/<short-name>.md`.

Name the actual reviewers. They decide what needs explaining — a doc for one teammate on your own service and a doc for three teams and a legal reviewer are different documents.

## 3. Write the first page

Title, metadata, objective, background, goals, non-goals. Whatever you would say to a teammate before handing them the doc belongs here.

Goals state benefits, not implementations: "minimize outages related to deploying new app versions", never "add Kubernetes to our infrastructure".

**Done when** a reviewer who reads only the first page can state what this is for, why it is happening now, and what it deliberately will not do.

## 4. Choose the rest by cost of error

Walk the catalogue in [`SECTIONS.md`](SECTIONS.md) and ask one question of each candidate decision: **what is the penalty for being wrong?**

- Expensive to reverse — language, storage backend, trust boundary, data retention, API contract, anything with 200,000 lines built on top of it later — goes in the doc and gets defended.
- Cheap to reverse — the ones you could change in an afternoon on user feedback — stays out. A "load more" button is not a design-level concern, and burning review cycles arguing about it costs more than being wrong about it.

**Done when** every section present names a decision that would hurt to get wrong, and every omitted section was omitted because it is cheap to change later.

## 5. Draw the system

You already hold the mental picture of how the pieces fit; reviewers do not, and prose is a poor way to hand it over. Draw at least one diagram covering how data flows, how components fit together, and how the system meets its dependencies and callers.

Use an editable format — Mermaid inline in the doc for anything a repo will hold, otherwise D2, Excalidraw or draw.io. Never a photo of a whiteboard.

## 6. Record what is still unsettled

Write every unresolved question as an open issue: the problem, the options, a proposed resolution, and the immediate next step with an owner. When one closes, move it to Resolved with the decision on top and the original discussion kept underneath.

Then answer "why didn't you do X?" before review asks it: name the genuinely strong alternatives and why each was rejected. Skip the weak ones.

**Done when** no open question lives only in your head or in the conversation — each is in the doc with a next step.

## 7. Hand it to reviewers

Set the status and list who must sign off, by name and date. Tell the user which sections you want argued about — the expensive, hard-to-reverse ones — and which are already settled.

## Reviewing an existing doc

Read the doc against the catalogue and report what is missing and what should be cut:

- Does the first page stand alone?
- Are goals written as benefits rather than as implementations?
- Are non-goals explicit, so readers stop assuming scope?
- Is every expensive decision written and defended — and every cheap one absent?
- Are SLOs measurable numbers rather than adjectives? "Performant on mobile" is not an SLO; "50th percentile latency ≤200ms" is.
- Does each open issue carry a next step and an owner?
- Would a reader outside the team hit an undefined term?
