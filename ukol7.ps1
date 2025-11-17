###############################################
# Skript: Získání teploty v Brně + naplánování
###############################################

# --- Funkce pro získání teploty a zápis do souboru ---
function ZapisTeplotu {
    $apiUrl = "https://wttr.in/Brno?format=%t"
    $teplota = Invoke-RestMethod -Uri $apiUrl

    $desktop = [Environment]::GetFolderPath("Desktop")
    $soubor = Join-Path $desktop "teploty.txt"

    $cas = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$cas - $teplota" | Out-File -FilePath $soubor -Append -Encoding UTF8
}

# --- Zavolání funkce při prvním spuštění ---
ZapisTeplotu

# --- Vytvoření hodinové naplánované úlohy ---
$scriptPath = "$env:USERPROFILE\Desktop\get-teplota.ps1"

# Uložení malého skriptu, který se bude spouštět každou hodinu
@"
`$apiUrl = "https://wttr.in/Brno?format=%t"
`$teplota = Invoke-RestMethod -Uri `$apiUrl
`$desktop = [Environment]::GetFolderPath("Desktop")
`$soubor = Join-Path `$desktop "teploty.txt"
`$cas = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"`$cas - `$teplota" | Out-File -FilePath `$soubor -Append -Encoding UTF8
"@ | Out-File -FilePath $scriptPath -Encoding UTF8


# --- Naplánování úlohy ---
$trigger = New-ScheduledTaskTrigger -Hourly -At (Get-Date).AddMinutes(1).TimeOfDay
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$scriptPath`""

Register-ScheduledTask `
    -TaskName "ZapisTeplotyBrno" `
    -Trigger $trigger `
    -Action $action `
    -Description "Zapisuje kazdou hodinu aktualni teplotu v Brne" `
    -User $env:USERNAME

Write-Host "Úloha byla vytvořena. Teploty se začnou zapisovat každou hodinu." -ForegroundColor Green
