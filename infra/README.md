# .infra — Terraform scaffold

> **Status:** `environments/`, `groups/`, and `identity/` are driven by
> `.lab-scripts/CP04b-setup-runtime-terraform.ps1` and
> `CP05b-setup-continuous-deployment-terraform.ps1` — an alternative to CP04/CP05.
> Run CP04+CP05 (imperative) **or** CP04b+CP05b (Terraform), not a mix: CP05b requires
> Terraform's local state to already own the Test environment resource, which only
> happens if CP04b (not CP04) ran first. `tenant/` remains scaffold-only; nothing
> calls it — deliberately, see Caution below.

## Scope

Manages, as Terraform resources:
- Power Platform tenant settings (`tenant/`)
- Environment groups (`groups/`)
- Dataverse Sandbox environments, their audit settings, security-team membership,
  and CD application-user registration (`environments/`)
- The Entra ID app registration, service principal, and GitHub OIDC federated
  credential used for CI/CD (`identity/`)

This intentionally covers more ground than a typical "power-platform domain" repo
would, since this lab has no separate Azure/Entra IaC domain to put identity in.

Does **not** manage: the GitHub branch protection ruleset (CP03), GitHub secrets or
Actions enablement (CP05), or GitHub Actions workflow files — those stay purely
imperative, owned by the checkpoint scripts.

## Layout

    .infra/
    ├── tenant/terraform/          # singleton: tenant-wide settings
    ├── identity/terraform/        # singleton: CD app registration + SP + federated credential
    ├── groups/terraform/          # one module instance per environment group
    │   └── workshop-environments/
    └── environments/terraform/    # one module instance per Dataverse environment
        ├── dev/                   # illustrative — mirrors CP04's wm-dev-<rid>
        └── test/                  # illustrative — mirrors CP04's wm-test-<rid>

`environments/*`'s `.tf` files are identical across `dev`/`test` — only `config.yml`
differs. `groups/terraform/workshop-environments` has no `config.yml`: it's the only
group this lab needs, so its values are inlined directly in `group.tf` and it
applies with no manual setup — `terraform apply` in `groups/terraform` works
immediately, no editing required before the first run (this is also why CP04b is
able to drive it automatically, with no vars to pass in).

`dev/config.yml`/`test/config.yml`'s `<rid>` placeholders, and their empty
`environment_group_id`, stop being purely illustrative once CP04b runs for real: it
applies `groups/terraform` first, then string-replaces `<rid>` and
`environment_group_id` with the session's actual random identifier and group id in
place, and the resulting file is committed as part of the `cp04` checkpoint — the
same "config becomes real, committed state" pattern `.lab-state.json` already uses
elsewhere in the lab. This only happens the first time CP04b actually creates Dev and
Test — a later re-run of CP04b (once both environments already exist) does not
re-apply `groups/terraform` or rewrite `environment_group_id`, since changing an
existing environment's group is a real mutation of that resource, not something a
routine re-run should trigger as a side effect.

## Prerequisites

- Terraform CLI >= 1.13
- An already-signed-in `pac`/`txc` session and `az` session on this machine — run
  `.lab-scripts/CP01-check-machine-setup.ps1` first. Providers here authenticate via
  `use_cli = true` (Power Platform) and the Azure CLI's default credential
  (`azuread`), not client secrets or OIDC — there's no service principal available
  to Terraform itself in this lab.

## State

Local state only (`terraform.tfstate` per directory, no remote backend). Each
attendee's fork/session is ephemeral and there is no shared Azure storage account to
back a remote backend for this lab. `.terraform/`, `*.tfstate*`, and
`.terraform.lock.hcl` are gitignored — do not commit them.

## Cross-tier wiring (manual, by design)

Because state is local (no `terraform_remote_state` data source available across
tiers), values that one tier's `output` produces must be pasted by hand into the
consuming tier's `config.yml` — unless a checkpoint script drives both tiers, in
which case it does the pasting for you:

- `groups/terraform` outputs `group_ids` → `environments/*/config.yml`'s
  `environment_group_id`. When CP04b drives this, it applies `groups/terraform`
  first and writes the output into both `dev/config.yml` and `test/config.yml`
  itself. This link is only manual if you're applying `groups/terraform` and
  `environments/terraform` directly, outside the checkpoint scripts.
- `groups/terraform` outputs `group_ids` → `tenant/terraform`'s
  `routing_target_environment_group_id` variable. `tenant/` is unused by CP04b/CP05b
  (deliberately — see Caution below), so this link stays manual.
- `identity/terraform` outputs `client_id` → `environments/test/config.yml`'s
  `deployment_principal_id`. When CP05b drives this, it reads the output and writes
  it into `config.yml` itself — this link is only manual if you're applying
  `identity/terraform` and `environments/terraform` directly, outside the checkpoint
  scripts.

## Caution

`tenant/terraform` targets tenant-wide settings. If multiple attendees share one
Power Platform tenant, do not `apply` this tier from your fork — it is included
for illustration/reference only in that setup.
