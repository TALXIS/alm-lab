#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP16: Plan tests with an agent                                   ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Conceptually this is step ONE of the BDD-agent authoring chain: give an agent a prompt,
# it explores the running app, and it hands back .feature files. It's checkpoint 16, not
# checkpoint 1, because that agent needs something to reuse - the frozen step-binding
# catalog under src/Tests.UI/Support/Bindings/ that CP14 scaffolds. Without that catalog
# the agent has nothing to check its own scenarios against and will happily invent steps
# nobody can execute. So: build the bindings first (CP14), plan against them from here on.
#
# This checkpoint doesn't call an LLM itself - like CP14's own comment says, see
# TALXIS/docs-patterns-practices (bdd-agent-v2) for that. It scaffolds the agent
# definition and the TestPlans/ convention so the workflow is: open this repo in an
# AI coding assistant that supports custom agents (GitHub Copilot agent mode, Claude
# Code, etc.), point it at .github/agents/bdd-warehouse-planner.agent.md, and give it a
# prompt such as "plan coverage for the low-stock highlight on the items grid."
#
# Run this once to scaffold the agent + TestPlans convention; run the agent itself as
# many times as you like afterwards, once per feature you want planned.
#
# Run:  .lab-scripts/CP16-plan-tests-with-agent.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP16 — BDD planning agent"
Push-Location $LabRoot
try {
    if (-not (Test-Path "src/Tests.UI/Support/Bindings")) {
        Write-Err "src/Tests.UI/Support/Bindings not found — run CP14 first (the planner needs the bindings catalog to plan against)."
        exit 1
    }

    New-Item -ItemType Directory -Path ".github/agents" -Force | Out-Null
    # Full source: .lab-scripts/templates/19-bdd-planner/bdd-warehouse-planner.agent.md
    Expand-LabTemplate -Path "19-bdd-planner/bdd-warehouse-planner.agent.md" `
        -Destination ".github/agents/bdd-warehouse-planner.agent.md"
    Write-Ok "Agent definition written: .github/agents/bdd-warehouse-planner.agent.md"

    New-Item -ItemType Directory -Path "TestPlans" -Force | Out-Null
    New-Item -ItemType Directory -Path "src/Tests.UI/Features/Planned" -Force | Out-Null
    New-Item -ItemType File -Path "src/Tests.UI/Features/Planned/.gitkeep" -Force | Out-Null
    # Full source: .lab-scripts/templates/19-bdd-planner/TestPlans-README.md
    Expand-LabTemplate -Path "19-bdd-planner/TestPlans-README.md" `
        -Destination "TestPlans/README.md"
    Write-Ok "TestPlans/ scaffolded"
} finally { Pop-Location }

Save-Checkpoint -Id "cp16" -Message "Add BDD planning agent and TestPlans convention" -Body @'
Add the planning step of the BDD-agent authoring chain: a prompt in, .feature files out, checked against the step-binding catalog the suite can already execute so proposed scenarios stay honest about what's implemented and what still needs binding work.

## Changes
- add .github/agents/bdd-warehouse-planner.agent.md — reads Support/Bindings + StepDefinitions before planning, explores the running app rather than guessing labels, reuses existing step text first, flags gaps instead of inventing bindings
- add TestPlans/ with README documenting the missing-bindings doc format
- add src/Tests.UI/Features/Planned/ as the landing spot for agent-planned scenarios pending review
## Testing
- no build changes; validate by running the agent against a scoped prompt and confirming it reuses existing step phrasing before proposing anything new
'@
Write-Host "`nNext: .lab-scripts/CP17-explore-blackbox-and-generate-tests.ps1" -ForegroundColor Cyan
