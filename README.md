# Power Platform Developer ALM Lab
Power Platform with source-first ALM: a monorepo, ephemeral Dev/Test environments,
trunk-based development, PR quality gates and GitHub Actions deployments.

## Start here

1. **Fork** this repo to your personal GitHub account (top-right **Fork** button).
2. On **your fork** (`https://github.com/<you>/alm-lab`), click **Code → Codespaces → Create codespace on main**.
   All tools are preinstalled. The Codespace and free GitHub Actions minutes run on *your* account.

   > ⚠️ Don't use a "one-click" badge that points at `TALXIS/alm-lab` — that starts the Codespace on the parent repo, where you can't push and your free minutes won't apply. Always launch from your own fork.

3. Wait for VS Code to load in the browser. Open a terminal (`Ctrl+\``) — you're in PowerShell.
4. Work through the **Checkpoints** below in order, starting with `CP01`.

> 💡 Each checkpoint script is fully commented — open it, read what it does, then run it.
> You can run them step-by-step (`F8` on selected lines) or all at once.

### Signing in (CP01)

`CP01` signs you in to everything up front: **GitHub** (`gh`), **Power Platform** (`txc`) and
**Azure** (`az`). Two of these use a **device code** — the terminal prints a code and a URL;
open it, paste the code, and approve. When prompted, allow the `workflow` scope for `gh` so
later checkpoints can install GitHub Actions on your fork.

## How each checkpoint works (PR flow)

Checkpoints don't push straight to `main` — they teach the real ALM loop. Each one:

1. Creates a branch and commits its changes.
2. Opens a **Pull Request** and prints the link.
3. **Pauses** — open the PR in your browser, review the diff and the running build check.
4. Press **Enter** to continue: it waits for the build check, squash-merges, and tags for rollback.

This is the slow, deliberate part — read the PR, watch the build go green, then merge. The
first time a checkpoint enables GitHub Actions you may be asked to **approve workflows on your
fork** — say yes.

## Checkpoints

| # | Script | Goal |
|---|--------|------|
| 01 | `CP01-check-machine-setup.ps1` | Verify all tools are installed |
| 02 | `CP02-create-repository-layout.ps1` | Monorepo layout (solution, src, NuGet) |
| 03 | `CP03-setup-continuous-integration.ps1` | Branch protection — gated PRs into main |
| 04 | `CP04-setup-runtime.ps1` | Create Dev + Test Dataverse environments |
| 05 | `CP05-setup-continuous-deployment.ps1` | OIDC service principal + deploy workflow |
| 06 | `CP06-implement-data-model.ps1` | Warehouse tables and columns |
| 07 | `CP07-implement-backend.ps1` | Plugins + logic solution |
| 08 | `CP08-implement-security.ps1` | Security roles |
| 09 | `CP09-implement-ui.ps1` | Model-driven app, sitemap, forms, views |
| 10 | `CP10-deploy-and-sync.ps1` | Deploy to Dev & pull changes back |
| 11 | `CP11-move-configuration.ps1` | Configuration data migration (CMT) |
| 12 | `CP12-extend-branch-policies-build-checks.ps1` | Require build check on PRs |
| 13 | `CP13-automate-testing.ps1` | BDD UI test project + (manual) test workflow |

Run a checkpoint:

```powershell
.lab-scripts/CP01-check-machine-setup.ps1
```

## Rollback

Every checkpoint commits, pushes, and tags its result. To roll back to an earlier checkpoint:

```powershell
git reset --hard cp05
git push --force
```

Your variables persist in `.lab-state.json` (committed), so you can resume on a fresh
Codespace even if your terminal crashes.

## Local dry-run for agents (no GitHub fork)

This section is for an AI coding agent (or a developer) that wants to exercise the lab's
git/PR/CI plumbing **without** forking to GitHub, without GitHub Codespaces, and without a
real `gh` login. It runs the same devcontainer image locally via Docker and short-circuits
every checkpoint's GitHub-specific calls behind `LAB_LOCAL_MODE=1`.

### 1. Build/run the devcontainer locally

The devcontainer uses `ghcr.io/talxis/tools-agentbox/image:latest` directly (see
`.devcontainer/devcontainer.json`) — there's no Dockerfile of our own to build. Plain Docker
is the simplest path:

```bash
docker run -it --rm \
  -v "$(pwd)":/workspaces/alm-lab \
  -w /workspaces/alm-lab \
  ghcr.io/talxis/tools-agentbox/image:latest \
  pwsh
```

Or, for closer parity with Codespaces (features/mounts honored), use the devcontainer CLI:

```bash
npm install -g @devcontainers/cli
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . pwsh
```

You should land in a `pwsh` shell with `dotnet`, `git`, `gh`, `pac`, `txc`, and `az` on `PATH`.

### 2. Initialize local-only git state (no GitHub)

Skip forking entirely. Inside the container/repo checkout:

```bash
git init   # if not already a repo
git config user.email "agent@local.test"
git config user.name  "alm-lab-agent"
git add -A && git commit -m "initial" --allow-empty
git branch -M main
```

Do **not** add a GitHub `origin` remote — `LAB_LOCAL_MODE` never pushes, so none is needed.

### 3. Run checkpoints in local mode

```bash
export LAB_LOCAL_MODE=1
export LAB_AUTO_MERGE=1   # belt-and-suspenders: also skip any interactive pause
pwsh ./.lab-scripts/CP01-check-machine-setup.ps1
pwsh ./.lab-scripts/CP02-create-repository-layout.ps1
pwsh ./.lab-scripts/CP03-setup-continuous-integration.ps1
```

Under `LAB_LOCAL_MODE=1`:

- `Save-Checkpoint` commits to a local `cpNN` branch, merges it into `main` with
  `git merge --no-ff`, and tags it — no push, no PR, no `gh pr` calls. Rollback still works
  exactly as documented above (`git reset --hard cpNN`).
- CP01 still verifies `dotnet`/`git`/`gh`/`pac`/`txc`/`az` are installed (they are, in the
  agentbox image), but skips the three interactive sign-ins to GitHub, Power Platform, and
  Azure.
- CP03's branch-protection ruleset and CP12's build-check requirement are **not** created
  against a real GitHub repo — each logs a `LAB_LOCAL_MODE: skipped — would...` line describing
  what it would have done, then continues.
- CP05's GitHub-only steps (`gh secret set`, enabling Actions, `gh auth refresh`) are skipped
  and logged the same way; the `build.yml`/`deploy.yml` workflow files are still copied into
  `.github/workflows/` locally so you can inspect them.

### 4. Where the smoke test stops

`CP04` (provisions real Dataverse Dev/Test environments via `txc`) and the Azure/Dataverse
portions of `CP05` (Entra app registration, OIDC federated credential, Dataverse
application-user assignment) call real cloud APIs with no local emulator — there is no way to
fake these. Treat failures there as expected: the goal of this dry run is to validate
CP01–CP03 and CP05's GitHub-shaped steps (secrets/workflow-file logic), not to complete a real
deployment. Stop once you've confirmed:

- CP01–CP03 run to completion and each leaves a `cpNN` tag,
- `.lab-state.json` accumulates the expected keys after each checkpoint,
- CP05's workflow files land in `.github/workflows/` and its "skipped" log lines appear where
  GitHub calls would have happened.
