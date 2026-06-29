# Developer ALM Lab — Power Platform on GitHub + GitHub Actions

A hands-on lab for **EPPC26**. You'll role-play building a **Warehouse Management** app in
Power Platform with modern, source-first ALM: a monorepo, ephemeral Dev/Test environments,
trunk-based development, PR quality gates and OIDC-secured GitHub Actions deployments.

## Start here

1. **Fork** this repo to your personal GitHub account.
2. Open your fork in **GitHub Codespaces** (all tools are preinstalled):

   [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/TALXIS/alm-lab?quickstart=1)

3. Wait for VS Code to load in the browser. Open a terminal (`Ctrl+\``) — you're in PowerShell.
4. Work through the **Checkpoints** below in order.

> 💡 Each checkpoint script is fully commented — open it, read what it does, then run it.
> You can run them step-by-step (`F8` on selected lines) or all at once.

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
| 12 | `CP12-automate-testing.ps1` | Automated BDD UI tests in CI |

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
