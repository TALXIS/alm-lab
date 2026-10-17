# TestPlans

Output of the Warehouse BDD Planner agent (`.github/agents/bdd-warehouse-planner.agent.md`).

Each file here documents the step bindings a planned `.feature` file (under
`src/Tests.UI/Features/Planned/`) needs but doesn't have yet. A feature with no matching
file here was planned entirely from existing, already-executable step bindings.

## Format

```markdown
# <Feature name> - Missing Steps

## Steps to implement
- [ ] [When] I <action>, parameters: <name: type>
  - Located on: <page/app>, labeled "<label>"
  - Behavior: <what a passing run should observe afterward>

## Notes
- <auth, duplicate elements, anything the implementer should know>
```

## Workflow

1. Run the planner agent with a prompt describing what to cover. It writes the `.feature`
   file to `Features/Planned/` and, if needed, a matching doc here.
2. A developer (or a binder-style follow-up pass, see CP14's comments and
   github.com/TALXIS/docs-patterns-practices/tree/master/bdd-agent-v2) implements the
   missing steps in `src/Tests.UI/StepDefinitions/`.
3. Once every step in a planned feature has a binding, move the `.feature` file out of
   `Planned/` into `Features/` and delete its entry here.
