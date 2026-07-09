<#
.SYNOPSIS
    One-time (occasionally re-run) provisioning for ClientTracker on Azure:
    resource group, Azure Container Registry, Azure Database for MySQL
    Flexible Server (seeded from scripts.txt), Container Apps environment,
    and the Azure AD SPA redirect URI update for the production URL.

    Run this once, then use deploy-apps.ps1 for every subsequent code change
    (it only rebuilds/redeploys the two container images - much faster).

.PREREQUISITES
    - Azure CLI installed and `az login` already run against the correct
      tenant/subscription.
    - scripts/create-azure-ad-app-registrations.ps1 already run at least
      once (this script assumes the API and SPA app registrations exist).

.NOTES
    Writes scripts/.deploy-state.json with everything deploy-apps.ps1 needs,
    INCLUDING THE MYSQL ADMIN PASSWORD IN PLAINTEXT. Keep this file out of
    source control (see the added .gitignore entry). Azure cannot recover a
    lost MySQL password, only reset it, so this file is the only local copy.

    Pure ASCII only, and every external command is checked via Invoke-Az -
    see the notes in create-azure-ad-app-registrations.ps1 for why.
#>

param(
    [string]$ResourceGroup = "rg-clienttracker",
    [string]$Location = "eastus",
    [string]$ContainerAppsEnvName = "cae-clienttracker",
    [string]$MySqlAdminUser = "clienttrackeradmin",
    [string]$MySqlAdminPassword,
    [string]$ApiAppName = "ClientTracker API",
    [string]$SpaAppName = "ClientTracker Web"
)

$ErrorActionPreference = "Stop"

# Azure CLI is Python-based and picks its stdout encoding from the console's
# active code page at startup; Windows consoles default to a legacy code
# page that can't represent all Unicode output some az commands stream back,
# crashing the LOCAL client even when the remote operation succeeded.
# Forcing UTF-8 here avoids that class of false-failure.
$env:PYTHONIOENCODING = "utf-8"
try { & chcp 65001 | Out-Null } catch {}

function Invoke-Az {
    <#
    Runs an external az command and throws if it fails. $ErrorActionPreference
    = "Stop" does NOT catch non-zero exit codes from external commands, only
    cmdlet/.NET exceptions - without this wrapper a failed az call would
    print an error and the script would silently continue.
    #>
    param([Parameter(Mandatory)][string[]]$ArgumentList)

    $output = & az @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "az $($ArgumentList -join ' ') failed with exit code $LASTEXITCODE"
    }
    return $output
}

function Test-AzResource {
    <#
    Runs an az "show"-style command used only to check whether a resource
    exists. Unlike Invoke-Az, this does NOT throw on failure - a non-zero
    exit code (e.g. ResourceNotFound) just means "doesn't exist yet", which
    is the expected, normal outcome on a first run, not an error.

    In Windows PowerShell 5.1, a native command's stderr output becomes a
    terminating NativeCommandError when $ErrorActionPreference = "Stop",
    even when redirected to $null - the redirection doesn't happen in time
    to stop it. Temporarily relaxing the preference around just this call
    is what actually suppresses it.
    #>
    param([Parameter(Mandatory)][string[]]$ArgumentList)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & az @ArgumentList 2>$null
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    return $output
}

function Set-Utf8NoBomContent {
    <#
    Writes text to a file as UTF-8 without a BOM. Windows PowerShell 5.1's
    Set-Content -Encoding only supports old enum values (UTF8 always writes
    a BOM there; "utf8NoBOM" is a PowerShell 7+ only option) - this uses the
    underlying .NET API directly, which works the same on every version.
    #>
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Value)

    [System.IO.File]::WriteAllText($Path, $Value, (New-Object System.Text.UTF8Encoding($false)))
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptsDir = $PSScriptRoot
$stateFilePath = Join-Path $scriptsDir ".deploy-state.json"

$subscriptionId = Invoke-Az @("account", "show", "--query", "id", "-o", "tsv")
$tenantId = Invoke-Az @("account", "show", "--query", "tenantId", "-o", "tsv")
$uniqueSuffix = $subscriptionId.Substring(0, 8)

$acrName = "acrclienttracker$uniqueSuffix"
$mySqlServerName = "mysql-clienttracker-$uniqueSuffix"

if (-not $MySqlAdminPassword) {
    # Reuse the password from a previous successful run if one was saved,
    # rather than always generating a fresh one - otherwise a script that
    # crashes AFTER creating the MySQL server but BEFORE writing the state
    # file (e.g. a later step fails) leaves the real password unrecoverable,
    # since the freshly-generated one only ever existed in that run's memory.
    if (Test-Path $stateFilePath) {
        $previousState = Get-Content $stateFilePath -Raw | ConvertFrom-Json
        if ($previousState.mySqlAdminPassword) {
            $MySqlAdminPassword = $previousState.mySqlAdminPassword
            Write-Host "Reusing MySQL admin password from a previous run's state file."
        }
    }
}
if (-not $MySqlAdminPassword) {
    # Auto-generate a strong password if none was supplied or recovered.
    # Windows PowerShell 5.1 runs on .NET Framework, which lacks the newer
    # static RandomNumberGenerator.Fill(byte[]) API - use the older
    # Create()+GetBytes() instance pattern instead, which works everywhere.
    $bytes = New-Object byte[] 24
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
    } finally {
        $rng.Dispose()
    }
    $MySqlAdminPassword = [Convert]::ToBase64String($bytes) -replace '[+/=]', 'x'
    Write-Host "Generated a MySQL admin password (saved to .deploy-state.json)."
}

Write-Host "Using subscription: $subscriptionId (tenant $tenantId)"
Write-Host ""

# ---- 0. Ensure required resource providers are registered ----
# On a subscription that has never used these services, `az acr create` /
# `az containerapp env create` / `az mysql flexible-server create` fail with
# a generic exit code 1 (MissingSubscriptionRegistration) until each
# provider namespace is registered. Registration is async, so this
# registers whatever isn't already registered and then polls until done.
$requiredProviders = @(
    "Microsoft.ContainerRegistry",
    "Microsoft.App",
    "Microsoft.OperationalInsights",
    "Microsoft.DBforMySQL"
)
foreach ($ns in $requiredProviders) {
    $state = Invoke-Az @("provider", "show", "--namespace", $ns, "--query", "registrationState", "-o", "tsv")
    if ($state -ne "Registered") {
        Write-Host "Registering resource provider $ns (currently $state)..."
        Invoke-Az @("provider", "register", "--namespace", $ns) | Out-Null
    }
}
foreach ($ns in $requiredProviders) {
    $state = Invoke-Az @("provider", "show", "--namespace", $ns, "--query", "registrationState", "-o", "tsv")
    $waited = 0
    while ($state -ne "Registered" -and $waited -lt 300) {
        Write-Host "Waiting for $ns to finish registering (currently $state)..."
        Start-Sleep -Seconds 10
        $waited += 10
        $state = Invoke-Az @("provider", "show", "--namespace", $ns, "--query", "registrationState", "-o", "tsv")
    }
    if ($state -ne "Registered") {
        throw "$ns did not finish registering within 5 minutes (last state: $state). Re-run this script once it finishes - check with: az provider show --namespace $ns --query registrationState -o tsv"
    }
    Write-Host "$ns is registered."
}
Write-Host ""

# ---- 1. Resource group (idempotent - az group create is safe to re-run) ----
Invoke-Az @("group", "create", "--name", $ResourceGroup, "--location", $Location) | Out-Null
Write-Host "Resource group '$ResourceGroup' ready."

# ---- 2. Azure Container Registry (check-then-create) ----
$existingAcr = Test-AzResource @("acr", "show", "--name", $acrName, "--resource-group", $ResourceGroup, "--query", "name", "-o", "tsv")
if (-not $existingAcr) {
    Invoke-Az @("acr", "create", "--resource-group", $ResourceGroup, "--name", $acrName, "--sku", "Basic", "--admin-enabled", "true") | Out-Null
    Write-Host "Created Azure Container Registry: $acrName"
} else {
    Write-Host "Azure Container Registry '$acrName' already exists, reusing it."
}
$acrLoginServer = Invoke-Az @("acr", "show", "--name", $acrName, "--query", "loginServer", "-o", "tsv")

# ---- 3. Azure Database for MySQL Flexible Server (check-then-create) ----
$existingMySql = Test-AzResource @("mysql", "flexible-server", "show", "--name", $mySqlServerName, "--resource-group", $ResourceGroup, "--query", "name", "-o", "tsv")
if (-not $existingMySql) {
    Invoke-Az @(
        "mysql", "flexible-server", "create",
        "--resource-group", $ResourceGroup,
        "--name", $mySqlServerName,
        "--location", $Location,
        "--admin-user", $MySqlAdminUser,
        "--admin-password", $MySqlAdminPassword,
        "--sku-name", "Standard_B1ms",
        "--tier", "Burstable",
        "--storage-size", "32",
        "--public-access", "0.0.0.0",
        "--yes"
    ) | Out-Null
    Write-Host "Created MySQL Flexible Server: $mySqlServerName"
} else {
    # Force-sync the server's actual admin password to whatever this run is
    # holding. Self-healing against exactly the scenario that bit us once
    # already: a run that created the server but crashed before the
    # password could be saved, leaving a later run's held password stale.
    # Idempotent and cheap - safe to run every time the server already exists.
    Invoke-Az @("mysql", "flexible-server", "update", "--resource-group", $ResourceGroup, "--name", $mySqlServerName, "--admin-password", $MySqlAdminPassword) | Out-Null
    Write-Host "MySQL Flexible Server '$mySqlServerName' already exists, reusing it (admin password re-synced)."
}
$mySqlHost = "$mySqlServerName.mysql.database.azure.com"

# ---- 3b. Firewall rule for THIS machine's public IP ----
# --public-access 0.0.0.0 above only allows Azure-hosted services to reach
# the server (the "AllowAllAzureServicesAndResourcesWithinAzureIps" rule) -
# it does NOT allow the machine running this script to connect, which is
# required for the `az mysql flexible-server execute` seed step below (that
# command connects directly from here, not from inside Azure). Add a
# firewall rule scoped to this machine's current public IP.
$myIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
Invoke-Az @(
    "mysql", "flexible-server", "firewall-rule", "create",
    "--resource-group", $ResourceGroup,
    "--name", $mySqlServerName,
    "--rule-name", "AllowLocalMachine",
    "--start-ip-address", $myIp,
    "--end-ip-address", $myIp
) | Out-Null
Write-Host "Allowed this machine's IP ($myIp) through the MySQL firewall."

# ---- 4. Seed the database from scripts.txt (guarded - the DDL isn't IF-NOT-EXISTS-safe) ----
$installedExtensions = Invoke-Az @("extension", "list", "--query", "[?name=='rdbms-connect'].name", "-o", "tsv")
if (-not $installedExtensions) {
    Invoke-Az @("extension", "add", "--name", "rdbms-connect") | Out-Null
    Write-Host "Installed the rdbms-connect az extension."
}

$existingDb = Test-AzResource @("mysql", "flexible-server", "db", "show", "--resource-group", $ResourceGroup, "--server-name", $mySqlServerName, "--database-name", "engagement_tracker", "--query", "name", "-o", "tsv")
if (-not $existingDb) {
    $scriptsTxtPath = Join-Path $repoRoot "scripts.txt"
    Invoke-Az @(
        "mysql", "flexible-server", "execute",
        "--name", $mySqlServerName,
        "--admin-user", $MySqlAdminUser,
        "--admin-password", $MySqlAdminPassword,
        "--database-name", "information_schema",
        "--file-path", $scriptsTxtPath
    ) | Out-Null
    Write-Host "Seeded database 'engagement_tracker' from scripts.txt."
} else {
    Write-Host "Database 'engagement_tracker' already exists, skipping seed."
}

# ---- 5. Container Apps environment (check-then-create) ----
$existingEnv = Test-AzResource @("containerapp", "env", "show", "--name", $ContainerAppsEnvName, "--resource-group", $ResourceGroup, "--query", "name", "-o", "tsv")
if (-not $existingEnv) {
    Invoke-Az @("containerapp", "env", "create", "--name", $ContainerAppsEnvName, "--resource-group", $ResourceGroup, "--location", $Location) | Out-Null
    Write-Host "Created Container Apps environment: $ContainerAppsEnvName"
} else {
    Write-Host "Container Apps environment '$ContainerAppsEnvName' already exists, reusing it."
}

$defaultDomain = Invoke-Az @("containerapp", "env", "show", "--name", $ContainerAppsEnvName, "--resource-group", $ResourceGroup, "--query", "properties.defaultDomain", "-o", "tsv")
$apiFqdn = "https://clienttracker-api.$defaultDomain"
$webFqdn = "https://clienttracker-web.$defaultDomain"
Write-Host "API will be reachable at: $apiFqdn"
Write-Host "Web will be reachable at: $webFqdn"

# ---- 6. Update the Azure AD SPA redirect URIs to include the production URL ----
$adScriptPath = Join-Path $scriptsDir "create-azure-ad-app-registrations.ps1"
& $adScriptPath -ApiAppName $ApiAppName -SpaAppName $SpaAppName -SpaRedirectUris @("https://localhost:5173", $webFqdn)
if ($LASTEXITCODE -ne 0) {
    throw "create-azure-ad-app-registrations.ps1 failed with exit code $LASTEXITCODE"
}

$apiAppId = Invoke-Az @("ad", "app", "list", "--display-name", $ApiAppName, "--query", "[0].appId", "-o", "tsv")
$spaAppId = Invoke-Az @("ad", "app", "list", "--display-name", $SpaAppName, "--query", "[0].appId", "-o", "tsv")

# ---- 7. Write the state file for deploy-apps.ps1 ----
$state = [ordered]@{
    resourceGroup       = $ResourceGroup
    location            = $Location
    acrName             = $acrName
    acrLoginServer      = $acrLoginServer
    mySqlServerName     = $mySqlServerName
    mySqlHost           = $mySqlHost
    mySqlAdminUser      = $MySqlAdminUser
    mySqlAdminPassword  = $MySqlAdminPassword
    containerAppsEnvName = $ContainerAppsEnvName
    apiFqdn             = $apiFqdn
    webFqdn             = $webFqdn
    tenantId            = $tenantId
    apiClientId         = $apiAppId
    spaClientId         = $spaAppId
}
Set-Utf8NoBomContent -Path $stateFilePath -Value ($state | ConvertTo-Json)
Write-Host ""
Write-Host "Infrastructure ready. State written to $stateFilePath"
Write-Host "Next: run deploy-apps.ps1 to build and deploy the container images."
