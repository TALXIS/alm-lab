# Local dry-run

Run the checkpoint scripts locally in a container, without forking to GitHub, without
Codespaces, and without provisioning any real Power Platform/Azure infrastructure. Every
checkpoint's GitHub/Power Platform/Azure calls short-circuit behind `LAB_LOCAL_MODE=1` —
each logs what it would have done and continues.

## Run it

Install Docker if you don't have it, then run the devcontainer image against your checkout
and run the checkpoints inside, in order:

```bash
docker run -it --rm \
  -v "$(pwd)":/workspaces/alm-lab \
  -w /workspaces/alm-lab \
  -e LAB_LOCAL_MODE=1 -e LAB_AUTO_MERGE=1 -e LAB_AUTO=1 \
  ghcr.io/talxis/tools-agentbox/image:latest \
  pwsh -c 'foreach ($cp in Get-ChildItem .lab-scripts/CP*.ps1 | Sort-Object Name) { & $cp.FullName }'
```

Git identity and branch state are handled by the scripts themselves — nothing to set up
first.

## If your network intercepts HTTPS

Behind a corporate or sandboxed proxy that intercepts TLS, `dotnet` and the Playwright
browser download can fail with `SELF_SIGNED_CERT_IN_CHAIN`. Trust that proxy's CA inside the
container first: mount it and run `update-ca-certificates` before the checkpoints. Not
needed on a plain internet-connected host.

## Verifying it worked

- `git tag` shows a tag per checkpoint that made a real change
- `.lab-state.json` has stub/placeholder values instead of real environment URLs or IDs
- checkpoint output only shows `LAB_LOCAL_MODE: skipped — would...` lines for the
  infrastructure-touching parts — no unexpected errors



## Running the black-box explorer

`playwright-cli` scopes browser sessions to the working directory, so establish the session from
the repo root first and have the agent run every command from there too.

```bash
playwright-cli -s=explorer open
playwright-cli -s=explorer state-load "$PWD/src/Tests.UI/.auth/state-<account>.json"
playwright-cli -s=explorer goto "https://apps.powerapps.com/play/e/<env-id>/a/<app-id>"
playwright-cli -s=explorer snapshot          # must show the item list, not a sign-in page
```

Then, pasting the agent definition into the prompt rather than pointing at the file — the agent is
forbidden from reading this repo, and reading its own brief would be the first violation:

```
claude "You are the Warehouse BDD Explorer; your role definition follows in full. <paste
.github/agents/bdd-warehouse-explorer.agent.md>. A signed-in session named 'explorer' is already
open. Prefix EVERY playwright-cli command with: cd <repo root> && . Never run open, close or
state-load. Write to src/Tests.UI/Features/Discovered/."
```