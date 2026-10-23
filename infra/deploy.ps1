param(
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [string] $AlertEmail,
    [string] $Location = 'francecentral'
)

$ErrorActionPreference = 'Stop'

function Assert-Ok($msg) {
    if ($LASTEXITCODE -ne 0) { throw $msg }
}

$stopwatch = [Diagnostics.Stopwatch]::StartNew()

Write-Host "1/3 Creating resource group $ResourceGroup..."
az group create -n $ResourceGroup -l $Location --tags app=backup-system costcenter=portfolio env=lab | Out-Null
Assert-Ok 'Resource group creation failed'

Write-Host '2/3 Deploying Bicep...'
$outputs = az deployment group create -g $ResourceGroup -f "$PSScriptRoot\main.bicep" --parameters alertEmail=$AlertEmail --query properties.outputs -o json | ConvertFrom-Json
Assert-Ok 'Bicep deployment failed'

$src = $outputs.sourceName.value
$rep = $outputs.replicaName.value

Write-Host '3/3 Configuring object replication...'
& "$PSScriptRoot\scripts\configure-replication.ps1" -ResourceGroup $ResourceGroup -SourceAccount $src -ReplicaAccount $rep

$stopwatch.Stop()
Write-Host ''
Write-Host ("Done in {0:N0} seconds." -f $stopwatch.Elapsed.TotalSeconds)
Write-Host "Source: $src"
Write-Host "Replica: $rep"
Write-Host 'Manual step remaining: authorize the Outlook connection (portal, API Connections, outlook, Edit API connection, Authorize, Save).'