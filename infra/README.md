# .infra — Terraform scaffold

> **Status:** `environments/` and `identity/` are driven by
> `.lab-scripts/CP04b-setup-runtime-terraform.ps1` and
> `CP05b-setup-continuous-deployment-terraform.ps1` — an alternative to CP04/CP05.
> Run CP04+CP05 (imperative) **or** CP04b+CP05b (Terraform), not a mix: CP05b requires
> Terraform's local state to already own the Test environment resource, which only
> happens if CP04b (not CP04) ran first. `tenant/` and `groups/` remain scaffold-only;
> nothing calls them.

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
immediately, no editing required before the first run.

`dev/config.yml`/`test/config.yml`'s `<rid>` placeholders stop being purely
illustrative once CP04b runs for real: it string-replaces `<rid>` with the session's
actual random identifier in place, and the resulting file is committed as part of the
`cp04` checkpoint — the same "config becomes real, committed state" pattern
`.lab-state.json` already uses elsewhere in the lab.

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
consuming tier's `config.yml`:

- `groups/terraform` outputs `group_ids` → paste into `environments/*/config.yml`'s
  `environment_group_id` and into `tenant/terraform`'s
  `routing_target_environment_group_id` variable. `groups/` and `tenant/` are unused
  by CP04b/CP05b, so this link stays manual.
- `identity/terraform` outputs `client_id` → `environments/test/config.yml`'s
  `deployment_principal_id`. When CP05b drives this, it reads the output and writes
  it into `config.yml` itself — this link is only manual if you're applying
  `identity/terraform` and `environments/terraform` directly, outside the checkpoint
  scripts.

## Caution

`tenant/terraform` targets tenant-wide settings. If multiple attendees share one
Power Platform tenant, do not `apply` this tier from your fork — it is included
for illustration/reference only in that setup.
