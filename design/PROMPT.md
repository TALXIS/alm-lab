# Design prompt

The input given to the `design` plugin (`personas` → `spec` → `features`). Written as a
problem statement, the way it would have been stated before any of this was built — the
point of the exercise is that the `.feature` files come first and the code answers them.

Everything below is a restatement of what the Warehouse Management solution actually does,
in the language of the business rather than of Dataverse.

---

## The situation

A distribution company stores goods across more than one physical site — a main warehouse and
an overflow unit — and is running the whole operation on a shared spreadsheet.

Nobody trusts the numbers in it. Stock is counted when someone remembers to count it, and the
count is wrong again within a day because movements in and out are written down after the fact,
if at all. Two problems follow from that, and they are the ones worth fixing:

- **Goods are promised that are not there.** An order goes out against a quantity the
  spreadsheet claims exists. The shortfall is discovered on the floor, at the point of picking.
- **Nobody notices stock running out until it has.** There is no signal between "plenty" and
  "none", so restocking is reactive.

## Who is involved

**Warehouse managers** work at a desk. They own the catalogue of goods and the list of sites:
what is stocked, where it belongs, what it costs, and the level at which it should be
reordered. They need to see the state of the whole operation at a glance and to correct
anything in it.

**Warehouse floor workers** work standing up, on a shared device, usually with one hand. Their
job is narrow and repetitive: find an item, record that stock went out or came in, move on.
They should not be able to reshape the catalogue or remove records, and they should only be
able to work with the movements they themselves recorded.

## What the system has to do

Keep a catalogue of **items** — what each one is, its stock-keeping code, what category it
falls into, how many are on hand, the level at which it should be reordered, what it costs,
its barcode and weight, and whether it is perishable and therefore has an expiry date. Each
item sits at one **location**, and a location has an address, a capacity, and can be retired
without deleting its history.

Record every **movement** of stock as its own record: which item, whether it came in or went
out, how many, when, a reference number, and a note. A movement is the only way the on-hand
quantity changes — it is never edited directly.

### The rules that matter

1. **A movement out may never exceed what is on hand.** It is rejected, and the rejection says
   what was available and what was asked for, because the person recording it needs to know how
   short they are, not just that they were wrong.
2. **On-hand quantity follows from movements automatically.** Goods in add, goods out subtract.
   This has to hold no matter which surface recorded the movement.
3. **An item at or below its reorder point is visibly low on stock** wherever items are
   listed — not buried in a report someone has to go and run.

## What people need to be able to do

Managers, at a desk: browse and correct items, locations and movements; open one item and see
its stock position; check an item's level against its reorder point on demand; and open a
dashboard giving the totals — how many items, how many locations, and how many are low on
stock — beside a list of the stock itself with the low rows standing out.

Floor workers, on a shared device: a fast, task-focused app, separate from the desk one — list
the items, open one, record a movement against it, and be told immediately if there is not
enough stock to cover it.

## Out of scope

Purchase orders, suppliers and replenishment workflow. Picking routes and bin-level locations
within a site. Barcode scanning hardware. Costing beyond a unit price and a movement's total
value. Anything to do with shipping or customers.

## Known unknowns

- Whether stock counts ever need correcting outside a movement (a stock-take), and if so
  whether that is a third movement type or something else entirely.
- Whether an expiry date should block a movement of perishable goods, or only warn.
- Whether a worker should see movements recorded by other workers, or only their own.
