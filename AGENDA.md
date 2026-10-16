# The day

Sunday, October 25 · 9:00 AM to 3:55 PM

Each block is a topic with one outcome. The checkpoint column points at the exercise, so the
scripts can change without the agenda changing.

| Time | # | Topic | You leave with | Checkpoints |
|---|---|---|---|---|
| 9:00–9:25 AM | 01 | The case and your workspace | The warehouse case, your Codespace, signed in to GitHub, Power Platform and Azure | CP01 |
| 9:25–10:05 AM | 02 | Data model | Dataverse tables and solutions, kept as source | CP02, CP06 |
| 10:05–10:15 AM | | *Coffee break* | | |
| 10:15–11:05 AM | 03 | Business rules on the server | Plugins that block illegal transactions and subtract stock | CP07 |
| 11:05 AM–12:00 PM | 04 | Security and your first deploy | Two security roles, deployed to Dev, one role edited in Dev and pulled back to source | CP08, CP10 |
| 12:00–12:45 PM | | *Lunch* | | |
| 12:45–1:40 PM | 05 | Frontend | A model-driven app and a React code app for warehouse picking | CP09 |
| 1:40–2:30 PM | 06 | Automated testing | Plugin and script unit tests, and BDD scenarios run with Playwright | CP14, CP15 |
| 2:30–2:40 PM | | *Coffee break* | | |
| 2:40–3:10 PM | 07 | External data | A custom connector and barcode lookup in the code app | CP11 |
| 3:10–3:30 PM | 08 | Background jobs | A cloud flow that runs without a user | Pending (draft PR #40) |
| 3:30–3:55 PM | 09 | Wrap-up: what you hand the agent | What to hand the agent and what to check yourself | |

## Before the day (facilitator or Terraform track)

These are slow and mostly waiting on builds and provisioning, so they are not live time.
CP10 and CP11 need the Dev environment from CP04, and CP10 needs the roles from CP08.

- CP03: branch protection on main
- CP04: Dev and Test environments (or the Terraform alternative, PR #36)
- CP05: OIDC service principal and deploy workflow
- CP13: required build check on pull requests

## Order matters

- Security (CP08) comes before the first deploy (CP10), because CP10 pulls the security solution back from Dev.
- The first deploy happens before the frontend, so attendees see source become a running environment early.
- CP12 (configuration data) is a take-home extra.

## Open items

- A custom API block (server functions and transactions) has no script yet, so it is not scheduled.
- Block 08 depends on the cloud flow checkpoint (draft PR #40). Until it merges, treat it as a demo.
- Block 07 is tight: CP11 has four stages in 30 minutes.
- Open PRs #49 (CP16 and CP17, test-planning agents) and #50 (code app rebuild) may change blocks 05 and 06.
