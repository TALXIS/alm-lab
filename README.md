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

### 1. Install Docker (plain Ubuntu host)

If you're starting from a bare Ubuntu machine (no Docker preinstalled), set up the Docker
Engine apt repo and install it:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Start the daemon and confirm it's running (on a systemd host `sudo systemctl enable --now
docker` also works; some containerized/sandboxed hosts have no systemd, so start `dockerd`
directly instead):

```bash
sudo systemctl enable --now docker 2>/dev/null || sudo dockerd > /tmp/dockerd.log 2>&1 &
sleep 3
docker info
```

Run `docker` without `sudo` for the rest of this section by adding your user to the `docker`
group (`sudo usermod -aG docker $USER`, then start a new shell) — or just keep prefixing
`sudo` on the `docker` commands below.

### 2. Build/run the devcontainer locally

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

### 3. Initialize local-only git state (no GitHub)

Skip forking entirely. Inside the container/repo checkout:

```bash
git init   # if not already a repo
git config user.email "agent@local.test"
git config user.name  "alm-lab-agent"
git add -A && git commit -m "initial" --allow-empty
git branch -M main
```

Do **not** add a GitHub `origin` remote — `LAB_LOCAL_MODE` never pushes, so none is needed.

### 4. Run checkpoints in local mode

```bash
export LAB_LOCAL_MODE=1
export LAB_AUTO_MERGE=1   # belt-and-suspenders: also skip any interactive pause
export LAB_AUTO=1         # skip CP10's "make manual changes" pause
for cp in .lab-scripts/CP*.ps1; do pwsh "$cp"; done
```

`LAB_LOCAL_MODE=1` runs the **entire CP01–CP13 chain to completion without provisioning any
real infrastructure** — no GitHub fork, no Power Platform tenant, no Azure subscription:

- `Save-Checkpoint` commits to a local `cpNN` branch, merges it into `main` with
  `git merge --no-ff`, and tags it — no push, no PR, no `gh pr` calls. Rollback still works
  exactly as documented above (`git reset --hard cpNN`).
- CP01 still verifies `dotnet`/`git`/`gh`/`pac`/`txc`/`az` are installed (they are, in the
  agentbox image), but skips the three interactive sign-ins to GitHub, Power Platform, and
  Azure.
- CP03's branch-protection ruleset, CP05's GitHub-only steps (`gh secret set`, enabling
  Actions, `gh auth refresh`), and CP12's build-check requirement are **not** created against
  a real GitHub repo — each logs a `LAB_LOCAL_MODE: skipped — would...` line describing what
  it would have done, then continues. The `build.yml`/`deploy.yml`/`test.yml` workflow files
  are still written to `.github/workflows/` locally so you can inspect them.
- CP04 doesn't provision real Dataverse Dev/Test environments — it stubs `devEnvUrl`/
  `testEnvUrl` with unreachable `*.stub.invalid` placeholders so every later checkpoint that
  only checks for their *presence* keeps working.
- CP05's Azure/Dataverse steps (Entra app registration, OIDC federated credential, adding the
  SP as a Dataverse application user) are skipped and logged the same way, using stub
  `tenantId`/`appId` values.
- CP06–CP09 (data model, backend, security, UI) are **real** — they scaffold actual source
  files via the TALXIS DevKit CLI and run `dotnet build`; nothing about them is Dataverse- or
  GitHub-dependent, so they work identically to a real run.
- CP10 still runs the **real** `dotnet publish` to build the deployment package (this needs no
  live environment), but skips `txc env pkg import` (deploy to the stub Dev URL) and
  `txc env solution pull`.
- CP11 still writes the **real** `data_schema.xml` CMT schema file, but skips `txc data pkg
  export`/`import` — there's no live Dev environment to export records from, so no `data.xml`
  is produced.
- CP13's BDD test project scaffolds and builds for real; only the Playwright browser download
  can fail if this host's outbound HTTPS is intercepted by a TLS-inspecting proxy whose CA
  Node.js doesn't trust (see note below) — the script logs this as a non-fatal warning and
  still completes the checkpoint.

### 5. A note on corporate/sandboxed network proxies

If your host intercepts outbound HTTPS (common in corporate networks or nested sandboxes),
`dotnet restore`/`publish` and the Playwright browser download can fail with
`SELF_SIGNED_CERT_IN_CHAIN` even though the rest of the chain works. Trust that proxy's CA
inside the container before running the checkpoints:

```bash
docker run --rm \
  -v "$(pwd)":/workspaces/alm-lab \
  -v /path/to/your-proxy-ca.crt:/usr/local/share/ca-certificates/proxy-ca.crt:ro \
  -w /workspaces/alm-lab \
  -e LAB_LOCAL_MODE=1 -e LAB_AUTO_MERGE=1 -e LAB_AUTO=1 \
  ghcr.io/talxis/tools-agentbox/image:latest \
  bash -c "update-ca-certificates && pwsh -c 'for (\$cp in Get-ChildItem .lab-scripts/CP*.ps1) { & \$cp.FullName }'"
```

On a plain internet-connected host (no intercepting proxy) this step isn't needed at all.

### 6. Verifying it worked

After a full run, confirm:

- `git tag` lists a `cpNN` tag for every checkpoint that produced a real change,
- `.lab-state.json` has `devEnvUrl`/`testEnvUrl` set to `*.stub.invalid` placeholders (not real
  Dataverse URLs) and `tenantId`/`appId` set to zeroed placeholder GUIDs,
- `src/` contains the full scaffolded monorepo (`Solutions.DataModel`, `Solutions.Logic`,
  `Solutions.Security`, `Solutions.UI`, `Plugins.Warehouse`, `Packages.Main`, `Scripts.UI`,
  `Tests.UI`),
- `.github/workflows/` contains `build.yml`, `deploy.yml`, and `test.yml`,
- every checkpoint's console output shows only `LAB_LOCAL_MODE: skipped — would...` lines for
  the parts that would touch real infrastructure — no unexpected errors.
