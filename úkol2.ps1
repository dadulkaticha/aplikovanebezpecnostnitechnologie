<# ======================================================================
 Ukol2.ps1 — ÚKOL 2
====================================================================== #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section([string]$Title) {
    $line = ('=' * 80)
    Write-Host "`n$line" -ForegroundColor DarkGray
    Write-Host $Title -ForegroundColor Cyan
    Write-Host $line -ForegroundColor DarkGray
}

#Kořen skriptu pro výstupy
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$outDir = Join-Path $ScriptRoot 'out'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$AliasesJson = Join-Path $outDir 'aliases.json'

# ---------- A) Úprava profilu ----------
Write-Section "ÚKOL 2A — Úprava profilu (ExecutionPolicy + Profile path v barvách)"

$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }

$markerStart = '# === ChatGPT: EP a profil echo ==='
$markerEnd   = '# === /ChatGPT ==='
$snippet = @"
$markerStart
try {
  \$ep = Get-ExecutionPolicy
  Write-Host ("Execution Policy: {0}" -f \$ep) -ForegroundColor Yellow
  Write-Host ("Profile path: {0}" -f \$PROFILE) -ForegroundColor Green
} catch {}
$markerEnd
"@

$current = Get-Content -Raw $PROFILE
if ($current -notmatch [regex]::Escape($markerStart)) {
  Add-Content -Path $PROFILE -Value "`r`n$snippet`r`n"
  Write-Host "Snippet přidán do profilu: $PROFILE" -ForegroundColor Green
} else {
  Write-Host "Snippet už v profilu existuje — nic nepřidáno." -ForegroundColor Yellow
}

#Okamžité načtení profilu
. $PROFILE

# ---------- B) Alias np/ct: export → smazat → import ----------
Write-Section "ÚKOL 2B — Alias np/ct → Export JSON → Smazat → Import JSON"

#Vytvoření alias
Set-Alias -Name np -Value notepad.exe -Force
Set-Alias -Name ct -Value control.exe -Force
Write-Host "Alias(y) vytvořeny: np -> notepad.exe, ct -> control.exe" -ForegroundColor Green

#Export do JSON
$aliasList = Get-Alias | Where-Object { $_.Name -in @('np','ct') } |
  Select-Object Name, Definition
$aliasList | ConvertTo-Json | Set-Content -Path $AliasesJson -Encoding UTF8
Write-Host "Export hotov: $AliasesJson" -ForegroundColor Green

#Smazání alias
Remove-Item alias:np -ErrorAction SilentlyContinue
Remove-Item alias:ct -ErrorAction SilentlyContinue
Write-Host "Alias(y) np/ct smazány." -ForegroundColor Yellow

#Import z JSON
$import = Get-Content -Raw $AliasesJson | ConvertFrom-Json
if ($import -isnot [System.Collections.IEnumerable] -or $import -is [string]) { $import = @($import) }
foreach ($a in $import) {
  if ($a.Name -and $a.Definition) {
    Set-Alias -Name $a.Name -Value $a.Definition -Force
  }
}
Write-Host "Alias(y) obnoveny z JSON." -ForegroundColor Green

#Ověření
Get-Alias np, ct | Format-Table Name, Definition
