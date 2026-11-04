# Writing a story

A story is one **user-facing outcome**. Work through these in order, then return to step 3 of `SKILL.md` for the shared fields.

## 1. Start from the problem

Before naming a feature, describe what the user is struggling with, in plain language. A story that opens with a solution ("add a Redis cache") has skipped the part that tells the team whether the solution is right.

## 2. Name one specific role

Use the role the user actually holds, such as `warehouse supervisor`, `returning customer` or `finance manager`, not `user`. When two roles need different things, they are two stories.

## 3. Write the statement

`As a <role>, I want <capability>, so that <benefit>.`

The capability is an outcome the user can see, not an implementation. The benefit is the reason it's worth building. If you can't fill in the benefit, go back to step 1.

| Weak            | Improved                                                                                                       |
| --------------- | -------------------------------------------------------------------------------------------------------------- |
| Build reports   | As a team lead, I want weekly workload summaries, so that I can spot capacity problems before planning.        |
| Improve search  | As a support agent, I want search results grouped by customer, so that I find the right case faster.          |
| Add login security | As an account owner, I want multi-factor authentication, so that unauthorized access is harder.             |

Title the ticket with the capability in plain words, such as "Save a delivery address during checkout".

## 4. Write the acceptance criteria as Given/When/Then

```
Given <starting condition>
When <user action or event>
Then <observable result>
```

> Given an inventory item is below its reorder threshold,
> when the supervisor opens the stock view,
> then the item appears in the low-stock group.

Three to five criteria is typical. Write the main journey first, then add one criterion for each of these that applies:

- validation of missing or bad input
- permissions: who may and may not do this
- the empty state: nothing matches, nothing exists yet
- errors and failures from dependencies
- duplicates and repeats, such as the same event twice or a double submit

## 5. Add examples and edge cases

Write concrete examples for ordinary use and for unusual inputs. Include any failure that would change behaviour, security, support load or testing. Examples settle business rules that prose leaves ambiguous ("a 10% discount on a $0.99 item rounds to…").

## 6. Check the size, and split when needed

Size with story points. Points are relative effort, complexity and uncertainty, not hours. A label change might be 1 point; address management might be 8 because of permissions, validation, storage and testing. An estimate far bigger than expected means the story needs splitting or a spike first.

The story should fit in one iteration. Split it when it has any of these:

- several independent outcomes
- more than one role
- a large estimate
- more criteria than fit comfortably on one screen

Split into **vertical slices**. Each slice delivers a meaningful outcome end to end, not one layer of the stack. The test for a slice: can the team ship it as a meaningful outcome before the related enhancements are done? An "account redesign", for example, splits into profile editing, password change, notification settings and account deletion. Each one ships on its own.

Done when the story names one role, states an outcome with a benefit, has testable criteria that cover the edge cases that apply, and fits in one iteration.
