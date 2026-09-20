# Design

What the Warehouse Management solution is for, written the way it should have been written
before any of it was built — and used here to show what feature files look like when they come
first.

Produced by the [`design`](https://github.com/TALXIS/skills) plugin, `personas` → `spec` →
`features`. Nothing here is executable and nothing here was scaffolded; these are documents.

| File | Skill | What it settles |
|---|---|---|
| [PROMPT.md](PROMPT.md) | — | The input. The problem, stated without reference to Dataverse |
| [personas.md](personas.md) | `design:personas` | Who the system is for, and how much authority each holds |
| [solution-design.md](solution-design.md) | `design:spec` | Data model, where each behaviour runs, one flow per job |
| [features/](features/) | `design:features` | What "done" means — one `.feature` per job |

## Why these are not in `src/Tests.UI`

They are acceptance criteria, not a test suite. They carry no step bindings and no project, and
`design:features` deliberately writes Gherkin only — `implement:test` is what turns them into
something that runs.

Keeping them apart also keeps the comparison below honest.

## Traceability

All ten jobs in `solution-design.md` have a feature. None was skipped.

| Job | Feature | Covered by the suite in `src/Tests.UI` today |
|---|---|---|
| J1 Maintain the catalogue | `J01-maintain-the-catalogue` | Navigation only — nothing adds or edits an item |
| J2 Maintain sites | `J02-maintain-sites` | Navigation only — retiring a site is untested |
| J3 Reorder points and low stock | `J03-reorder-points-and-low-stock` | **No** |
| J4 Check an item's stock position | `J04-check-an-items-stock-position` | **Yes** — implemented as `Features/CheckStockPosition.feature` |
| J5 See the whole operation | `J05-see-the-whole-operation` | **No** — the dashboard has no scenario at all |
| J6 Correct a movement | `J06-correct-a-movement` | **No** |
| J7 Find an item | `J07-find-an-item` | Yes — the picking app's background and item step |
| J8 Record stock going out | `J08-record-stock-going-out` | Yes, from the floor app. **Not** from the desk app |
| J9 Record stock coming in | `J09-record-stock-coming-in` | **No** — only outbound is exercised |
| J10 See what is on hand | `J10-see-what-is-on-hand` | Yes — the quantity assertion after a pick |

Four jobs of ten are genuinely covered — J4 was taken from this folder and implemented, and the
feature file moved across unchanged. Two more are covered only as far as reaching the right
screen. **That gap is the argument for writing these first**: the implemented suite was written
against what had been built, so it tests the things that were easy to reach from a sitemap, and
it has no opinion at all about the dashboard, the reorder point or a delivery arriving.

## The scenarios that are meant to fail

`J06-correct-a-movement` carries two scenarios tagged `@open-question`. They state what the
design says should be true, and neither holds: both business rules are registered on **create**
only, so editing a saved movement re-validates nothing and adjusts nothing. A worker may record
an outbound of one and then edit it to a thousand.

They are written down rather than left out, because a feature file is exactly where a rule that
nobody implemented should become visible. Open question 1 in `solution-design.md` has the detail.

## What this design found

Writing the design against the built solution surfaced three things the code does not say out
loud:

1. **Neither business rule survives an edit** — the gap above.
2. **`almlab_isprocessed` and `almlab_processedby` serve no job.** Nothing reads or writes them.
3. **The `Warehouse worker` role is broader than intended** — Global create and write on items,
   where the statement of the problem says workers should not reshape the catalogue.
