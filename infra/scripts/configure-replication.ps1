param(
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [string] $SourceAccount,
    [Parameter(Mandatory)] [string] $ReplicaAccount,
    [string] $Container = 'client-docs'
)

$ErrorActionPreference = 'Stop'

function Assert-Ok($msg) {
    if ($LASTEXITCODE -ne 0) { throw $msg }
}

$sub   = az account show --query id -o tsv
$acct  = "/subscriptions/$sub/resourceGroups/$ResourceGroup/providers/Microsoft.Storage/storageAccounts"
$base  = "https://management.azure.com$acct"
$api   = 'api-version=2023-05-01'
$srcId = "$acct/$SourceAccount"
$repId = "$acct/$ReplicaAccount"
$tmp   = Join-Path $env:TEMP 'or-policy.json'

function Get-ReplicaPolicy {
    $list = az rest --method get --url "$base/$ReplicaAccount/objectReplicationPolicies?$api" | ConvertFrom-Json
    Assert-Ok 'Could not list policies on the replica'
    $list.value | Where-Object { $_.properties.sourceAccount -ieq $srcId } | Select-Object -First 1
}

# 1. Destination policy first (created under the name 'default', stored under a generated ID)
$policy = Get-ReplicaPolicy
if (-not $policy) {
    Write-Host 'Creating policy on the replica...'
    $body = @{ properties = @{
        sourceAccount      = $srcId
        destinationAccount = $repId
        rules              = @(@{ sourceContainer = $Container; destinationContainer = $Container })
    } } | ConvertTo-Json -Depth 6 -Compress
    Set-Content -Path $tmp -Value $body -Encoding ascii
    az rest --method put --url "$base/$ReplicaAccount/objectReplicationPolicies/default?$api" --body "@$tmp" | Out-Null
    Assert-Ok 'Creating the replica policy failed'
    $policy = Get-ReplicaPolicy
    if (-not $policy) { throw 'Replica policy not found after creation' }
} else {
    Write-Host 'Replica policy already exists, reusing it.'
}

$policyId = $policy.properties.policyId
$ruleId   = $policy.properties.rules[0].ruleId

# 2. Source policy, using the generated policy and rule IDs
Write-Host "Applying policy $policyId on the source..."
$body = @{ properties = @{
    sourceAccount      = $srcId
    destinationAccount = $repId
    rules              = @(@{ ruleId = $ruleId; sourceContainer = $Container; destinationContainer = $Container })
} } | ConvertTo-Json -Depth 6 -Compress
Set-Content -Path $tmp -Value $body -Encoding ascii
az rest --method put --url "$base/$SourceAccount/objectReplicationPolicies/${policyId}?$api" --body "@$tmp" | Out-Null
Assert-Ok 'Creating the source policy failed'

Remove-Item $tmp -ErrorAction SilentlyContinue
Write-Host "Object replication configured. Policy ID: $policyId"