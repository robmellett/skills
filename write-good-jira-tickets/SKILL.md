---
name: write-good-jira-tickets
description: Write or review a Jira ticket — bug report, user story, task or tech debt — so it can be picked up without a follow-up conversation. Use when the user wants to write, file, rewrite or improve a Jira ticket, bug report or user story, write acceptance criteria, split a story that is too big, or turn a vague request ("checkout is broken") into a ticket.
---

A good ticket survives a **cold read**: someone who never saw the bug, heard the conversation, or saw the Slack thread can act on it from the ticket alone. They can reproduce or build it, they know what was actually observed, and they know what proves it's done. Every rule below serves the cold read.

Worked before/after examples of a bug and a story: [`EXAMPLE.md`](EXAMPLE.md). Read it when you need the level of detail for a real ticket.

Reviewing a ticket that already exists? Run step 4 against it, then rewrite using steps 1–3.

## 1. Gather the facts

Collect what the user knows and sort every claim into **observed** (seen, logged, reproduced) or **assumed** (inferred, suspected, reported second-hand). Keep that split all the way into the ticket.

When a fact the ticket needs is missing, ask the user for it. If they don't know, the gap goes into the ticket as an **open question**. Guessing to fill it isn't allowed.

Done when every claim you will write is tagged observed or assumed, and every gap is either filled or recorded as an open question.

## 2. Pick the type and fill its fields

**Bug:**

- **Steps to reproduce**: numbered, specific, repeatable. Include the URL or screen, the exact data entered, and the exact action ("press Pay twice before a result appears", not "submit the form").
- **Expected result**: what should have happened.
- **Actual result**: what did happen, observed only. Put suspected consequences under open questions.
- **Environment**: device, OS, browser and version, build or release, environment (staging/prod), account or tenant if relevant.
- **Evidence**: console errors, network/request IDs, stack traces, log lines, screenshots. A screen recording for anything intermittent or timing-dependent.

**Story** (a user-facing outcome): work through [`STORIES.md`](STORIES.md). It covers the problem-first statement, the single specific role, Given/When/Then criteria, edge cases and splitting. In short:

- **User story**: `As a <specific role>, I want <capability>, so that <benefit>.` Describe the outcome, not the implementation.
- **Context**: the user's problem in plain language, and what they do today instead.
- **Business rules, examples and design references**, when there are any.

**Task / tech debt / infrastructure** (work that supports delivery but isn't a user capability itself): context (why it matters), the change wanted, and how you'll know it worked. Developers file these too. They get the same cold read.

**Subtask**: one piece of _how_ inside a story or task ("add a payment-declined response handler"). It inherits its parent's acceptance criteria and states only its own piece.

Every ticket, regardless of type, also gets the fields in step 3.

Done when every field for the chosen type is filled or is explicitly an open question.

## 3. Write the shared fields

**Title**: one sentence that names the behaviour and its context. A reader seeing only the title in a backlog list should know what's wrong or wanted, and roughly why it matters.

| Symptom title  | Specific title                                               |
| -------------- | ------------------------------------------------------------ |
| Login broken   | Login button does not respond when clicked in Chrome 114     |
| Fix button     | Password reset email not delivered to Gmail addresses        |
| Backend issue  | Add rate limiting to POST /api/auth/login                    |

**Acceptance criteria**: the conditions specific to this ticket that must hold before it closes. Write them before development starts (ideally in refinement, where they surface misunderstandings). Use `- [ ]` checkboxes, or Given/When/Then for stories. Each criterion must be:

- _testable_: someone can check it pass/fail ("returns HTTP 200 and sends a confirmation email", not "the form should work")
- _specific_: names the input, the action and the outcome, using concrete values in place of words like _intuitive_, _fast_, _easy_ or _user-friendly_
- about _what_ must happen. _How_ to build it belongs in subtasks.

Cover the main path first, then validation, permissions, empty states, errors, retries and duplicate input. State business rules outright. A reader shouldn't have to infer them.

Acceptance criteria are not the team's **Definition of Done**. The DoD is the shared bar for every ticket (code review, tests, docs, release approval) and isn't repeated per ticket. A ticket is done when its criteria pass _and_ the DoD is met. Moving it to Done without checking the criteria just hides unfinished work.

**Priority**: set by customer impact, business value, risk, urgency, dependencies, and whether a workaround exists. Don't set it by how loud the request was. Default scale (adapt it to the org's incident policy):

| Level    | Meaning                                                                  |
| -------- | ------------------------------------------------------------------------ |
| Critical | Severe service, data or security impact. Follow the incident process.    |
| High     | An important workflow is blocked with no useful workaround.              |
| Medium   | Real impact, but a usable workaround exists. Rank against planned work.  |
| Low      | Cosmetic or minor. Fix when time allows.                                 |

Pick the lowest level the facts support. If everything is High, nothing is.

**Links**: use Jira issue links (`blocks`, `is blocked by`, `relates to`, `duplicates`) for related work. A "see also" in the description doesn't count as a link.

**Parent epic**: one primary epic. Link any other initiatives it touches, but don't parent it under them. If the work genuinely serves unrelated outcomes, split it.

**Planning fields**, when the team uses them: product area or component, sprint or release, estimate, dependencies and known risks.

**Owner**: assign a person or team. If the user doesn't know who, say so and suggest asking the team lead. An unassigned ticket gets ignored.

**Open questions**: everything recorded in step 1 that the implementer must resolve or that could change the implementation.

**Technical detail**: include it when it affects scope, security, performance, integration or risk. Leave other implementation detail to subtasks.

**Size**: put in enough to reproduce, implement and verify, and no more. When a ticket holds independent outcomes, split it into one ticket per outcome and link them.

Done when every shared field is filled and each acceptance criterion passes the testable/specific check.

## 4. Cold-read review

Read the draft as a stranger who has only the ticket, and answer:

1. What is the first action I'd take? (If it's "ask someone", the ticket fails.)
2. Can I reproduce it, or know exactly what to build?
3. What was actually observed, and what is only assumed?
4. What would prove the fix, or prove the story delivers its benefit?
5. What could change the implementation?
6. Could the team estimate this now, without major open questions?

Any answer that needs a guess becomes either a fix to the ticket or a new open question. When the user can get a teammate to do the cold read for real, suggest it. That teammate should get only the ticket. For stories, the cold read can also be done in refinement: read it aloud and check that everyone can explain the benefit.

Done when all six questions are answered from the ticket text alone.

## 5. Deliver

Output the ticket as Markdown in this order: title, context/user story, steps or the change wanted, expected/actual (bugs), environment and evidence, acceptance criteria, open questions, then priority, parent epic, links, planning fields and owner. If a Jira/Atlassian tool is available and the user asked to file it, create the issue there with the same content. Otherwise hand back the Markdown for them to paste in.
