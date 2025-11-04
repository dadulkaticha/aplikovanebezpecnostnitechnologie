<# =====================================================================
 ÚKOL 4: Práce s registrem
===================================================================== #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------
# 1) Kontrola a nastavení NumLocku při přihlášení
# ---------------------------------------------------------------------
function Set-NumLockAtLogon {
    [CmdletBinding()]
    param(
        [ValidateSet(0,1,2)]
        [int]$Value = 2
    )
    $regPath = "HKCU:\Control Panel\Keyboard"
    $regKey  = "InitialKeyboardIndicators"

    try {
        $current = (Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction Stop).$regKey
    } catch {
        Write-Host "Klíč '$regKey' nebyl nalezen, bude vytvořen."
        $current = $null
    }

    if ($current -ne $Value) {
        Write-Host "Hodnota NumLock není $Value (aktuálně '$current'). Nastavuji na $Value..."
        New-Item -Path $regPath -Force | Out-Null
        Set-ItemProperty -Path $regPath -Name $regKey -Value $Value
        Write-Host "Hodnota '$regKey' nastavena na $Value."
        Write-Host "Pozn.: Projeví se po příštím odhlášení/přihlášení."
    } else {
        Write-Host "Hodnota '$regKey' je již správně nastavena na $Value."
    }
}

# ---------------------------------------------------------------------
# 2) Vytvoření a naplnění podklíče registru
# ---------------------------------------------------------------------
function Initialize-PlaygroundRegistryKey {
    [CmdletBinding()]
    param(
        [string]$KeyPath = "HKCU:\Hrátky s PowerShellem"
    )

    Write-Host "Vytvářím (pokud neexistuje) klíč: $KeyPath"
    New-Item -Path $KeyPath -Force | Out-Null

    Write-Host "Nastavuji hodnoty..."
    Set-ItemProperty -Path $KeyPath -Name "UživatelskýÚčet"   -Value $env:USERNAME
    Set-ItemProperty -Path $KeyPath -Name "JménoPočítače"     -Value $env:COMPUTERNAME
    Set-ItemProperty -Path $KeyPath -Name "AktuálníDatum"     -Value (Get-Date -Format "dd.MM.yyyy HH:mm:ss")
    Set-ItemProperty -Path $KeyPath -Name "VerzePowerShellu"  -Value $PSVersionTable.PSVersion.ToString()

    Write-Host "Hotovo. Ověřuji obsah klíče..."
    Get-ItemProperty -Path $KeyPath | Format-List
}
