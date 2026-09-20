#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║              11: Tests.UI — Playwright / Reqnroll UI Test Project                      ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Creates a Playwright-based BDD test project using the pp-test-ui template.
# Includes frozen step bindings for model-driven app surfaces (forms, views,
# command bar, navigation) and a sample feature file, plus a second feature +
# hand-authored custom steps for the Warehouse Picking code app — a standalone SPA the
# frozen bindings can't navigate to, since those only know the model-driven app's URL shape.
#
# Expects: $PublisherPrefix from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Tests.UI ──" -ForegroundColor Cyan

# $PublisherPrefix comes from the calling checkpoint. Without this guard an unset variable
# expands to "" and every template renders "'_warehouseapp'" — an app name that resolves to
# nothing, in feature files that still build, still get committed, and only fail once someone
# finally runs the browser scenarios. Fail here instead.
if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) {
    throw "11-tests-ui.ps1: `$PublisherPrefix is not set. The calling checkpoint must set it (Get-LabValue 'publisherPrefix' 'almlab')."
}

# ──────────────────────────────────────────────────────────────────────────────────────────
#                              Scaffold Test Project
# ──────────────────────────────────────────────────────────────────────────────────────────

if (-not (Get-LabValue 'testsUiScaffolded')) {

txc workspace component create pp-test-ui `
    --output "src/Tests.UI"

# Add to solution
dotnet sln add src/Tests.UI/Tests.UI.csproj

Write-Host "  ✓ Tests.UI project created" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                              Sample Feature File
# ──────────────────────────────────────────────────────────────────────────────────────────

txc workspace component create pp-test-ui-feature `
    --param "name=WarehouseItemNavigation" `
    --output "src/Tests.UI"

Write-Host "  ✓ Sample feature: WarehouseItemNavigation.feature" -ForegroundColor Green

# Write a meaningful scenario into the feature file.
# The "I am logged in as '<who>'" step only records a label - nothing authenticates from it
# (the binding stores the string and returns). Real sign-in comes from the captured browser
# session at StorageStatePath/TXC_STORAGE_STATE_PATH, so the scenarios name a role rather
# than a UPN: business language, and nothing to re-substitute per tenant.
# Full source: .lab-scripts/templates/11-tests-ui/WarehouseItemNavigation.feature
Expand-LabTemplate -Path "11-tests-ui/WarehouseItemNavigation.feature" `
    -Destination "src/Tests.UI/Features/WarehouseItemNavigation.feature" `
    -Tokens @{ PREFIX = $PublisherPrefix }
Write-Host "  ✓ Feature scenario written" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                  Warehouse Locations / Transactions Navigation (sitemap coverage)
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# Same frozen navigation vocabulary as WarehouseItemNavigation above — these two entities
# also have their own sitemap subarea and view (see scaffold/05b-sitemap.ps1 and
# 05d-views-subgrids.ps1), so they get the same coverage rather than being left untested.

txc workspace component create pp-test-ui-feature `
    --param "name=WarehouseLocationNavigation" `
    --output "src/Tests.UI"
# Full source: .lab-scripts/templates/11-tests-ui/WarehouseLocationNavigation.feature
Expand-LabTemplate -Path "11-tests-ui/WarehouseLocationNavigation.feature" `
    -Destination "src/Tests.UI/Features/WarehouseLocationNavigation.feature" `
    -Tokens @{ PREFIX = $PublisherPrefix }
Write-Host "  ✓ Sample feature: WarehouseLocationNavigation.feature" -ForegroundColor Green

txc workspace component create pp-test-ui-feature `
    --param "name=WarehouseTransactionNavigation" `
    --output "src/Tests.UI"
# Full source: .lab-scripts/templates/11-tests-ui/WarehouseTransactionNavigation.feature
Expand-LabTemplate -Path "11-tests-ui/WarehouseTransactionNavigation.feature" `
    -Destination "src/Tests.UI/Features/WarehouseTransactionNavigation.feature" `
    -Tokens @{ PREFIX = $PublisherPrefix }
Write-Host "  ✓ Sample feature: WarehouseTransactionNavigation.feature" -ForegroundColor Green

# One cross-area scenario as a lightweight sitemap regression check — same steps, chained.
txc workspace component create pp-test-ui-feature `
    --param "name=WarehouseCrossAreaNavigation" `
    --output "src/Tests.UI"
# Full source: .lab-scripts/templates/11-tests-ui/WarehouseCrossAreaNavigation.feature
Expand-LabTemplate -Path "11-tests-ui/WarehouseCrossAreaNavigation.feature" `
    -Destination "src/Tests.UI/Features/WarehouseCrossAreaNavigation.feature" `
    -Tokens @{ PREFIX = $PublisherPrefix }
Write-Host "  ✓ Sample feature: WarehouseCrossAreaNavigation.feature" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                       Warehouse Picking Feature (code app)
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# The frozen bindings under Support/Bindings/ only cover the model-driven app (they navigate
# via main.aspx?appname=..., a URL the code app — a standalone SPA — doesn't have). This
# scenario needs its own steps, kept in StepDefinitions/ to signal "ours, not
# template-shipped" — same split the pp-test-ui template itself uses for genux/custom pages.

txc workspace component create pp-test-ui-feature `
    --param "name=WarehousePicking" `
    --output "src/Tests.UI"

# pp-test-ui-feature only scaffolds an empty "Feature: WarehousePicking" stub — Reqnroll
# generates the .feature.cs designer file from it at build time, nothing to remove here.
# We overwrite the stub with the real scenarios below via Expand-LabTemplate, same as
# WarehouseItemNavigation above.

# Full source: .lab-scripts/templates/11-tests-ui/WarehousePicking.feature
Expand-LabTemplate -Path "11-tests-ui/WarehousePicking.feature" `
    -Destination "src/Tests.UI/Features/WarehousePicking.feature"

New-Item -ItemType Directory -Path "src/Tests.UI/StepDefinitions" -Force | Out-Null
# Full source: .lab-scripts/templates/11-tests-ui/WarehousePickingSteps.cs
Expand-LabTemplate -Path "11-tests-ui/WarehousePickingSteps.cs" `
    -Destination "src/Tests.UI/StepDefinitions/WarehousePickingSteps.cs"

Write-Host "  ✓ Feature scenario written: WarehousePicking.feature + custom steps" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                       Authentication (the "I am logged in as" step)
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# The pp-test-ui template's login step only records the string it is given - the scenarios then
# need a browser session captured by hand, which is the step everyone forgets before a demo.
# These files make the step sign in for real: persona -> account from .env, cached session per
# account under .auth/, TOTP for MFA so a headless run works on a protected tenant. Same shape
# as TALXIS.TestKit's LoginSteps (user alias, cookie cache, OtpToken) and as the auth script in
# Microsoft's power-platform-playwright-samples, without needing npm in a .NET test project.

New-Item -ItemType Directory -Path "src/Tests.UI/Authentication" -Force | Out-Null
foreach ($file in @("DotEnv.cs", "TestCredentials.cs", "SignIn.cs", "Totp.cs", "AuthenticationHooks.cs")) {
    # Full source: .lab-scripts/templates/11-tests-ui/Authentication/$file
    Expand-LabTemplate -Path "11-tests-ui/Authentication/$file" `
        -Destination "src/Tests.UI/Authentication/$file"
}

# Offline tests for the two parts that are pure logic and easy to get subtly wrong: the
# persona -> variable-name mapping, and RFC 6238 (verified against the spec's own vectors).
foreach ($file in @("TotpTests.cs", "TestCredentialsTests.cs")) {
    # Full source: .lab-scripts/templates/11-tests-ui/$file
    Expand-LabTemplate -Path "11-tests-ui/$file" -Destination "src/Tests.UI/Tests/$file"
}

# Full source: .lab-scripts/templates/11-tests-ui/env.example
Expand-LabTemplate -Path "11-tests-ui/env.example" -Destination "src/Tests.UI/.env.example"

# Full source: .lab-scripts/templates/11-tests-ui/Authentication.feature
Expand-LabTemplate -Path "11-tests-ui/Authentication.feature" `
    -Destination "src/Tests.UI/Features/Authentication.feature" `
    -Tokens @{ PREFIX = $PublisherPrefix }

# Redirect the frozen login binding at the new code. Patched rather than replaced wholesale so
# the rest of NavigationSteps.cs stays whatever the template ships; the step *text* is
# untouched, so the frozen vocabulary test and every feature file still hold.
$navigationSteps = "src/Tests.UI/Support/Bindings/NavigationSteps.cs"
$navigation = Get-Content -Raw -LiteralPath $navigationSteps
$loginStub = @'
    [Given("I am logged in as {string}")]
    public Task GivenIAmLoggedInAs(string profile)
    {
        _scenarioContext["Profile"] = profile;
        return Task.CompletedTask;
    }
'@
$loginReal = @'
    // Lab deviation from the frozen binding: upstream this only records the string. Here it
    // signs in - see Authentication/SignIn.cs. The step text is unchanged, so the frozen
    // vocabulary (and every feature file written against it) still holds.
    [Given("I am logged in as {string}")]
    public async Task GivenIAmLoggedInAs(string profile)
    {
        _scenarioContext["Profile"] = profile;
        await Authentication.SignIn.EnsureSignedInAsync(_scenarioContext, profile);
    }
'@
if ($navigation.Contains($loginStub.Replace("`r`n", "`n"))) {
    $navigation = $navigation.Replace($loginStub.Replace("`r`n", "`n"), $loginReal.Replace("`r`n", "`n"))
    Set-Content -LiteralPath $navigationSteps -Value $navigation -Encoding UTF8
} elseif (-not $navigation.Contains("SignIn.EnsureSignedInAsync")) {
    # Fail loudly: silently skipping this leaves scenarios that cannot authenticate, and the
    # only symptom is a timeout on a Microsoft sign-in page much later.
    throw "11-tests-ui.ps1: could not find the login stub in $navigationSteps - the pp-test-ui template changed it. Patch Authentication/SignIn.cs in by hand."
}

# .env holds a password; .auth/ holds a live session. Neither may ever be committed.
Add-Content -LiteralPath "src/Tests.UI/.gitignore" -Value @"

# Cached sessions written by the "I am logged in as" step, one file per account.
.auth/

# Credentials for that step. .env.example is the committed template.
.env
!.env.example
"@

Write-Host "  ✓ Authentication: .env-backed sign-in, session cache, TOTP for MFA" -ForegroundColor Green

# Drop the Calculator sample that ships with the templates. This runs after every
# pp-test-ui-feature call, not just the first: the sample reappears, and its four steps have
# no bindings anywhere in the project, so leaving it behind means one guaranteed failing
# scenario in the Testing panel for every learner.
Remove-Item "src/Tests.UI/Features/Calculator.feature" -ErrorAction SilentlyContinue
Remove-Item "src/Tests.UI/Features/Calculator.feature.cs" -ErrorAction SilentlyContinue

# ──────────────────────────────────────────────────────────────────────────────────────────
#                              Configure appsettings.json
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# All settings can be overridden via environment variables:
#   TXC_ENVIRONMENT_URL, TXC_APP_NAME, TXC_HEADLESS, TXC_SLOWMO,
#   TXC_TIMEOUT, TXC_STORAGE_STATE_PATH, TXC_SCREENSHOT_ON_FAILURE, TXC_TRACING_ENABLED
#
# To capture auth state for headless runs (Codespaces):
#   playwright-cli open --browser=msedge --headed <env-url>    # local machine with display
#   playwright-cli state-save src/Tests.UI/auth-state.json
#   playwright-cli close
#
# NOTE: StorageStatePath must be an absolute path — relative paths resolve from the test
#       binary output directory (bin/Debug/<tfm>/) and are silently ignored by Playwright.
#       It is therefore left EMPTY here rather than baked in: appsettings.json is committed,
#       and an absolute path from whoever ran this checkpoint last is wrong on every other
#       machine (and leaks their home directory). Set TXC_STORAGE_STATE_PATH at run time, or
#       put your own absolute path in appsettings.json locally without committing it.
#       With it empty the browser starts signed out: the unit tests still pass, the browser
#       scenarios stop at the Microsoft sign-in page.

# The Dev environment this lab just provisioned is the right default target - falling back to
# a placeholder URL only guarantees the first test run fails.
$envUrl = if ($env:TXC_ENVIRONMENT_URL) { $env:TXC_ENVIRONMENT_URL } else { Get-LabValue 'devEnvUrl' "https://yourenv.crm4.dynamics.com" }
# Full source: .lab-scripts/templates/11-tests-ui/appsettings.json
Expand-LabTemplate -Path "11-tests-ui/appsettings.json" `
    -Destination "src/Tests.UI/appsettings.json" `
    -Tokens @{ ENV_URL = $envUrl; AUTH_STATE_PATH = ""; PREFIX = $PublisherPrefix }
Write-Host "  ✓ appsettings.json configured" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                              Build + Install Playwright
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "  → Building Tests.UI..." -ForegroundColor White
dotnet build src/Tests.UI/Tests.UI.csproj --nologo --verbosity quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Build succeeded" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Build had issues (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
}

# Detect actual output TFM from build output directory
$debugDir = "src/Tests.UI/bin/Debug"
$tfm = if (Test-Path $debugDir) {
    Get-ChildItem -Path $debugDir -Directory | Select-Object -First 1 -ExpandProperty Name
} else { "net8.0" }

Write-Host "  → Installing Playwright browsers (TFM: $tfm)..." -ForegroundColor White
$playwrightScript = "src/Tests.UI/bin/Debug/$tfm/playwright.ps1"
if (Test-Path $playwrightScript) {
    pwsh $playwrightScript install chromium
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Playwright browsers installed" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Playwright install had issues (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠ playwright.ps1 not found at $playwrightScript — run dotnet build first" -ForegroundColor Yellow
}

# Marks the whole block done — checked instead of Test-Path on the csproj so a re-run after
# a partial failure (e.g. project created but the feature file/build didn't finish) retries
# everything rather than silently skipping the missing work.
Set-LabValue 'testsUiScaffolded' $true

} else {
    Write-Host "  ✓ Tests.UI (exists)" -ForegroundColor Green
}

