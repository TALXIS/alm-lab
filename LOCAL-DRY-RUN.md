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

**Node/npm needs its own separate fix.** `update-ca-certificates` only wires the CA into the
OS/`dotnet` trust store — Node's own TLS stack doesn't consult it, so any checkpoint that
runs `npm install` (CP09's code app and script-library components, e.g. `Scripts.UI`,
`Apps.WarehousePicking`) will still fail with `SELF_SIGNED_CERT_IN_CHAIN` even after the step
above. Point Node/npm at the same CA bundle explicitly, before running the checkpoints:

```bash
export NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/<your-proxy-ca>.crt
npm config set cafile /usr/local/share/ca-certificates/<your-proxy-ca>.crt
```

Symptom if you skip this: the checkpoint script doesn't fail outright — MSBuild's
`NodeRestore` target just reports `npm install exited with code 1` after several minutes
(it silently retries), and CP09 continues past the failed component with a `⚠ ... build had
issues` warning rather than stopping. Set the two lines above before the run, or if you're
already mid-run, set them and manually re-run `npm install` in the affected project
directory, then re-run the checkpoint script — it's idempotent and will pick up from where
it left off.

## Verifying it worked

- `git tag` shows a tag per checkpoint that made a real change
- `.lab-state.json` has stub/placeholder values instead of real environment URLs or IDs
- checkpoint output only shows `LAB_LOCAL_MODE: skipped — would...` lines for the
  infrastructure-touching parts — no unexpected errors
