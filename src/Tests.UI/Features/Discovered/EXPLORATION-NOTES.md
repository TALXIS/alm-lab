# Exploration notes — Warehouse Picking app

Exploratory session driven entirely through the running app's UI. No repository
source, feature files or step bindings were read at any point, by design.

Date of run: 2026-09-20.

---

## What I tried, in order

1. **Oriented on the item list.** Three items: Laser Printer (50, Overflow
   Storage), Office Laptop (100, Main Warehouse), Wireless Mouse (5, Main
   Warehouse). All Active, all Electronics. Navigation offers Items,
   Transactions, Locations.
2. **Opened an item.** Item detail shows available quantity, category,
   location, status, and a list of that item's movements with a button to add
   a new one.
3. **Learned the picking form.** A movement needs a name (free text), a
   quantity, and a type. Type offers exactly two choices: Inbound and Outbound.
4. **Happy path.** Recorded an outbound movement of 1 against Wireless Mouse
   (5 available). Stock dropped to 4, the movement appeared in the item's
   history with today's date. Worked exactly as expected.
5. **Over-pick, 999 units** against 4 available. Rejected — no stock change, no
   movement recorded — but the dialog closed as though it had worked.
6. **Over-pick, 50 units**, to see whether any message was shown. None visible.
7. **Over-pick, 20 units**, screenshotted immediately on submit. This caught it:
   a green **"Transaction created"** confirmation. See finding 1.
8. **Verified nothing persisted** by reloading and by opening the full
   Transactions list. None of the three over-picks existed.
9. **Exact available quantity.** Recorded an outbound movement of 4 against 4
   available. Succeeded cleanly, stock went to 0. Boundary holds.
10. **Empty required field** (reached accidentally, then confirmed). Submitting
    with no name shows a red **"Please fill all required fields"** and keeps the
    dialog open.
11. **Negative quantity.** The quantity field refused to take `-5` at all,
    leaving it empty, so submission failed the required-field check.
12. **Zero quantity.** Accepted, and kept. See finding 3.
13. **Pick from an emptied item** (1 unit from 0 available). Reported as
    created; nothing recorded. See finding 2.
14. **Double-submit.** Filled a pick of 10 against Office Laptop (100) and
    fired the confirm action twice concurrently. One movement, stock 100 → 90.
    No double deduction.
15. **Over-long and malformed name.** 320 characters including markup, a script
    tag, non-Latin characters, an emoji and SQL-looking text, with a valid
    quantity of 1. Reported as created; nothing recorded. See finding 4.
16. **Abandoning mid-flow.** With the picking dialog open, the navigation links
    are unreachable — the dialog is properly modal. Cancelling and reopening
    gives a completely clean form with no stale values.
17. **Refresh mid-flow.** Reloading while on an item detail returns to the full
    item list. See finding 5.

---

## Findings

### 1. A rejected pick is reported as a success — HIGH

**Confidence: high. Seen directly, captured in a screenshot, reproduced four
times.**

When the app refuses to save a movement, it shows a green **"Transaction
created"** confirmation and closes the form. Stock does not move and no record
is written. The picker is told the opposite of what happened.

Reproduced with: an over-pick of 999, of 50 and of 20 against 4 available; a
pick of 1 against 0 available; and an over-long name (finding 4).

Why this matters more than a cosmetic wording bug: the stock guard itself is
working correctly — the warehouse is never over-drawn, which is the hard part.
The damage is entirely in the reporting. A picker who reads the confirmation
walks away believing units left the shelf. The physical pick may well happen
anyway, and now the system and the shelf disagree with no trace of why.

This is not a case of the app lacking a way to show errors. It has one, and
uses it correctly for missing required fields: a red banner, dialog stays open.
The rejected-save path simply does not use it.

I could not determine from the UI whether the backend returns an error that the
screen ignores, or whether the screen never asks. Either way the observable
behaviour is the same.

### 2. Picking from an item with no stock behaves the same way — HIGH

**Confidence: high. Seen directly.**

Wireless Mouse reached 0. Recording an outbound movement of 1 was reported as
created, and nothing was recorded. Same root cause as finding 1, but written up
separately because it is the most realistic way a picker meets this bug: the
shelf is empty, the app says the pick worked.

### 3. A pick of zero units is accepted and kept — MEDIUM

**Confidence: high. Seen directly, and the record is still in the ledger.**

A movement of zero units saves successfully and appears in the item's history
alongside real picks. It shows a quantity of 0 with today's date and an active
status.

This is a judgement call rather than an outright defect — nobody is harmed and
stock is correct. But a movement that moves nothing is not a real event, and
the ledger is the audit trail. Worth someone deciding deliberately whether zero
should be allowed, rather than it being allowed by omission.

### 4. An over-long movement name is silently discarded — MEDIUM

**Confidence: high for the observed behaviour, inferred for the cause.**

A 320-character name with an otherwise valid pick of 1 unit produced the same
false confirmation and saved nothing. I am **inferring** that name length is the
reason, because the same quantity and type succeed with a short name. I did not
narrow down the actual limit, so the true cut-off is unknown. It could also
have been triggered by the markup, the emoji or the non-Latin characters rather
than the length — I changed several things at once, which was sloppy of me.

No evidence of a script-injection problem: nothing executed, and the input was
rejected wholesale. The concern here is silent data loss, not security.

### 5. Refreshing during picking returns to the item list — LOW

**Confidence: high for the behaviour, low for it mattering.**

Reloading while viewing an item lands on the full item list rather than the
item. On a handheld in a warehouse an accidental refresh would cost the picker
their place. This is fairly ordinary single-page-app behaviour and may be
entirely intended — it is recorded because refresh-mid-action was on the list
to try, not because I think it is a defect.

---

## What held up under pressure

Worth stating plainly, because these are the rules the app gets right:

- **Stock is never over-drawn.** Every over-pick attempt was refused. No
  attempt produced a negative or inflated quantity.
- **Picking exactly the available quantity works**, taking stock cleanly to
  zero. The off-by-one boundary is correct.
- **Negative quantities cannot be entered.** The quantity field refuses a minus
  sign outright, so there is no path to a stock-increasing "pick".
- **Required fields are enforced**, with a clear red message and the form left
  open so the work is not lost.
- **The picking dialog is properly modal** — you cannot navigate away
  mid-entry.
- **Cancelling clears the form.** Reopening gives a clean slate with no stale
  values from the abandoned attempt.
- **Double-submit did not double-deduct.** One movement, one deduction.

### Weak test — do not treat as proven

The **double-submit** result deserves a caveat. I fired two confirm actions
concurrently, but the dialog closes on the first, so the second may simply have
landed on nothing rather than being rejected by any guard. This does **not**
demonstrate that the app is safe against a genuine concurrent double-save, for
example two pickers on two devices picking the same item at the same time. That
remains untested. Treat "double-submit is safe" as unproven.

---

## Data changed in the live environment

No teardown was performed and nothing was deleted. Everything below is real and
still present.

### Movements created (4, all still in the ledger)

| Name | Item | Type | Qty | Stock effect |
|---|---|---|---|---|
| EXPLORER-PICK-1 | Wireless Mouse (MSE-002) | Outbound | 1 | 5 → 4 |
| EXPLORER-EXACT-4 | Wireless Mouse (MSE-002) | Outbound | 4 | 4 → 0 |
| EXPLORER-NEG-5 | Wireless Mouse (MSE-002) | Outbound | 0 | none |
| EXPLORER-DOUBLE-10 | Office Laptop (LTP-001) | Outbound | 10 | 100 → 90 |

Note: **EXPLORER-NEG-5 is misleadingly named.** It was meant to be a negative
quantity test; the field refused the minus sign, and the record that actually
saved has a quantity of zero. It is the finding-3 record.

### Net stock changes

| Item | Before | After |
|---|---|---|
| Wireless Mouse (MSE-002) | 5 | 0 |
| Office Laptop (LTP-001) | 100 | 90 |
| Laser Printer (PRN-003) | 50 | 50 (unchanged) |

**Wireless Mouse is now fully depleted** as a direct result of this run. If
something else in this shared environment expects it to have stock, it will
need an inbound movement to restore it. I did not create one, to avoid adding
further records beyond what the exploration required.

### Attempts that changed nothing

Recorded for completeness — all were refused and left no trace: over-picks of
999, 50 and 20 on Wireless Mouse; a pick of 1 from Wireless Mouse at zero
stock; the 320-character name on Office Laptop; one submission with an empty
name; one submission with a negative quantity.

---

## Not tested, and why

- **Inbound movements.** Never exercised. I do not know whether inbound is
  capped, whether it has the same false-confirmation behaviour, or whether it
  can inflate stock arbitrarily. I stopped short because each test writes a
  permanent record to a shared environment. **This is the most valuable gap to
  close next** — the false-confirmation bug may well affect inbound too.
- **Genuine concurrency.** Two sessions picking the same item simultaneously.
  Not reachable with a single browser session.
- **The Locations screen.** Never opened.
- **The model-driven app** (secondary target). Not reached; the time went on
  the primary target as instructed.
- **The real length limit on a movement name**, and which of length, markup or
  character set actually triggered the rejection in finding 4.
- **Editing or deleting an existing movement.** I did not look for a way to do
  either, so I do not know whether the ledger is append-only.

---

## Note for whoever reviews this

None of these scenarios should be treated as ready to run. They are written
from observed behaviour only, with no knowledge of the existing step bindings,
so the wording will not match what is already bound. Findings 1 and 2 in
particular describe what the app *currently does*, which is the behaviour I
would expect a reviewer to want changed rather than locked in by a test.
