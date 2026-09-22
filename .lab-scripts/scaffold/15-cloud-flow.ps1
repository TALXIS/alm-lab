#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║          15: Cloud Flow — scaffold, type-check against the environment, validate       ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Scaffolds a Power Automate cloud flow into Solutions.Logic and fills in a Dataverse
# action. Expects: $PublisherPrefix from parent scope.
# Expects: Solutions.Logic already scaffolded (08-logic-solution.ps1, via CP07).
#
# The interesting part is not the scaffold - it is where the action's parameter names come
# from. They are read out of the connected environment, not typed from memory. A flow
# definition is hand-written JSON with no compiler behind it, so an invented operation id
# or a misspelled parameter name survives all the way to a failed deployment. txc reads the
# real connector metadata and checks the definition against it.
#
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Cloud flow ──" -ForegroundColor Cyan

if (-not (Get-LabValue 'cloudFlowScaffolded')) {

$FlowLogicalName = "lowstockreport"
$Connector       = "shared_commondataserviceforapps"   # Microsoft Dataverse
$Operation       = "ListRecords"
$EntitySetName   = "${PublisherPrefix}_warehouseitems"

# ──────────────────────────────────────────────────────────────────────────────────────────
#                    Does a connection reference exist to bind to?
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# A solution-aware flow does not carry credentials. It binds to a *connection reference* by
# logical name, and the reference is what gets wired to a real connection at import time.
# There is no component template for a connection reference yet, so unlike every other
# component in this lab it cannot be scaffolded from source - it has to exist already.

Write-Info "Looking for a Dataverse connection reference..."
$connectionsJson = txc environment connection list --connector $Connector --format json 2>$null
$connections = if ($connectionsJson) { $connectionsJson | ConvertFrom-Json } else { @() }
$reference = $connections | Where-Object { $_.connectionReferenceLogicalName } | Select-Object -First 1

if (-not $reference) {
    Write-Err "No Dataverse connection reference found in this environment."
    Write-Info "A flow binds to a connection reference by logical name, and one cannot be"
    Write-Info "created from source yet. Create it once in the maker portal:"
    Write-Info "  1. https://make.powerautomate.com → your Dev environment"
    Write-Info "  2. Solutions → your solution → New → More → Connection reference"
    Write-Info "  3. Pick the Microsoft Dataverse connector and an existing connection"
    Write-Info "Then re-run this checkpoint."
    exit 1
}

$ConnectionReferenceLogicalName = $reference.connectionReferenceLogicalName
Write-Ok "Connection reference: $ConnectionReferenceLogicalName"

# ──────────────────────────────────────────────────────────────────────────────────────────
#                                   Scaffold the flow
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# Emits two files into Solutions.Logic/Workflows - the .json client data (definition) and
# the .json.data.xml Workflow record - and registers the flow as a root component (type 29)
# in Solution.xml. The definition arrives with a manual trigger and an empty "actions": {}.

txc workspace component create pp-flow `
    --output "src/Solutions.Logic" `
    --param "PublisherPrefix=$PublisherPrefix" `
    --param "LogicalName=$FlowLogicalName"

$flowJson = Get-ChildItem -Path "src/Solutions.Logic/Workflows" -Filter "*.json" |
            Where-Object { $_.Name -notlike "*.data.xml" } |
            Select-Object -First 1
if (-not $flowJson) { Write-Err "Flow scaffold produced no .json definition"; exit 1 }

Write-Ok "Scaffolded $($flowJson.Name)"

# ──────────────────────────────────────────────────────────────────────────────────────────
#                     Read the operation contract from the environment
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# These two commands are the point of the checkpoint. The first finds the operation, the
# second prints its exact parameter names, types, required flags and - importantly - the
# action type the definition has to declare. Read the output before looking at the JSON
# below: every name in that JSON came from here.

Write-Info "Connector operations matching 'list rows':"
txc environment connector get $Connector --query "list rows" --format text

Write-Info "`nParameter contract for ${Operation}:"
txc environment connector operation get $Connector $Operation --format text

# ──────────────────────────────────────────────────────────────────────────────────────────
#                              Write the action into the definition
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# entityName is the entity *set* name (plural) and is required. $filter and $select are
# optional. The host block addresses the operation; connectionName points at the key used
# in connectionReferences below, and "source": "Embedded" is what a deployed solution needs.

$definition = Get-Content -Raw -LiteralPath $flowJson.FullName | ConvertFrom-Json

$action = [ordered]@{
    type    = "OpenApiConnection"
    inputs  = [ordered]@{
        host       = [ordered]@{
            apiId        = "/providers/Microsoft.PowerApps/apis/$Connector"
            operationId  = $Operation
            connectionName = $Connector
        }
        parameters = [ordered]@{
            entityName = $EntitySetName
            '$filter'  = "${PublisherPrefix}_availablequantity lt 10"
            '$select'  = "${PublisherPrefix}_availablequantity"
        }
    }
    runAfter = @{}
}

$definition.properties.definition.actions | Add-Member -NotePropertyName "Get_low_stock_items" -NotePropertyValue $action -Force

$definition.properties.connectionReferences | Add-Member -NotePropertyName $Connector -NotePropertyValue ([ordered]@{
    connectionName                 = $Connector
    source                         = "Embedded"
    id                             = "/providers/Microsoft.PowerApps/apis/$Connector"
    connectionReferenceLogicalName = $ConnectionReferenceLogicalName
}) -Force

$definition | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $flowJson.FullName -Encoding UTF8

Write-Ok "Action written: Get_low_stock_items → $Operation on $EntitySetName"

# ──────────────────────────────────────────────────────────────────────────────────────────
#                                      Validate
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# The gate. Checks the definition against live metadata: the connector and operation exist,
# the declared action type matches what the operation requires, every parameter name is
# real, every required one is present, enum values are in range, and the connection
# reference resolves. Exit code 2 means findings - each carries a JSON pointer to the node.

Write-Info "`nValidating the flow against the environment..."
txc environment flow validate "src/Solutions.Logic/Workflows" --connection-check --format text
if ($LASTEXITCODE -ne 0) {
    Write-Err "Flow validation failed - fix the findings above before continuing"
    exit 1
}
Write-Ok "Flow definition valid"

# Marks the whole block done - checked instead of Test-Path on the .json so a re-run after
# a partial failure (scaffolded but not patched, or patched but not valid) retries
# everything rather than silently skipping the missing work.
Set-LabValue 'cloudFlowScaffolded' $true

} else {
    Write-Host "  ✓ Cloud flow (exists)" -ForegroundColor Green
}
