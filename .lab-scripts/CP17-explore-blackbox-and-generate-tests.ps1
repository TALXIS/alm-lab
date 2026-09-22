#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP17: Black-box exploration agent                                ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# The last step in the chain, and deliberately the opposite of CP16: that planner reads the
# bindings catalog first and reuses what already exists. This agent is FORBIDDEN from
# reading this repository's source at all — no .feature files, no StepDefinitions, no
# Support/Bindings, nothing. It only ever sees the running apps, the same way a real user
# or a tester with zero implementation knowledge would.
#
# The point isn't coverage efficiency, it's an honest second opinion: a suite planned by an
# agent that read the bindings catalog will only ever find what that catalog already
# anticipates. An agent that can't read any of that has no such ceiling — it can only find
# what the actual running UI lets it find, which is exactly the kind of gap a
# spec-first/bindings-first workflow is structurally blind to.
#
# Everything this agent produces lands in Features/Discovered/, kept separate from the
# reviewed suite. A human reviews it — promote what's real, discard what's noise — before
# any of it is bound and added to CI. This checkpoint scaffolds that agent and the
# Discovered/ convention; it does not invoke the agent itself, same as CP16.
#
# Run:  .lab-scripts/CP17-explore-blackbox-and-generate-tests.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP17 — Black-box exploration agent"
Push-Location $LabRoot
try {
    New-Item -ItemType Directory -Path ".github/agents" -Force | Out-Null
    # Full source: .lab-scripts/templates/16-bdd-explorer/bdd-warehouse-explorer.agent.md
    Expand-LabTemplate -Path "16-bdd-explorer/bdd-warehouse-explorer.agent.md" `
        -Destination ".github/agents/bdd-warehouse-explorer.agent.md"
    Write-Ok "Agent definition written: .github/agents/bdd-warehouse-explorer.agent.md"

    New-Item -ItemType Directory -Path "src/Tests.UI/Features/Discovered" -Force | Out-Null
    # Full source: .lab-scripts/templates/16-bdd-explorer/EXPLORATION-NOTES.md
    Expand-LabTemplate -Path "16-bdd-explorer/EXPLORATION-NOTES.md" `
        -Destination "src/Tests.UI/Features/Discovered/EXPLORATION-NOTES.md"
    Write-Ok "Features/Discovered/ scaffolded"

    # Keep Discovered/ out of the compiled suite. Reqnroll's .props globs **\*.feature into
    # ReqnrollFeatureFile, so anything the agent drops here becomes a test with no bindings and
    # fails on its first undefined step - turning a green suite red the moment the agent is
    # actually run. The Remove works from the project body because that glob lives in a .props,
    # which is imported first.
    $csproj = "src/Tests.UI/Tests.UI.csproj"
    $content = Get-Content -Raw -LiteralPath $csproj
    if ($content -notmatch 'ReqnrollFeatureFile Remove') {
        $marker = "</Project>"
        $exclusion = @"
  <!-- Features/Discovered/ is unvetted agent output: readable Gherkin, no bindings, not tests
       until a human promotes one into Features/ and binds it. None keeps them visible. -->
  <ItemGroup>
    <ReqnrollFeatureFile Remove="Features/Discovered/**/*.feature" />
    <None Include="Features/Discovered/**/*.feature" />
  </ItemGroup>

</Project>
"@
        $content = $content.Replace($marker, $exclusion)
        Set-Content -LiteralPath $csproj -Value $content -Encoding UTF8
        Write-Ok "Tests.UI.csproj: Discovered/ excluded from the compiled suite"
    }
} finally { Pop-Location }

Save-Checkpoint -Id "cp17" -Message "Add black-box exploration agent forbidden from reading source" -Body @'
Add the last step of the BDD-agent chain: an agent that only ever sees the running apps, never the source, so its scenarios aren'"'"'t bounded by what the bindings catalog or the human authors already anticipated.

## Changes
- add .github/agents/bdd-warehouse-explorer.agent.md — hard constraint against reading any repo file, browser-only exploration of the model-driven app and the picking code app, told to actively try to break things (boundaries, malformed input, double-submit, abandoned flows)
- add src/Tests.UI/Features/Discovered/ with EXPLORATION-NOTES.md as the unvetted landing spot for what it finds, pending human review before anything is bound or merged
## Testing
- no build changes; validate by running the agent against the dev environment and confirming EXPLORATION-NOTES.md and any Discovered/*.feature files only reference what'"'"'s observable in the running UI
'@
Write-Host "`n✓ Lab complete — you built the app, tested it, and closed the loop with agents that plan and explore it." -ForegroundColor Green
