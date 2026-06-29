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
| 10 | `CP10-move-configuration.ps1` | Configuration data migration (CMT) |
| 11 | `CP11-extend-branch-policies-build-checks.ps1` | Require build check on PRs |
| 12 | `CP12-automate-testing.ps1` | BDD UI test project + (manual) test workflow |

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
