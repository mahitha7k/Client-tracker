<#
.SYNOPSIS
    Creates (or reuses) the two Azure AD app registrations needed for
    ClientTracker: an API registration exposing an "access_as_user" scope,
    and a single-page-app registration that signs users in and requests
    access to that scope.

.PREREQUISITES
    - Azure CLI installed and `az login` already run against the correct
      tenant/subscription.
    - The signed-in principal needs Application.ReadWrite.All (or the
      Application Administrator / Cloud Application Administrator role) to
      create app registrations. Granting admin consent additionally requires
      tenant admin rights; if you don't have them, the consent step is
      skipped with a warning and users will be prompted to consent
      individually at first login instead.

.NOTES
    Idempotent: re-running this script looks up existing app registrations
    by display name and reuses them instead of creating duplicates. Display
    names are not guaranteed unique in Azure AD, so if you've manually
    created an app with the same name outside this script, rename or delete
    it first to avoid the lookup picking the wrong app.

    JSON PATCH bodies are written to temp files and passed via `--body
    @file`, not inline strings - passing complex JSON inline through
    PowerShell to the az.cmd wrapper on Windows is unreliable (quoting gets
    mangled) and fails silently rather than erroring, which is exactly what
    caused AADSTS650053 "scope doesn't exist" if you hit that before.
#>

param(
    [string]$ApiAppName = "ClientTracker API",
    [string]$SpaAppName = "ClientTracker Web",
    [string[]]$SpaRedirectUris = @("https://localhost:5173")
)

$ErrorActionPreference = "Stop"

function Invoke-Az {
    <#
    Runs an external az command and throws if it fails. Needed because
    $ErrorActionPreference = "Stop" does NOT catch non-zero exit codes from
    external commands (only cmdlet/.NET exceptions) - without this wrapper,
    a failed `az` call prints an error but the script silently continues.
    #>
    param([Parameter(Mandatory)][string[]]$ArgumentList)

    $output = & az @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "az $($ArgumentList -join ' ') failed with exit code $LASTEXITCODE"
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

$tenantId = Invoke-Az @("account", "show", "--query", "tenantId", "-o", "tsv")
Write-Host "Using tenant: $tenantId"

# ---- 1. API app registration (idempotent lookup) ----
$existingApi = Invoke-Az @("ad", "app", "list", "--display-name", $ApiAppName, "--query", "[0].appId", "-o", "tsv")
if ($existingApi) {
    Write-Host "Found existing API app registration ($existingApi), reusing it."
    $apiAppId = $existingApi
} else {
    $apiAppId = Invoke-Az @("ad", "app", "create", "--display-name", $ApiAppName, "--sign-in-audience", "AzureADMyOrg", "--query", "appId", "-o", "tsv")
    Write-Host "Created API app registration: $apiAppId"
}
$apiObjectId = Invoke-Az @("ad", "app", "show", "--id", $apiAppId, "--query", "id", "-o", "tsv")

# Ensure a service principal exists for the API app (needed for permission grants/consent).
# Wrapped in try/catch, not `2>$null` alone: in Windows PowerShell 5.1, a native
# command's stderr output becomes a terminating error under
# $ErrorActionPreference = "Stop" regardless of stream redirection - only
# try/catch reliably swallows it. Failure here is expected/benign (the SP
# already exists), so silently continuing is correct.
try { & az ad sp create --id $apiAppId 2>$null | Out-Null } catch {}

# ---- 2. Set the API's App ID URI ----
Invoke-Az @("ad", "app", "update", "--id", $apiAppId, "--identifier-uris", "api://$apiAppId") | Out-Null
Write-Host "Set API App ID URI to api://$apiAppId"

# ---- 3. Define the access_as_user scope ----
# `az ad app` has no flag for exposed scopes; this must go through a Graph PATCH.
$existingScopeId = Invoke-Az @("ad", "app", "show", "--id", $apiAppId, "--query", "api.oauth2PermissionScopes[?value=='access_as_user'].id | [0]", "-o", "tsv")
if ($existingScopeId) {
    Write-Host "Scope 'access_as_user' already exists ($existingScopeId), reusing it."
    $scopeId = $existingScopeId
} else {
    $scopeId = [guid]::NewGuid().ToString()
    $scopeBody = @{
        api = @{
            oauth2PermissionScopes = @(
                @{
                    id                      = $scopeId
                    adminConsentDescription = "Allows the app to access ClientTracker API on behalf of the signed-in user."
                    adminConsentDisplayName = "Access ClientTracker API as user"
                    userConsentDescription  = "Allow the app to access ClientTracker API on your behalf."
                    userConsentDisplayName  = "Access ClientTracker API"
                    value                   = "access_as_user"
                    type                    = "User"
                    isEnabled               = $true
                }
            )
        }
    } | ConvertTo-Json -Depth 10

    $scopeBodyFile = New-TemporaryFile
    Set-Utf8NoBomContent -Path $scopeBodyFile -Value $scopeBody
    try {
        Invoke-Az @("rest", "--method", "PATCH", "--uri", "https://graph.microsoft.com/v1.0/applications/$apiObjectId", "--headers", "Content-Type=application/json", "--body", "@$scopeBodyFile") | Out-Null
    } finally {
        Remove-Item $scopeBodyFile -ErrorAction SilentlyContinue
    }

    # Verify it actually landed - the whole point of this rewrite.
    $verifyScopeId = Invoke-Az @("ad", "app", "show", "--id", $apiAppId, "--query", "api.oauth2PermissionScopes[?value=='access_as_user'].id | [0]", "-o", "tsv")
    if (-not $verifyScopeId) {
        throw "Scope 'access_as_user' was not found on the API app after the PATCH. The Graph call may have failed silently - check your account has Application.ReadWrite.All rights."
    }
    Write-Host "Configured scope 'access_as_user' ($scopeId) on API app."
}

# ---- 4. SPA app registration (idempotent lookup) ----
$existingSpa = Invoke-Az @("ad", "app", "list", "--display-name", $SpaAppName, "--query", "[0].appId", "-o", "tsv")
if ($existingSpa) {
    Write-Host "Found existing SPA app registration ($existingSpa), reusing it."
    $spaAppId = $existingSpa
} else {
    $spaAppId = Invoke-Az @("ad", "app", "create", "--display-name", $SpaAppName, "--sign-in-audience", "AzureADMyOrg", "--query", "appId", "-o", "tsv")
    Write-Host "Created SPA app registration: $spaAppId"
}
$spaObjectId = Invoke-Az @("ad", "app", "show", "--id", $spaAppId, "--query", "id", "-o", "tsv")
try { & az ad sp create --id $spaAppId 2>$null | Out-Null } catch {}

# ---- 5. Set SPA platform + redirect URIs ----
# `az ad app` cannot write spa.redirectUris either - only web.redirectUris. Graph PATCH required.
# The PATCH REPLACES the whole redirectUris array, so every URI that should stay
# registered (e.g. localhost for local dev alongside a production URL) must be
# passed together in $SpaRedirectUris - passing just one drops the others.
$spaBody = @{ spa = @{ redirectUris = @($SpaRedirectUris) } } | ConvertTo-Json -Depth 5
$spaBodyFile = New-TemporaryFile
Set-Utf8NoBomContent -Path $spaBodyFile -Value $spaBody
try {
    Invoke-Az @("rest", "--method", "PATCH", "--uri", "https://graph.microsoft.com/v1.0/applications/$spaObjectId", "--headers", "Content-Type=application/json", "--body", "@$spaBodyFile") | Out-Null
} finally {
    Remove-Item $spaBodyFile -ErrorAction SilentlyContinue
}

$verifyRedirects = Invoke-Az @("ad", "app", "show", "--id", $spaAppId, "--query", "spa.redirectUris", "-o", "tsv")
foreach ($uri in $SpaRedirectUris) {
    if ($verifyRedirects -notcontains $uri) {
        throw "SPA redirect URI '$uri' was not found after the PATCH. Got: $verifyRedirects"
    }
}
Write-Host "Set SPA redirect URIs to: $($SpaRedirectUris -join ', ')"

# ---- 6. Grant SPA delegated permission to the API's access_as_user scope ----
Invoke-Az @("ad", "app", "permission", "add", "--id", $spaAppId, "--api", $apiAppId, "--api-permissions", "$scopeId=Scope") | Out-Null

# Optional: admin-consent immediately so users aren't blocked by a "users cannot consent" tenant policy
try {
    Invoke-Az @("ad", "app", "permission", "admin-consent", "--id", $spaAppId) | Out-Null
    Write-Host "Admin consent granted."
} catch {
    Write-Warning "Admin consent failed (likely insufficient privileges). Users may need to consent individually at first login, or ask a tenant admin to run: az ad app permission admin-consent --id $spaAppId"
}

# ---- 7. Output everything needed for config ----
Write-Host ""
Write-Host "=== Copy these into your app config ==="
Write-Host "Tenant Id:            $tenantId"
Write-Host "API App (client) Id:  $apiAppId"
Write-Host "API App ID URI:       api://$apiAppId"
Write-Host "API Scope value:      access_as_user"
Write-Host "SPA App (client) Id:  $spaAppId"
Write-Host "SPA Redirect URIs:    $($SpaRedirectUris -join ', ')"
Write-Host ""
Write-Host "appsettings.json (ClientTracker.Api) AzureAd section:"
Write-Host "  TenantId: $tenantId"
Write-Host "  ClientId: $apiAppId"
Write-Host "  Audience: api://$apiAppId"
Write-Host ""
Write-Host ".env (ClientTracker.Web):"
Write-Host "  VITE_AZURE_CLIENT_ID=$spaAppId"
Write-Host "  VITE_AZURE_TENANT_ID=$tenantId"
Write-Host "  VITE_API_SCOPE=api://$apiAppId/access_as_user"
