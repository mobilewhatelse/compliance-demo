<#
.SYNOPSIS
    Imports EQ Online Services demo data into a Dataverse environment via the Web API.

.DESCRIPTION
    Reads the JSON files in this folder and upserts all records via Dataverse OData API.
    Uses PAC CLI to obtain a Bearer token from the current auth profile.
    Records are upserted (created or updated) so the script is safe to run multiple times.

.PREREQUISITES
    - PAC CLI installed and authenticated: pac auth create -u https://your-env.crm.dynamics.com
    - PowerShell 5.1 or later
    - Dataverse tables created (deploy the solution first)

.USAGE
    cd "C:\Users\kraemhel\OneDrive - Tietoevry\ClaudeCode\EQ-OnlineServices\dataverse\demo-data"
    .\import-demo-data.ps1

    Override environment URL:
    .\import-demo-data.ps1 -EnvUrl "https://contoso.crm.dynamics.com"
#>

param(
    [string]$EnvUrl = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-Step  { param($msg) Write-Host "`n► $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red }

function Get-EnvUrl {
    Write-Step "Detecting environment URL from PAC CLI..."
    try {
        $who = pac env who 2>&1 | Out-String
        if ($who -match 'https://[^\s/]+\.crm[0-9]*\.dynamics\.com') {
            return $Matches[0].TrimEnd('/')
        }
    } catch {}
    throw "Could not detect environment URL. Run: pac auth create -u https://your-env.crm.dynamics.com"
}

function Get-BearerToken {
    param([string]$url)
    Write-Step "Obtaining Bearer token from PAC CLI..."

    # pac auth token is available in PAC CLI >= 1.28
    try {
        $token = pac auth token --environment $url 2>&1
        if ($token -match '^eyJ') { return $token.Trim() }
    } catch {}

    # Fallback: ask user to paste a token from the browser
    Write-Warn "pac auth token not available. Please supply a Bearer token manually."
    Write-Host "  Get one via: https://YOUR-ENV.crm.dynamics.com/api/data/v9.2/" -ForegroundColor Gray
    Write-Host "  (Open the URL in a browser while signed in, copy the token from DevTools → Network)" -ForegroundColor Gray
    $token = Read-Host "  Paste Bearer token"
    if (-not $token) { throw "No token provided." }
    return $token.Trim()
}

function Invoke-DataverseUpsert {
    param(
        [hashtable]$Headers,
        [string]    $BaseUrl,
        [string]    $EntitySet,
        [string]    $PrimaryKey,
        [object[]]  $Records
    )

    $ok = 0; $fail = 0
    foreach ($rec in $Records) {
        $id    = $rec.$PrimaryKey
        $uri   = "$BaseUrl/api/data/v9.2/${EntitySet}($id)"
        $body  = $rec | ConvertTo-Json -Depth 5

        try {
            Invoke-RestMethod -Method Patch -Uri $uri -Headers $Headers -Body $body -ContentType "application/json" | Out-Null
            $ok++
        } catch {
            $fail++
            Write-Warn "Failed $id — $($_.Exception.Message)"
        }
    }
    return @{ Ok = $ok; Fail = $fail }
}

function Read-DemoJson {
    param([string]$File)
    $raw = Get-Content $File -Raw -Encoding UTF8
    # Strip JS-style line comments (// ...) so ConvertFrom-Json doesn't choke
    $raw = $raw -replace '(?m)\s*//.*$', ''
    return $raw | ConvertFrom-Json
}

function Expand-Lookups {
    <#
      Converts shorthand lookup properties like:
        "eq_product_lookup": "11111111-..."
      into the Dataverse bind syntax:
        "eq_product@odata.bind": "/eq_products(11111111-...)"
      This avoids having to set navigation properties server-side.
    #>
    param([object[]]$Records, [hashtable]$LookupMap)

    $result = @()
    foreach ($rec in $Records) {
        $dict = [ordered]@{}
        foreach ($prop in $rec.PSObject.Properties) {
            if ($prop.Name -match '^(.+)_lookup$') {
                $field   = $Matches[1]
                $setName = $LookupMap[$field]
                if ($setName) {
                    $dict["${field}@odata.bind"] = "/$setName($($prop.Value))"
                }
            } else {
                $dict[$prop.Name] = $prop.Value
            }
        }
        $result += $dict
    }
    return $result
}

# ── Main ─────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  EQ Online Services — Demo Data Import" -ForegroundColor Magenta
Write-Host "  voestalpine Böhler Welding" -ForegroundColor Magenta
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Magenta

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. Resolve environment URL
if (-not $EnvUrl) { $EnvUrl = Get-EnvUrl }
Write-Ok "Environment: $EnvUrl"

# 2. Get token
$token = Get-BearerToken -url $EnvUrl

$headers = @{
    "Authorization"    = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
    "Accept"           = "application/json"
    "Prefer"           = "return=minimal"
}

# Lookup field → entity set name mapping
$lookupMap = @{
    "eq_product"  = "eq_products"
    "eq_warranty" = "eq_warranties"
}

$total = @{ Ok = 0; Fail = 0 }

# ── 1. Products ───────────────────────────────────────────────────────────────
Write-Step "Importing products (6 records)..."
$products = Read-DemoJson "$scriptDir\products.json"
$r = Invoke-DataverseUpsert -Headers $headers -BaseUrl $EnvUrl `
     -EntitySet "eq_products" -PrimaryKey "eq_productid" -Records $products
Write-Ok "$($r.Ok) products upserted, $($r.Fail) failed"
$total.Ok += $r.Ok; $total.Fail += $r.Fail

# ── 2. Documents ─────────────────────────────────────────────────────────────
Write-Step "Importing documents (15 records)..."
$docs = Read-DemoJson "$scriptDir\documents.json"
$docs = Expand-Lookups -Records $docs -LookupMap $lookupMap
$r = Invoke-DataverseUpsert -Headers $headers -BaseUrl $EnvUrl `
     -EntitySet "eq_documents" -PrimaryKey "eq_documentid" -Records $docs
Write-Ok "$($r.Ok) documents upserted, $($r.Fail) failed"
$total.Ok += $r.Ok; $total.Fail += $r.Fail

# ── 3. Warranties ─────────────────────────────────────────────────────────────
Write-Step "Importing warranties (4 records)..."
$warranties = Read-DemoJson "$scriptDir\warranties.json"
$warranties = Expand-Lookups -Records $warranties -LookupMap $lookupMap
$r = Invoke-DataverseUpsert -Headers $headers -BaseUrl $EnvUrl `
     -EntitySet "eq_warranties" -PrimaryKey "eq_warrantyid" -Records $warranties
Write-Ok "$($r.Ok) warranties upserted, $($r.Fail) failed"
$total.Ok += $r.Ok; $total.Fail += $r.Fail

# ── 4. Service Tickets ────────────────────────────────────────────────────────
Write-Step "Importing service tickets (4 records)..."
$tickets = Read-DemoJson "$scriptDir\servicetickets.json"
$tickets = Expand-Lookups -Records $tickets -LookupMap $lookupMap
$r = Invoke-DataverseUpsert -Headers $headers -BaseUrl $EnvUrl `
     -EntitySet "eq_servicetickets" -PrimaryKey "eq_serviceticketid" -Records $tickets
Write-Ok "$($r.Ok) tickets upserted, $($r.Fail) failed"
$total.Ok += $r.Ok; $total.Fail += $r.Fail

# ── 5. Spare Parts ────────────────────────────────────────────────────────────
Write-Step "Importing spare parts (10 records)..."
$parts = Read-DemoJson "$scriptDir\spareparts.json"
$parts = Expand-Lookups -Records $parts -LookupMap $lookupMap
$r = Invoke-DataverseUpsert -Headers $headers -BaseUrl $EnvUrl `
     -EntitySet "eq_spareparts" -PrimaryKey "eq_sparepartid" -Records $parts
Write-Ok "$($r.Ok) parts upserted, $($r.Fail) failed"
$total.Ok += $r.Ok; $total.Fail += $r.Fail

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Magenta
if ($total.Fail -eq 0) {
    Write-Host "  ✓ All $($total.Ok) records imported successfully!" -ForegroundColor Green
} else {
    Write-Host "  $($total.Ok) records OK, $($total.Fail) failed — check warnings above" -ForegroundColor Yellow
}
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

Write-Host "Demo serial numbers for Warranty Check:" -ForegroundColor Cyan
Write-Host "  TRX-2025-00001234  →  Active warranty (~600 days remaining)" -ForegroundColor White
Write-Host "  UNX-2024-00005678  →  Expiring soon (~27 days)" -ForegroundColor White
Write-Host "  TRX-2023-00009999  →  Expired (March 2025)" -ForegroundColor White
Write-Host "  UNKNOWN-SERIAL-XXX →  Not found (any unknown number)" -ForegroundColor White
Write-Host ""
