#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                          Lab.Auth.ps1 — sign-in helpers                                ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Dot-sourced by Lab.Common.ps1, so every checkpoint gets the same GitHub credential choice.
# The interactive part (Invoke-LabSignIn) runs from lab-signin.ps1 and CP01.
#
# The lab runs on attendees' own computers, in Docker, in Codespaces and in cloud agent
# sandboxes, driven by a person or by a coding agent. Each of those hands the CLIs different
# credentials, so nothing here trusts a status command or the environment's name - every
# credential is checked by actually using it, read-only.
#
# Signing in is always done by the person running the lab, in their own terminal: the
# scripts never start a sign-in when no terminal is attached (the same rule txc enforces for
# its own device-code login). An agent that hits a sign-in step stops and asks the person.
#
# ──────────────────────────────────────────────────────────────────────────────────────────

# Same rule as txc's headless detection: a person can only answer prompts when both stdin and
# stdout are attached to a terminal.
function Test-LabInteractive {
    -not ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected)
}

# Prints the stop message an agent relays to the person (see AGENTS.md) and exits.
function Stop-LabNeedsPerson {
    param([Parameter(Mandatory)][string]$Reason)
    Write-Err $Reason
    Write-Host "  [LAB-ACTION] Run this in your own terminal, then re-run this checkpoint: .lab-scripts/lab-signin.ps1" -ForegroundColor Yellow
    exit 1
}

# Resolves the fork (owner/repo) from the origin remote, not the upstream parent.
function Get-LabRepo {
    $originUrl = git -C $LabRoot remote get-url origin 2>$null
    if ($originUrl -match 'github\.com[:/](.+?)(?:\.git)?$') { return $Matches[1] }
    return $null
}

# ── GitHub ──────────────────────────────────────────────────────────────────────────────
# gh prefers a token in GH_TOKEN/GITHUB_TOKEN over the person's own `gh auth login`. Codespaces
# injects GITHUB_TOKEN, which can't manage rulesets, Actions settings or secrets - and it comes
# back in every new terminal. Cloud agent sandboxes inject a token that may work. So: once the
# person has signed in with gh, that login wins in every process; otherwise the injected token
# is kept and Invoke-LabSignIn checks what it can actually do.
$Global:LabGitHubSource = 'none'

function Test-LabGhStoredLogin {
    $saved = @{ GH_TOKEN = $env:GH_TOKEN; GITHUB_TOKEN = $env:GITHUB_TOKEN }
    try {
        Remove-Item Env:GH_TOKEN, Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
        gh auth token -h github.com *> $null
        return $LASTEXITCODE -eq 0
    } finally {
        foreach ($name in $saved.Keys) { if ($null -ne $saved[$name]) { Set-Item "Env:$name" $saved[$name] } }
    }
}

function Select-LabGitHubCredential {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return }
    $hasEnvToken = $env:GH_TOKEN -or $env:GITHUB_TOKEN
    if (Test-LabGhStoredLogin) {
        Remove-Item Env:GH_TOKEN, Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
        $Global:LabGitHubSource = 'login'
    } elseif ($hasEnvToken) {
        $Global:LabGitHubSource = 'environment'
    }
}

# Read-only calls that need the same permissions the lab's writes need. Returns the problems found.
function Test-LabGitHubAccess {
    param([Parameter(Mandatory)][string]$Repo)
    $problems = @()
    gh api user --silent 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { return @("the GitHub credential doesn't work") }
    gh api "repos/$Repo/actions/permissions" --silent 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { $problems += "can't manage repository settings on $Repo (needed for rulesets and Actions)" }
    gh api "repos/$Repo/actions/secrets/public-key" --silent 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { $problems += "can't manage Actions secrets on $Repo" }
    # Pushing workflow files needs the 'workflow' scope. Only a gh login lists its scopes; an
    # injected token can't be checked without pushing, so CP05's push is where that shows up.
    if ($Global:LabGitHubSource -eq 'login') {
        $scopes = (gh auth status -h github.com 2>&1 | Select-String 'Token scopes') -replace '.*Token scopes: ', ''
        if ($scopes -notmatch 'workflow') { $problems += "the GitHub login is missing the 'workflow' scope" }
    }
    return $problems
}

function Invoke-LabGitHubSignIn {
    $repo = Get-LabRepo
    if (-not $repo) { Write-Err "Could not resolve the origin repo - make sure origin is your fork on github.com."; exit 1 }

    $problems = @(Test-LabGitHubAccess -Repo $repo)
    if ($problems.Count -eq 0) {
        $how = if ($Global:LabGitHubSource -eq 'login') { 'your gh login' } else { 'the token provided by this environment' }
        Write-Ok "GitHub: $(gh api user -q .login) on $repo, via $how"
        if ($Global:LabGitHubSource -eq 'login') { gh auth setup-git 2>&1 | Out-Null }
        return
    }

    foreach ($problem in $problems) { Write-Warn2 $problem }
    if ($Global:LabGitHubSource -eq 'login' -and $problems.Count -eq 1 -and $problems[0] -match "'workflow' scope") {
        if (-not (Test-LabInteractive)) { Stop-LabNeedsPerson "GitHub needs the 'workflow' scope, and that has to be approved by you." }
        Write-Info "Adding the 'workflow' scope - approve it in the browser..."
        gh auth refresh -h github.com -s workflow
    } elseif ($Global:LabGitHubSource -eq 'login') {
        Write-Err "Your gh login has no admin rights on $repo. Work in your own fork (see README, Start here)."
        exit 1
    } else {
        if (-not (Test-LabInteractive)) {
            $reason = if ($Global:LabGitHubSource -eq 'environment') { "the token this environment provides can't do everything the lab needs" } else { "there is no GitHub sign-in" }
            Stop-LabNeedsPerson "GitHub sign-in is needed: $reason."
        }
        Remove-Item Env:GH_TOKEN, Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
        Write-Info "Sign in to GitHub with the account that owns $repo (browser or one-time code)..."
        gh auth login -h github.com -p https -s workflow --web
        if ($LASTEXITCODE -ne 0) { Write-Err "GitHub sign-in failed"; exit 1 }
        $Global:LabGitHubSource = 'login'
    }

    $problems = @(Test-LabGitHubAccess -Repo $repo)
    if ($problems.Count -gt 0) { foreach ($problem in $problems) { Write-Err $problem }; exit 1 }
    gh auth setup-git 2>&1 | Out-Null
    Write-Ok "GitHub: $(gh api user -q .login) on $repo, via your gh login"
}

# ── Microsoft (txc + az) ────────────────────────────────────────────────────────────────
# txc and az are signed in separately, so nothing stops them ending up on different accounts
# or tenants - which only fails later, deep inside CP05. txc signs in first and az follows
# its tenant. Set LAB_TENANT (tenant id or domain) to pin the training tenant for both.

# A browser redirect to localhost only works when the browser runs on this machine.
function Test-LabLocalBrowser {
    if ($env:CODESPACES -or $env:SSH_CONNECTION -or $env:REMOTE_CONTAINERS -or (Test-Path '/.dockerenv')) { return $false }
    if ($IsLinux -and -not ($env:DISPLAY -or $env:WAYLAND_DISPLAY)) { return $false }
    return $true
}

function Get-LabTxcCredentials {
    $json = txc config auth list --format json 2>$null | Out-String
    if (-not $json.Trim()) { return @() }
    @($json | ConvertFrom-Json)
}

function Select-LabTxcCredential {
    $credentials = @(Get-LabTxcCredentials)
    if ($credentials.Count -eq 0) { return $null }
    $recorded = Get-LabValue 'txcAuth'
    $match = $credentials | Where-Object { $_.id -eq $recorded } | Select-Object -First 1
    if ($match) { return $match }
    if ($env:LAB_TENANT) { $credentials = @($credentials | Where-Object { $_.tenantId -eq $env:LAB_TENANT }) }
    if ($credentials.Count -le 1) { return $credentials | Select-Object -First 1 }

    if (-not (Test-LabInteractive)) { Stop-LabNeedsPerson "Several Power Platform sign-ins are stored; choose which one the lab uses." }
    Write-Info "Several Power Platform sign-ins are stored. Which one should the lab use?"
    for ($i = 0; $i -lt $credentials.Count; $i++) { Write-Info "  [$($i + 1)] $($credentials[$i].id) (tenant $($credentials[$i].tenantId))" }
    $choice = [int](Read-Host "  Number") - 1
    if ($choice -lt 0 -or $choice -ge $credentials.Count) { Write-Err "No such option"; exit 1 }
    return $credentials[$choice]
}

function Invoke-LabTxcSignIn {
    $credential = Select-LabTxcCredential
    if ($credential) {
        # --check-token makes a real token request, so an expired sign-in shows up here, not in CP04.
        txc config auth get $credential.id --check-token --format json *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Power Platform: $($credential.id) (tenant $($credential.tenantId))"
            return $credential
        }
        Write-Warn2 "Power Platform sign-in '$($credential.id)' has expired or no longer works."
    }

    if (-not (Test-LabInteractive)) { Stop-LabNeedsPerson "Power Platform sign-in is needed." }
    Write-Info "Sign in to Power Platform with your lab account (txc shows a browser window or a code)..."
    $previousId = if ($credential) { $credential.id }
    $before = @(Get-LabTxcCredentials | ForEach-Object { $_.id })
    $loginArgs = @('config', 'auth', 'login')
    if ($env:LAB_TENANT) { $loginArgs += @('--tenant', $env:LAB_TENANT) }
    txc @loginArgs
    if ($LASTEXITCODE -ne 0) { Write-Err "Power Platform sign-in failed"; exit 1 }

    # A repeat sign-in for the same account updates the existing alias, so fall back to it.
    $after = @(Get-LabTxcCredentials)
    $credential = $after | Where-Object { $_.id -notin $before } | Select-Object -First 1
    if (-not $credential -and $previousId) { $credential = $after | Where-Object { $_.id -eq $previousId } | Select-Object -First 1 }
    if (-not $credential -and $after.Count -eq 1) { $credential = $after[0] }
    if (-not $credential) { Write-Err "Signed in, but no Power Platform credential was stored"; exit 1 }
    Write-Ok "Power Platform: $($credential.id) (tenant $($credential.tenantId))"
    return $credential
}

# Prints nothing (instead of JSON) when az isn't signed in.
function Get-LabAzAccount {
    $json = az account show --query "{tenant:tenantId, user:user.name}" -o json 2>$null | Out-String
    if (-not $json.Trim()) { return $null }
    $json | ConvertFrom-Json
}

function Invoke-LabAzSignIn {
    param([Parameter(Mandatory)][string]$TenantId)
    $account = Get-LabAzAccount
    if ($account -and $account.tenant -eq $TenantId) {
        az account get-access-token --query expiresOn -o tsv *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Azure: $($account.user) (tenant $TenantId)"
            return $account
        }
        Write-Warn2 "Azure sign-in for $($account.user) has expired."
    } elseif ($account) {
        Write-Warn2 "Azure is signed in to tenant $($account.tenant), but Power Platform uses $TenantId."
    }

    if (-not (Test-LabInteractive)) { Stop-LabNeedsPerson "Azure sign-in to tenant $TenantId is needed." }
    # Signing in adds this tenant and makes it active; other az accounts on this machine stay signed in.
    $loginArgs = @('login', '--tenant', $TenantId, '--allow-no-subscriptions')
    if (Test-LabLocalBrowser) {
        Write-Info "Sign in to Azure with the same account in the browser window that opens..."
    } else {
        Write-Info "Sign in to Azure with the same account - open the link below and enter the code:"
        $loginArgs += '--use-device-code'
    }
    az @loginArgs | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Err "Azure sign-in failed"; exit 1 }
    $account = Get-LabAzAccount
    if (-not $account -or $account.tenant -ne $TenantId) { Write-Err "Azure signed in to tenant $($account.tenant), expected $TenantId"; exit 1 }
    Write-Ok "Azure: $($account.user) (tenant $TenantId)"
    return $account
}

# Signs in wherever something is missing, expired or mismatched; a no-op when all is well.
function Invoke-LabSignIn {
    if ($env:LAB_LOCAL_MODE) {
        Write-Step "Sign in 1/3 — GitHub"
        Write-Info "LAB_LOCAL_MODE: skipped sign-in for GitHub"
        Write-Step "Sign in 2/3 — Power Platform (txc)"
        Write-Info "LAB_LOCAL_MODE: skipped sign-in for Power Platform"
        Write-Step "Sign in 3/3 — Azure (az)"
        Write-Info "LAB_LOCAL_MODE: skipped sign-in for Azure"
        return
    }

    Write-Info "Use your lab account for Power Platform and Azure - the same account for both."
    if ($env:LAB_TENANT) { Write-Info "This lab is pinned to tenant $env:LAB_TENANT (LAB_TENANT)." }

    Write-Step "Sign in 1/3 — GitHub"
    Invoke-LabGitHubSignIn

    Write-Step "Sign in 2/3 — Power Platform (txc)"
    $credential = Invoke-LabTxcSignIn
    if (-not $credential.tenantId) { Write-Err "Power Platform sign-in '$($credential.id)' has no tenant recorded - run 'txc config auth delete $($credential.id)' and sign in again."; exit 1 }
    Set-LabValue 'txcAuth' $credential.id

    Write-Step "Sign in 3/3 — Azure (az)"
    $account = Invoke-LabAzSignIn -TenantId $credential.tenantId
    Set-LabValue 'tenantId' $credential.tenantId

    # Aliases default to the signed-in UPN, so a differing pair of UPNs means two accounts.
    if ($credential.id -match '@' -and $account.user -match '@' -and $credential.id -notlike "$($account.user)*") {
        Write-Warn2 "Power Platform uses $($credential.id) but Azure uses $($account.user) - same tenant, different accounts."
    }
}
