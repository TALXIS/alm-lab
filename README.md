# Power Platform Developer ALM Lab
Power Platform with source-first ALM: a monorepo, ephemeral Dev/Test environments,
trunk-based development, PR quality gates and GitHub Actions deployments.

## Start here

1. **Fork** this repo to your personal GitHub account (top-right **Fork** button).
2. On **your fork** (`https://github.com/<you>/alm-lab`), click **Code → Codespaces → Create codespace on main**.
   All tools are preinstalled. The Codespace and free GitHub Actions minutes run on *your* account.

   > ⚠️ Don't use a "one-click" badge that points at `TALXIS/alm-lab` — that starts the Codespace on the parent repo, where you can't push and your free minutes won't apply. Always launch from your own fork.

3. Wait for VS Code to load in the browser. Open a terminal (Ctrl+`) — you're in PowerShell.
4. Work through the **Checkpoints** below, starting with `CP01`. CP01 is the only one you
   truly must run first — it's the step that signs you in. After that, every checkpoint
   checks its own prerequisites (both `.lab-state.json` and this machine's live CLI
   sessions) before doing anything, so re-running a checkpoint that already succeeded is
   safe, and you can jump ahead or skip one you don't need. If a checkpoint can't find
   something it needs, it tells you exactly which earlier checkpoint to (re-)run. Not sure
   where you left off? Run `.lab-scripts/lab-status.ps1` for a summary.

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
| 09 | `CP09-implement-ui.ps1` | Model-driven app, sitemap, forms, views, grid PCF, warehouse picking code app |
| 10 | `CP10-deploy-and-sync.ps1` | Deploy to Dev & pull changes back |
| 11 | `CP11-integrate-external-data.ps1` | Product table + Item lookup (step 1 of external data integration — connector and UI land in later updates) |
| 12 | `CP12-move-configuration.ps1` | Configuration data migration (CMT) |
| 13 | `CP13-extend-branch-policies-build-checks.ps1` | Require build check on PRs |
| 14 | `CP14-automate-ui-testing.ps1` | BDD UI test project + (manual) test workflow |
| 15 | `CP15-implement-unit-tests.ps1` | Plugin (FakeXrmEasy) + script (Jest) unit tests |
| 16 | `CP16-plan-tests-with-agent.ps1` | Agent plans new `.feature` files against the existing bindings catalog |
| 17 | `CP17-explore-blackbox-and-generate-tests.ps1` | Agent forbidden from reading source explores the running apps and proposes its own tests |

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

## Resuming on a different machine

`.lab-state.json` travels with the repo, but auth sessions and CLI profiles (gh/txc/az)
live on whatever machine you're on right now — they don't come along with a `git clone`.
To pick up the lab on a fresh Codespace, VM, or after a crash:

1. Clone the repo (or open a new Codespace on your fork).
2. If you want to resume from a specific checkpoint rather than the latest commit:
   `git checkout <tag>` (e.g. `git checkout cp07`).
3. Run `.lab-scripts/lab-status.ps1` — it reports which checkpoints are done according to
   `.lab-state.json` and git tags, and whether this machine's own `gh`/`txc`/`az` sessions
   actually match what lab-state expects (a mismatch here is the most common reason a
   checkpoint fails partway through instead of at the top with a clear message).
4. Re-run CP01 if `lab-status.ps1` flags missing/mismatched auth, then continue with
   whichever checkpoint it names as next.

## Running the tests in VS Code

`.vscode/extensions.json` recommends the extensions that put the three suites in the Testing
panel: C# Dev Kit for the plugin and UI tests, and the Jest extension for `src/Tests.Scripts`
(those tests are Jest, not .NET, so the .NET provider will never find them).

The Gherkin scenarios appear as ordinary .NET tests — Reqnroll generates one `[TestMethod]` per
scenario into a `*.feature.cs` at build time, so **build once before expecting scenarios to show
up**, and rebuild after editing a `.feature` file.

> ⚠️ **macOS: C# Dev Kit cannot use Homebrew's .NET.** If `dotnet` came from `brew`, the Testing
> panel stays empty and Dev Kit claims "a supported .NET 10 SDK is not installed" however new your
> SDK is. Two separate problems hide behind that one message, and only the second is fatal:
>
> 1. `/opt/homebrew/bin/dotnet` is a wrapper script that sets `DOTNET_ROOT` and execs the real host
>    under `libexec/`. Dev Kit inspects paths rather than running it, looks for an `sdk/` next to
>    `bin/dotnet`, finds none, and refuses to select the host.
> 2. Get past that and the server fails to load Homebrew's `libhostfxr.dylib` outright:
>
>    ```
>    code signature ... not valid for use in process:
>    mapping process and mapped file (non-platform) have different Team IDs
>    ```
>
>    Dev Kit's server runs with hardened runtime and library validation, so macOS will only map
>    libraries signed by the same Team ID. Homebrew's .NET is **ad-hoc signed**
>    (`TeamIdentifier=not set`); Microsoft's is signed `UBF8T346G9`. Check an install with
>    `codesign -dvvv <dotnet-root>/host/fxr/*/libhostfxr.dylib`. No configuration fixes this.
>
> Install a Microsoft-signed SDK without admin rights, point Dev Kit at it in your **user**
> `settings.json` (not this repo's — the path is machine-specific), and **fully restart VS Code**;
> a window reload is not enough, because the extension host reads this once at launch:
>
> ```bash
> curl -fsSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh
> ./dotnet-install.sh --channel 10.0 --install-dir "$HOME/.dotnet" --no-path
> ```
>
> ```jsonc
> "dotnetAcquisitionExtension.existingDotnetPath": [
>   { "extensionId": "ms-dotnettools.csdevkit", "path": "/Users/<you>/.dotnet/dotnet" },
>   { "extensionId": "ms-dotnettools.csharp",   "path": "/Users/<you>/.dotnet/dotnet" }
> ]
> ```
>
> `/usr/local/share/dotnet` (the official `.pkg` location) is signed correctly too, but Dev Kit's
> floor is SDK **10.0.400** — an older official install there is refused with the same misleading
> message. Homebrew's `dotnet` can stay the one on your `PATH`; this setting only governs the host
> the extensions themselves run on.
>
> Throughout all of it `dotnet test` from a terminal works — the suites are fine, only Dev Kit's
> discovery is affected.

Browser scenarios additionally need a signed-in Playwright storage state; see
[src/Tests.UI/README.md](src/Tests.UI/README.md).

## Developing this lab

See [LOCAL-DRY-RUN.md](LOCAL-DRY-RUN.md) to run the checkpoints locally, without forking to
GitHub or provisioning real infrastructure.
