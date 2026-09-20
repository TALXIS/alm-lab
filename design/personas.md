# Personas

Who the Warehouse Management solution is for.

Two personas, not more. Everyone who touches this system is either responsible for the
catalogue or responsible for moving goods, and those two jobs want different surfaces, different
devices and different authority. A third persona would be a variation of one of these.

Both are already modelled as security roles in `src/Solutions.Security/Roles/`, so the cast is
confirmed against the build rather than invented beside it.

---

## Warehouse manager

| | |
|---|---|
| **Context of use** | At a desk, on a full screen, in sessions of minutes rather than seconds. Works across the whole operation, not one site. |
| **Decision authority** | Organization-wide (**Global**) on everything, including delete. They are the only ones who may retire a location or remove a record. |

### Jobs to be done

- Know what the company stocks, where each thing sits, and what it is worth.
- Decide the level at which each item should be reordered, and see at a glance which items have
  fallen to it.
- Keep the list of sites current — add one, correct its address or capacity, retire one that is
  no longer used without losing the history attached to it.
- Check one item's stock position on demand, against its own reorder point, without reading it
  off a list.
- See the shape of the whole operation in one view: how many items, how many sites, how many
  items are low.
- Correct a movement that was recorded wrongly, including one recorded by someone else.

### What makes it hard today

The spreadsheet is the only record, and it is wrong. There is no moment at which the manager can
say "this is what we have" and be right. Low stock is discovered by a worker failing to pick it,
which is both the latest possible moment and the most expensive one. Deciding what to reorder is
guesswork dressed as a number.

---

## Warehouse floor worker

| | |
|---|---|
| **Context of use** | Standing, moving, on a shared device, often one-handed. Sessions are seconds long and repetitive. Needs a narrow, fast surface — not the same app the manager uses. |
| **Decision authority** | Reads everything organization-wide (**Global**), so they can find any item at any site. Creates and edits **only their own** movements (**Basic**). No delete on anything; no authority over sites. |

### Jobs to be done

- Find an item quickly — by name, from a list, while holding something else.
- Record that stock went out, against the item it came from, and know immediately whether it
  went through.
- Record that stock came in.
- See how many of an item are on hand right now, before promising any of it.
- Be stopped — clearly, with the numbers — when they try to take out more than exists, at the
  moment they try it rather than after the fact.

### What makes it hard today

Movements are written down after the event, on paper or from memory, and typed up later by
someone else. By the time the spreadsheet reflects a pick, the next pick has already happened
against the stale number. The worker is the person who discovers the shortfall and the person
least equipped to do anything about it.

---

## One persona, two depths

These two are genuinely different personas rather than one at two privilege levels — the context
of use differs, not just the authority, and that difference is what justifies a second app
surface rather than a second security role on the same app.

Where they *do* differ only in depth, it is on movements: the manager holds **Global** create,
write and delete; the worker holds **Basic** create and write and no delete. Same job, different
reach.

---

## What was inferred

- **Neither persona was elicited from a person.** Both are read from the two security roles in
  the build and from the problem statement, and reconciled against the two app surfaces that
  exist (a model-driven app for the desk, a standalone picking app for the floor).
- **"Shared device" is an inference** from the floor worker's task shape, not a stated
  requirement. It is the reason their surface is separate and narrow, so it is worth confirming.
- **The dashboard reader is the manager**, not a third persona. It sits in the manager's app and
  answers a manager's question; nobody else has a job that needs it.

## Worth resolving before the design is agreed

The problem statement says floor workers "should not be able to reshape the catalogue". The
security role does not agree: `Warehouse worker` holds **Global create and write on items**, so a
worker can today add an item to the catalogue and edit any item at any site. Only delete and
location-editing are actually withheld.

Either the statement is too strong or the role is too generous. It matters, because the
authority column above is what a security role is generated from.
