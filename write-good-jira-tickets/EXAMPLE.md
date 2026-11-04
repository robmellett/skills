# Example: from vague request to ticket

## Before

> **Checkout is broken**
>
> Checkout is broken, please fix.

This fails the cold read on every question. There's no first action, nothing to reproduce, no record of what was seen, and no definition of done.

## After

> **Checkout submits twice when Pay is pressed repeatedly on mobile**
>
> **Type:** Bug · **Priority:** High · **Owner:** Payments team · **Relates to:** PAY-412
>
> ### Context
>
> A shopper can resubmit the payment form while the first payment request is still pending. There is no pending indicator, so on a slow connection pressing Pay again looks like the right thing to do.
>
> ### Steps to reproduce
>
> 1. On staging, add any in-stock item to the cart and go to checkout.
> 2. Enter the test card `4242 4242 4242 4242`.
> 3. In DevTools, set network throttling to "Slow 3G".
> 4. Press **Pay**, then press it again before any result appears.
>
> ### Expected
>
> One payment attempt creates one order, and the button shows a pending state while the request is in flight.
>
> ### Actual
>
> Two `POST /api/checkout/pay` requests appear in the request log, about 400 ms apart. The button shows no pending state.
>
> ### Environment and evidence
>
> - iPhone 15, iOS 18.1, Safari; also reproduced in Chrome 131 with mobile emulation
> - Staging, build `2026.11.02-3`
> - Request IDs: `req_8f2a…`, `req_8f2c…`
> - Screen recording attached
>
> ### Acceptance criteria
>
> - [ ] After Pay is pressed, the button shows a pending state and ignores further presses until a result returns.
> - [ ] Pressing Pay repeatedly creates at most one paid order.
> - [ ] After a declined payment, the shopper can retry and that retry is processed normally.
> - [ ] A network timeout shows an error and allows a retry without creating a duplicate order.
>
> ### Open questions
>
> - Do both requests result in a charge? We observed two requests but have not checked the payment provider for duplicate charges.
> - Does the payment service already accept an idempotency key? If it does, the fix may be client-side only.

## What changed

- **Title** names the behaviour (double submit), the trigger (repeated presses), and the context (mobile).
- **Observed vs assumed** stay separate. Two requests in the log is observed and goes under _Actual_. A duplicate charge is suspected but unverified, so it goes under _Open questions_ and not into the title or the priority.
- **Steps** give the exact data and timing, so a stranger can reproduce it on the first try.
- **Acceptance criteria** cover the unhappy paths (decline, timeout) as well as the fix itself.
- **Priority** is High rather than Critical, based only on what's confirmed. Checkout is a core flow, and "only press Pay once" is not a workaround shoppers can be expected to know. If the open question confirms duplicate charges, raise it to Critical.
- **Open questions** record the one unknown that could change the implementation (idempotency support), so nobody fills it with a guess.
