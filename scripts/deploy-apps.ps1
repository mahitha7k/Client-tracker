<#
.SYNOPSIS
    Builds both container images (via az acr build - no local Docker daemon
    required) and deploys/updates the two Container Apps. Run this after
    deploy-infrastructure.ps1 has run at least once, and every time after
    for code changes - it's the fast, repeatable inner loop.

.PREREQUISITES
    - deploy-infrastructure.ps1 has been run and scripts/.deploy-state.json
      exists.

.NOTES
    Pure ASCII only, every external command checked via Invoke-Az - see
    create-azure-ad-app-registrations.ps1 for why.
#>

param(
    [string]$Tag = (Get-Date -Format "yyyyMMddHHmmss")
)

$ErrorActionPreference = "Stop"

# `az acr build` streams the remote Docker build log to this console,
# including characters like the checkmark npm/Vite print on success (U+2713).
# Azure CLI is Python-based and picks its stdout encoding from the console's
# active code page at startup; Windows consoles default to a legacy code
# page (e.g. cp1252) that can't represent that character, crashing the LOCAL
# az client with UnicodeEncodeError even though the REMOTE build succeeded.
# Forcing UTF-8 here avoids that false-failure.
$env:PYTHONIOENCODING = "utf-8"
try { & chcp 65001 | Out-Null } catch {}

function Invoke-Az {
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

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptsDir = $PSScriptRoot
$stateFilePath = Join-Path $scriptsDir ".deploy-state.json"

if (-not (Test-Path $stateFilePath)) {
    throw "State file not found at $stateFilePath. Run deploy-infrastructure.ps1 first."
}
$state = Get-Content $stateFilePath -Raw | ConvertFrom-Json

$apiImage = "$($state.acrLoginServer)/clienttracker-api:$Tag"
$webImage = "$($state.acrLoginServer)/clienttracker-web:$Tag"

# ---- 1. Build the API image (az acr build - no local Docker daemon needed) ----
# --no-logs: az acr build normally streams the remote build log to this
# console, and that log can contain Unicode characters (e.g. npm/Vite's
# success checkmark) that crash the LOCAL az client on Windows consoles
# using a legacy code page (cp1252) - the remote build itself succeeds
# regardless, but the local client reports a false failure. --no-logs skips
# streaming that content; the command still blocks until the build finishes
# and still returns a real exit code, so failure detection is unaffected.
Write-Host "Building API image: $apiImage"
Invoke-Az @(
    "acr", "build",
    "--registry", $state.acrName,
    "--image", "clienttracker-api:$Tag",
    "--file", (Join-Path $repoRoot "src/ClientTracker.Api/Dockerfile"),
    "--no-logs",
    (Join-Path $repoRoot "src/ClientTracker.Api")
) | Out-Null

# ---- 2. Build the Web image (VITE_* values baked in at build time) ----
Write-Host "Building Web image: $webImage"
Invoke-Az @(
    "acr", "build",
    "--registry", $state.acrName,
    "--image", "clienttracker-web:$Tag",
    "--file", (Join-Path $repoRoot "src/ClientTracker.Web/Dockerfile"),
    "--build-arg", "VITE_API_BASE_URL=$($state.apiFqdn)",
    "--build-arg", "VITE_AZURE_CLIENT_ID=$($state.spaClientId)",
    "--build-arg", "VITE_AZURE_TENANT_ID=$($state.tenantId)",
    "--build-arg", "VITE_API_SCOPE=api://$($state.apiClientId)/access_as_user",
    "--no-logs",
    (Join-Path $repoRoot "src/ClientTracker.Web")
) | Out-Null

$acrUsername = Invoke-Az @("acr", "credential", "show", "--name", $state.acrName, "--query", "username", "-o", "tsv")
$acrPassword = Invoke-Az @("acr", "credential", "show", "--name", $state.acrName, "--query", "passwords[0].value", "-o", "tsv")

# ---- 3. Deploy/update the API container app ----
$existingApiApp = Test-AzResource @("containerapp", "show", "--name", "clienttracker-api", "--resource-group", $state.resourceGroup, "--query", "name", "-o", "tsv")
if (-not $existingApiApp) {
    $mySqlConnectionString = "Server=$($state.mySqlHost);Port=3306;Database=engagement_tracker;User Id=$($state.mySqlAdminUser);Password=$($state.mySqlAdminPassword);SslMode=Required;"

    Invoke-Az @(
        "containerapp", "create",
        "--name", "clienttracker-api",
        "--resource-group", $state.resourceGroup,
        "--environment", $state.containerAppsEnvName,
        "--image", $apiImage,
        "--target-port", "8080",
        "--ingress", "external",
        "--registry-server", $state.acrLoginServer,
        "--registry-username", $acrUsername,
        "--registry-password", $acrPassword,
        "--secrets", "mysql-conn-string=$mySqlConnectionString",
        "--env-vars",
            "ConnectionStrings__EngagementTracker=secretref:mysql-conn-string",
            "AzureAd__Instance=https://login.microsoftonline.com/",
            "AzureAd__TenantId=$($state.tenantId)",
            "AzureAd__ClientId=$($state.apiClientId)",
            "AzureAd__Audience=api://$($state.apiClientId)",
            "Cors__AllowedOrigins=$($state.webFqdn)",
            "ASPNETCORE_ENVIRONMENT=Production"
    ) | Out-Null
    Write-Host "Created Container App: clienttracker-api"
} else {
    Invoke-Az @("containerapp", "update", "--name", "clienttracker-api", "--resource-group", $state.resourceGroup, "--image", $apiImage) | Out-Null
    Write-Host "Updated Container App: clienttracker-api -> $Tag"
}

# ---- 4. Deploy/update the Web container app ----
$existingWebApp = Test-AzResource @("containerapp", "show", "--name", "clienttracker-web", "--resource-group", $state.resourceGroup, "--query", "name", "-o", "tsv")
if (-not $existingWebApp) {
    Invoke-Az @(
        "containerapp", "create",
        "--name", "clienttracker-web",
        "--resource-group", $state.resourceGroup,
        "--environment", $state.containerAppsEnvName,
        "--image", $webImage,
        "--target-port", "80",
        "--ingress", "external",
        "--registry-server", $state.acrLoginServer,
        "--registry-username", $acrUsername,
        "--registry-password", $acrPassword
    ) | Out-Null
    Write-Host "Created Container App: clienttracker-web"
} else {
    Invoke-Az @("containerapp", "update", "--name", "clienttracker-web", "--resource-group", $state.resourceGroup, "--image", $webImage) | Out-Null
    Write-Host "Updated Container App: clienttracker-web -> $Tag"
}

# ---- 5. Verify both apps' actual FQDNs match what was precomputed ----
$actualApiFqdn = "https://" + (Invoke-Az @("containerapp", "show", "--name", "clienttracker-api", "--resource-group", $state.resourceGroup, "--query", "properties.configuration.ingress.fqdn", "-o", "tsv"))
$actualWebFqdn = "https://" + (Invoke-Az @("containerapp", "show", "--name", "clienttracker-web", "--resource-group", $state.resourceGroup, "--query", "properties.configuration.ingress.fqdn", "-o", "tsv"))

if ($actualApiFqdn -ne $state.apiFqdn) {
    throw "API FQDN mismatch: expected $($state.apiFqdn), got $actualApiFqdn"
}
if ($actualWebFqdn -ne $state.webFqdn) {
    throw "Web FQDN mismatch: expected $($state.webFqdn), got $actualWebFqdn"
}

Write-Host ""
Write-Host "Deployed successfully."
Write-Host "API: $($state.apiFqdn)"
Write-Host "Web: $($state.webFqdn)"
