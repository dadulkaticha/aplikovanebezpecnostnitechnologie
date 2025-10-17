<# ======================================================================
 Ukol1.ps1 — ÚKOL 1
====================================================================== #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section([string]$Title) {
    $line = ('=' * 80)
    Write-Host "`n$line" -ForegroundColor DarkGray
    Write-Host $Title -ForegroundColor Cyan
    Write-Host $line -ForegroundColor DarkGray
}

# ---------- A) Události System logu ----------
Write-Section "ÚKOL 1A — Události ze System logu (10 dní, Error→Warning fallback)"

$Start = (Get-Date).AddDays(-10)

# "Chyba"
$events = Get-WinEvent -FilterHashtable @{
  LogName   = 'System'
  Level     = 2
  StartTime = $Start
} -ErrorAction SilentlyContinue

if (-not $events -or $events.Count -eq 0) {
  Write-Host "Žádné 'Chyba' události — zobrazím 'Upozornění'." -ForegroundColor Yellow
  $events = Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Level     = 3
    StartTime = $Start
  } -ErrorAction SilentlyContinue
} else {
  Write-Host "Nalezeny události typu 'Chyba'." -ForegroundColor Green
}

if (-not $events -or $events.Count -eq 0) {
  Write-Host "Za posledních 10 dní nebyly nalezeny ani 'Chyba' ani 'Upozornění'." -ForegroundColor Yellow
} else {
  $events |
    Select-Object TimeCreated, Id, ProviderName, LevelDisplayName,
      @{ n='Message'; e={ $_.Message -replace '\s+',' ' } } |
    Format-Table -AutoSize -Wrap
}

# ---------- B) HEX → ASCII ----------
Write-Section "ÚKOL 1B — Konverze HEX → ASCII"

# Zadaný řetězec
$Hex = "506f7765727368656c6c20697320617765736f6d6521"
Write-Host "Vstupní HEX: $Hex" -ForegroundColor DarkCyan

if ($Hex -notmatch '^[0-9A-Fa-f]+$') { throw "HEX řetězec obsahuje neplatné znaky." }
if ($Hex.Length % 2 -ne 0) { throw "HEX řetězec musí mít sudý počet znaků." }

$bytes = for ($i = 0; $i -lt $Hex.Length; $i += 2) {
  [Convert]::ToByte($Hex.Substring($i, 2), 16)
}

$text = [System.Text.Encoding]::ASCII.GetString($bytes)
Write-Host "Výstupní ASCII:" -ForegroundColor Green
Write-Host $text
