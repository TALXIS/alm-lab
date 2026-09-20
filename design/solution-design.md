# Solution design — Warehouse Management

Designed against the workspace in this repository, from the problem statement in
[PROMPT.md](PROMPT.md) and the cast in [personas.md](personas.md).

---

## Context

A distribution company stores goods across several sites and runs the operation on a shared
spreadsheet nobody trusts. Two consequences are worth fixing: goods get promised that are not
there, and nobody notices stock running out until it has.

The system replaces the spreadsheet with a record where **the on-hand quantity is derived, never
typed** — it moves only because a movement was recorded — and where an attempt to take out more
than exists is refused at the moment it is attempted.

Two personas, [already modelled as security roles](personas.md): the **warehouse manager** at a
desk, who owns the catalogue and the sites; and the **warehouse floor worker** on a shared
device, who records movements and nothing else.

---

## Existing

A full TALXIS workspace exists. Nothing in this design is greenfield — every requirement below
is classified against what is already here.

| Project | Type | What it holds |
|---|---|---|
| `Solutions.DataModel` | Solution | The three tables, their columns, relationships, views and forms |
| `Solutions.Logic` | Solution | The two plug-in registrations |
| `Solutions.Security` | Solution | `Warehouse manager`, `Warehouse worker` |
| `Solutions.UI` | Solution | The model-driven app, its sitemap, the lookup views, the grid control binding |
| `Plugins.Warehouse` | Plugin | `ValidateWarehouseTransactionPlugin`, `SubtractQuantityPlugin` |
| `Scripts.UI` | ScriptLibrary | Grid customisation, form handlers, the ribbon action |
| `Apps.WarehousePicking` | CodeApp | The floor worker's standalone SPA |
| `GenPages.Dashboard` | GenPage | The manager's dashboard |
| `Packages.Main` | PDPackage | Deployment unit: the four solutions plus seed data |

Publisher prefix `almlab`. Tables: `almlab_warehouseitem`, `almlab_warehouselocation`,
`almlab_warehousetransaction` — matched exactly, not by substring.

Relationships, both 1:N:

- `almlab_warehouselocation` → `almlab_warehouseitem` via `almlab_locationid`
- `almlab_warehouseitem` → `almlab_warehousetransaction` via `almlab_itemid`

### How each requirement classifies

| Requirement | Verdict | Why |
|---|---|---|
| Catalogue of items | **Reuse** | `almlab_warehouseitem` carries every stated attribute |
| Sites | **Reuse** | `almlab_warehouselocation`, with `almlab_isactive` for retirement without deletion |
| Movements as records | **Reuse** | `almlab_warehousetransaction`, typed Inbound/Outbound |
| Reject an oversized withdrawal | **Reuse** | `ValidateWarehouseTransactionPlugin`, pre-validation |
| On-hand follows movements | **Reuse** | `SubtractQuantityPlugin`, post-operation |
| Low stock visible in lists | **Reuse** | Grid customiser paints cells at or below reorder point |
| Desk surface | **Reuse** | Model-driven app `almlab_warehouseapp` |
| Floor surface | **Reuse** | Code app, separate from the model-driven app |
| Totals at a glance | **Reuse** | Generative page, first in the sitemap |
| **Rules hold on edit, not only on create** | **Extend** | Both plug-in steps are registered on Create only — see Open questions |

---

## Jobs to be done

| # | Persona | Job |
|---|---|---|
| J1 | Manager | Maintain the catalogue of items |
| J2 | Manager | Maintain the list of sites, retiring one without losing its history |
| J3 | Manager | Set the reorder point per item and see which items have reached it |
| J4 | Manager | Check one item's stock position against its reorder point on demand |
| J5 | Manager | See the shape of the whole operation in one view |
| J6 | Manager | Correct a movement recorded by anyone |
| J7 | Worker | Find an item quickly on a shared device |
| J8 | Worker | Record stock going out, and be refused if there is not enough |
| J9 | Worker | Record stock coming in |
| J10 | Worker | See how many of an item are on hand before promising any |

---

## Data model

### `almlab_warehouseitem`

| Column | Type | Serves |
|---|---|---|
| `almlab_name` *(required)* | Text | J1, J7 |
| `almlab_sku` *(required)* | Text | J1, J7 — the code people actually search by |
| `almlab_category` | Choice — Electronics, Clothing, Food, Hardware, Other | J1 |
| `almlab_availablequantity` *(required)* | Whole number | J8, J10 — **derived; only a movement changes it** |
| `almlab_reorderpoint` | Whole number | J3 — the threshold the low-stock signal compares against |
| `almlab_unitprice` | Currency | J1 |
| `almlab_barcode` | Text | J7 |
| `almlab_weight` | Decimal | J1 |
| `almlab_isperishable` | Yes/No | J1 |
| `almlab_expirationdate` | Date | J1 |
| `almlab_description` | Multiline text | J1 |
| `almlab_locationid` | Lookup → location | J1, J5 |

### `almlab_warehouselocation`

| Column | Type | Serves |
|---|---|---|
| `almlab_name` *(required)* | Text | J2 |
| `almlab_address` | Text | J2 |
| `almlab_capacity` | Whole number | J2 |
| `almlab_isactive` | Yes/No | J2 — retire a site without deleting its items' history |
| `almlab_notes` | Multiline text | J2 |

### `almlab_warehousetransaction`

| Column | Type | Serves |
|---|---|---|
| `almlab_name` *(required)* | Text | J6 |
| `almlab_itemid` *(required)* | Lookup → item | J8, J9 |
| `almlab_transactiontype` *(required)* | Choice — Inbound, Outbound | J8, J9 |
| `almlab_quantity` *(required)* | Whole number | J8, J9 |
| `almlab_transactiondate` *(required)* | Date | J8, J9 |
| `almlab_referencenumber` | Text | J6 |
| `almlab_totalvalue` | Currency | J6 |
| `almlab_notes` | Multiline text | J8 |
| `almlab_isprocessed` | Yes/No | — **no job claims this; see Open questions** |
| `almlab_processedby` | Text | — **likewise** |

---

## Logic

| Behaviour | Runs where | Why there |
|---|---|---|
| Item name, SKU and quantity are mandatory; movement needs item, type, quantity and date | **Configuration** | Required-level flags. Nothing here needs code. |
| Category and movement type are fixed sets | **Configuration** | Local choices on the columns. |
| **An outbound movement may not exceed what is on hand** | **Backend** — plug-in, **pre-validation** (stage 10, sync) | The rule has to hold for the model-driven app, the code app, the Web API and any import alike. Pre-validation because the right outcome is *rejection before anything is written* — and the message carries both numbers, so the worker learns how short they are: `Not enough product in stock. Available: {n}, requested: {m}.` |
| **On-hand follows the movement** — inbound adds, outbound subtracts | **Backend** — plug-in, **post-operation** (stage 40, sync) | Two writes that must not diverge. Post-operation so the movement exists before the item is adjusted; synchronous so the number is right the instant the worker looks at it. |
| Low stock is visible wherever items are listed | **Frontend** — grid customiser | Presentation, not a rule. Cells at or below the reorder point are painted; items with no reorder point fall back to 10. Never the enforcement of anything. |
| Movement date defaults to today | **Frontend** — form `onLoad` | Saves a keystroke on the surface where a person is typing. The column stays required, so the default is a convenience, not the guarantee. |
| Check an item's level against its reorder point on demand | **Frontend** — ribbon button on the item form | Answers a question; changes nothing. J4. |
| Quantity column reads "Qty on hand" | **Frontend** — column interceptor | Wording, in one place, rather than renamed per view. |

**Nothing is enforced only in the frontend.** Both rules that matter live in plug-ins; the
scripts exist to make the surface pleasant, and the code app is protected by the same two
plug-ins without shipping a line of validation itself.

---

## User flows

### J1 · Maintain the catalogue — *manager, model-driven app*
Warehouse Items → grid → open or new → main form → save. Low-stock rows are already tinted in
the grid, so the items needing attention surface without a filter.

### J2 · Maintain sites — *manager, model-driven app*
Warehouse Locations → grid → open or new → main form. Retiring a site clears `almlab_isactive`
rather than deleting the record, so the items that reference it keep their history.

### J3 · Set reorder points and see what has reached them — *manager*
Item form → reorder point → save. Thereafter any grid listing that item paints its quantity when
it is at or below the point. The dashboard counts them.

### J4 · Check one item's stock position — *manager*
Item form → **Check Stock Levels** on the command bar → a dialog states the level and whether it
is above or below the reorder point.

### J5 · See the whole operation — *manager, dashboard*
Dashboard (first in the sitemap, its own group) → three totals — items, sites, items low on
stock — above a table of the stock itself with the low rows marked.

### J6 · Correct a movement — *manager*
Warehouse Transactions → open → amend → save. **The correction does not re-run either rule** —
see Open questions.

### J7 · Find an item — *worker, code app*
Open the app → item list → tap through to the item.

### J8 · Record stock going out — *worker, code app*
Item detail → New transaction → type Outbound, quantity, date → submit. Enough stock: the
movement is created and on-hand drops. Not enough: the write is refused and the message names
the available and requested quantities.

### J9 · Record stock coming in — *worker, code app*
The same dialog with type Inbound. No validation applies; on-hand rises.

### J10 · See what is on hand — *worker, code app*
Item detail shows the current quantity, read after each movement rather than cached.

---

## Out of scope

Purchase orders, suppliers, replenishment workflow. Picking routes and bin-level positions
within a site. Barcode scanning hardware — the barcode is stored, not read. Costing beyond a
unit price and a movement's total value. Shipping and customers. Stock-takes and adjustments
that are not a movement.

---

## Open questions

1. **Both plug-in steps are registered on Create only.** Confirmed from the step definitions:
   `Create of almlab_warehousetransaction`, stages 10 and 40. Editing a saved movement therefore
   neither re-validates it nor adjusts on-hand. Combined with the worker's **Basic write** on
   movements, a worker can record an outbound of 1 against an item holding 1, then edit it to
   1000: no rejection, and the item's quantity never moves. Either movements become immutable
   once saved, or both steps gain an Update registration with a pre-image to work out the delta.
   **This is the most significant gap in the design.**
2. **`almlab_isprocessed` and `almlab_processedby` serve no job.** Nothing reads or writes them.
   They are either the residue of a workflow that was never built, or a requirement nobody wrote
   down. Columns with no job are how a data model rots.
3. **The worker's authority is broader than stated.** The problem statement says workers should
   not reshape the catalogue; `Warehouse worker` holds **Global create and write on items**.
   Either loosen the statement or tighten the role.
4. **Does an expiry date block a movement of perishable goods, or only warn?** The columns exist;
   no rule references them.
5. **Should a worker see other workers' movements?** They currently read all movements
   organization-wide but may only write their own. That may be deliberate or may be an oversight.
6. **Is a stock-take a third movement type, or something else?** Listed out of scope, but the
   moment a physical count disagrees with the system, someone needs an answer.
