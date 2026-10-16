# The day

Sunday, October 25 · 9:00 AM to 3:55 PM

Each block is a topic with one outcome. The checkpoint column points at the exercise, so the
scripts can change without the agenda changing. "What we do" is the running record of each
block: fill in the notes column as the day goes.

| Time | # | Topic | What we do | You leave with | Checkpoints | Notes |
|---|---|---|---|---|---|---|
| 9:00–9:35 AM | 01 | Opening and setup | Introduce the warehouse case. Everyone forks the repo and starts a Codespace, which builds while we cover the core concepts (see below). Then run the prerequisites check (CP01) and sign in to GitHub, Power Platform and Azure with device codes. | The shared vocabulary for the day, a running Codespace with all tools verified, and all three services signed in | CP01 | |
| 9:35–10:15 AM | 02 | Data model and security | Scaffold the monorepo layout and the Package Deployer. Add the Location, Item and Transaction tables with their columns, all as code. Then add the Warehouse Manager and Worker security roles and explain privilege depth. | Dataverse tables and solutions kept as source, plus two security roles | CP02, CP06, CP08 | |
| 10:15–10:30 AM | | *Coffee break* | | | | |
| 10:30–11:15 AM | 03 | Business rules on the server | Write the plugins that block illegal transactions and subtract stock. Register them as SDK message processing steps in the Logic solution. | Plugins that enforce legal transactions | CP07 | |
| 11:15 AM–12:00 PM | 04 | Deploy and sync | Build the package and deploy it to Dev. Edit a security role in Dev and pull the change back to source. Discuss managed versus unmanaged solutions. | The package running in Dev, and the loop from source to environment and back | CP10 | |
| 12:00–12:45 PM | | *Lunch* | | | | |
| 12:45–1:40 PM | 05 | Frontend | Build the model-driven app with sitemap, forms, views, form scripts, ribbon and the Grid PCF. Then build the React code app for warehouse picking. | A model-driven app and a code app from the same repo | CP09 | |
| 1:40–2:30 PM | 06 | External data | Add the Product table, a custom connector to an external product catalog, and wire both into the code app with barcode lookup. | A custom connector and barcode lookup in the code app | CP11 | |
| 2:30–2:40 PM | | *Coffee break* | | | | |
| 2:40–3:00 PM | 07 | Background jobs | Show a cloud flow that runs without a user. | A flow running in the background | Pending (draft PR #40) | |
| 3:00–3:40 PM | 08 | Automated testing | Run the plugin unit tests with FakeXrmEasy and the script tests with Jest. Run BDD scenarios with Playwright against the app. | Unit tests and BDD scenarios passing | CP14, CP15 | |
| 3:40–3:55 PM | 09 | Wrap-up: what you hand the agent | Review what was built. Discuss what to hand to an agent and what to check yourself. | A shared view of where agents help and where you still verify | | |

## Block 01 running order

| Minutes | Segment |
|---|---|
| 9:00–9:05 | Fork the repo and start the Codespace. It builds in the background during the next segment. |
| 9:05–9:20 | Concepts (below) |
| 9:20–9:35 | Prerequisites check and sign-in (CP01) |

### Concepts to introduce

Each one is a sentence or two, tied to something attendees will touch that day.

- **LLM:** the model that reads and writes text and code. It only knows what is in its context.
- **Agent:** an LLM in a loop that can read files, run commands and call tools to reach a goal.
- **Harness:** the program around the model that supplies the tools, permissions and context, and runs the loop. The agent is only as capable as its harness.
- **Skills:** packaged instructions the agent loads when a task matches, such as how to add a plugin or a table in this workspace.
- **Agent plugins:** bundles of skills, tools and commands installed into the harness, so the agent has the team's way of working.
- **Codespaces:** the cloud dev machine with every tool preinstalled. Each attendee gets the same environment, on their own account.
- **Power Platform resources:** environments, solutions, tables, plugins, security roles, apps and connectors. What each is, which live in source and which only in an environment.
- **Steering agents:** how you control the work. Give the goal and constraints up front, use instructions files and skills for standing rules, and review the plan before it runs. Keep changes small in a branch and PR, and let the build and tests act as the gate. Check the diff yourself.

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

- Block 01 is tight: five minutes to start the Codespace, fifteen for concepts and fifteen for CP01 including the device-code sign-ins. If it runs over, take ten minutes from block 06 (External data), where CP11 has the most slack.
- Block 02 is 40 minutes for three checkpoints. Security is short, but CP06 has three scaffolds.
- Block 07 depends on the cloud flow checkpoint (draft PR #40). Until it merges, treat it as a demo.
- Block 08 is 40 minutes for CP14 and CP15. Open PR #49 adds CP16 and CP17 (test-planning agents), which would not fit without more time.
- There is no custom API block because there is no script for it yet.
- Open PR #50 (code app rebuild) may change block 05.
