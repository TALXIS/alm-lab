# The day

Sunday, October 25 · 9:00 AM to 3:55 PM

Each block is a topic with one outcome. The checkpoint column points at the exercise, so the
scripts can change without the agenda changing.

| Time | # | Topic | You leave with | Checkpoints |
|---|---|---|---|---|
| 9:00–9:25 AM | 01 | The case and your workspace | The warehouse case, your Codespace, signed in to GitHub, Power Platform and Azure | CP01 |
| 9:25–10:05 AM | 02 | Data model and security | Dataverse tables and solutions kept as source, plus two security roles on top | CP02, CP06, CP08 |
| 10:05–10:15 AM | | *Coffee break* | | |
| 10:15–11:05 AM | 03 | Business rules on the server | Plugins that block illegal transactions and subtract stock | CP07 |
| 11:05 AM–12:00 PM | 04 | Deploy and sync | The package deployed to Dev, one role edited in Dev and pulled back to source | CP10 |
| 12:00–12:45 PM | | *Lunch* | | |
| 12:45–1:40 PM | 05 | Frontend | A model-driven app and a React code app for warehouse picking | CP09 |
| 1:40–2:30 PM | 06 | External data | A custom connector and barcode lookup in the code app | CP11 |
| 2:30–2:40 PM | | *Coffee break* | | |
| 2:40–3:00 PM | 07 | Background jobs | A cloud flow that runs without a user | Pending (draft PR #40) |
| 3:00–3:40 PM | 08 | Automated testing | Plugin and script unit tests, and BDD scenarios run with Playwright | CP14, CP15 |
| 3:40–3:55 PM | 09 | Wrap-up: what you hand the agent | What to hand the agent and what to check yourself | |

## Before the day (facilitator or Terraform track)

These are slow and mostly waiting on builds and provisioning, so they are not live time.
CP10 and CP11 need the Dev environment from CP04.

- CP03: branch protection on main
- CP04: Dev and Test environments (or the Terraform alternative, PR #36)
- CP05: OIDC service principal and deploy workflow
- CP13: required build check on pull requests

## Order matters

- Security (CP08) is in block 02, ahead of Deploy and sync (CP10), which pulls the security solution back from Dev.
- The first deploy happens before the frontend, so attendees see source become a running environment early.
- All testing is in block 08, so it covers everything built earlier, including the connector and code app.
- CP12 (configuration data) is a take-home extra.

## Open items

- Block 02 is 40 minutes for two checkpoints. Security is short, but CP06 has three scaffolds.
- Block 04 is long on purpose: the package build and import take minutes of waiting, and it carries the managed versus unmanaged explanation.
- Block 07 depends on the cloud flow checkpoint (draft PR #40). Until it merges, treat it as a demo.
- Block 08 is 40 minutes for CP14 and CP15. Open PR #49 adds CP16 and CP17 (test-planning agents), which would not fit without more time.
- There is no custom API block because there is no script for it yet.
- Open PR #50 (code app rebuild) may change block 05.
