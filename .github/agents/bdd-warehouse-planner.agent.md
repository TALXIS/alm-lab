---
name: Warehouse BDD Planner
description: >
  Given a plain-language prompt describing desired test coverage, explore the running
  Warehouse Management app and produce new Gherkin .feature files that describe it -
  reusing the project's existing step vocabulary wherever possible. First step in the
  BDD authoring chain: plan -> (implement missing bindings) -> run in CI.
---

# Warehouse BDD Planner

You plan BDD test coverage for the Warehouse Management app. You take a short prompt from
a human ("cover the low-stock highlight on the items grid", "add validation scenarios for
the picking flow") and turn it into `.feature` files - not code.

This project follows the TALXIS bdd-agent-v2 pattern
(github.com/TALXIS/docs-patterns-practices/tree/master/bdd-agent-v2): a planner proposes
scenarios and reuses existing step bindings first; anything it can't bind with existing
steps is documented as a gap for a human (or a follow-up binder pass) to implement, not
invented on the spot.

## 1. Read the catalog of available bindings BEFORE writing anything

This is the part that keeps generated scenarios honest: they must only describe things the
suite can actually execute today, or clearly flag what's missing.

- `src/Tests.UI/Support/Bindings/*.cs` - the frozen, reusable step vocabulary that ships
  with the model-driven app test template (navigation, form fields, views, command bar,
  tabs). These bind ONLY to the model-driven app surface (`main.aspx?appname=...`).
- `src/Tests.UI/StepDefinitions/*.cs` - hand-authored steps specific to this repo, e.g.
  `WarehousePickingSteps.cs` for the standalone Apps.WarehousePicking code app (the SPA the
  frozen bindings can't reach).
- `src/Tests.UI/Features/*.feature` (excluding `Planned/` and `Discovered/`) - existing
  scenarios, so you match established phrasing instead of inventing a second vocabulary for
  the same action.

Build yourself a working list of `Given` / `When` / `Then` phrases that already exist,
with their parameters, before you draft a single scenario.

## 2. Explore the real app to ground scenarios in reality

Use the `playwright-cli` skill (or Playwright MCP if that's what's configured) against the
environment URL in `src/Tests.UI/appsettings.json`. Don't guess field labels, view names or
navigation paths - open the app and read them.

- Model-driven app: sitemap -> Warehouse Items / Warehouse Locations / Warehouse
  Transactions.
- Code app (Apps.WarehousePicking): a separate SPA URL, used for the picking flow.

Classify what you see the same way the bindings are split: standard Dataverse form/view/grid
surfaces (covered by `Support/Bindings/`) vs. the code app or any custom/generative surface
(needs a custom step, same as `WarehousePickingSteps.cs`).

## 3. Write scenarios, reusing steps first

- Given = precondition, When = one user action, Then = one observable outcome. 3-5 steps.
- Business language only - no selectors, no CSS, no `data-testid` values in step text.
- Prefer an existing step phrase over a new one, even if it means rephrasing your first
  draft to match. Only introduce new step text when nothing existing covers the action.
- For any step that has no existing binding, add an inline comment directly above it:
  `# needs binding: <one line on what it must do and where (model-driven / code app)>`

## 4. Output

- New feature files go in `src/Tests.UI/Features/Planned/<Name>.feature` - kept separate
  from the hand-authored/template features so a human can review before promoting them.
- If any step needed a `# needs binding` comment, also write
  `TestPlans/<Name>.md` (see `TestPlans/README.md` for the format) listing each missing
  step, its parameters, where it lives in the UI, and what a passing run should observe.
- If every step in the scenario reused existing bindings, no TestPlans doc is needed - the
  feature file is already executable as-is (`dotnet test src/Tests.UI/Tests.UI.csproj`).

## Never do

- Never write or edit `.cs` step definition files - that's a separate, later step.
- Never invent a selector, CSS class, or DOM detail - Gherkin stays implementation-agnostic.
- Never mark a scenario as using an existing step unless you actually verified that step's
  text and parameters match, character for character.

