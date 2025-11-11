<# =====================================================================
 ÚKOL 4: Práce s registrem (aktualizováno dle připomínek)
 - Pro nastavení NumLocku před přihlášením je potřeba měnit větev
   HKU\.DEFAULT\Control Panel\Keyboard\InitialKeyboardIndicators
   (ta ovlivní stav na přihlašovací obrazovce, když není nikdo přihlášen).
 - Varianta pro HKCU zůstává pro informaci / uživatelský profil.
===================================================================== #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------
# 1) Nastavení NumLocku na PŘIHLAŠOVACÍ OBRAZOVCE (před přihlášením)
#    -> vyžaduje oprávnění ke změně HKU\.DEFAULT (typicky admin)
# ---------------------------------------------------------------------
function Set-PrelogonNumLock {
    [CmdletBinding()]
    param(
        [ValidateSet(0,1,2)]
        [int]$Value = 2
    )
    $regPath = "HKU:\.DEFAULT\Control Panel\Keyboard"
    $regKey  = "InitialKeyboardIndicators"

    Write-Host "Nastavuji NumLock pro přihlašovací obrazovku v '$regPath' na $Value..."

    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name $regKey -Value $Value
    Write-Host "Hotovo. Toto nastavení ovlivní stav kláves před přihlášením."
}

# ---------------------------------------------------------------------
# 2) (Volitelně) Nastavení NumLocku pro AKTUÁLNÍHO UŽIVATELE (HKCU)
#    -> projeví se po odhlášení/přihlášení daného uživatele
# ---------------------------------------------------------------------
function Set-CurrentUserNumLock {
    [CmdletBinding()]
    param(
        [ValidateSet(0,1,2)]
        [int]$Value = 2
    )
    $regPath = "HKCU:\Control Panel\Keyboard"
    $regKey  = "InitialKeyboardIndicators"

    Write-Host "Nastavuji NumLock pro aktuálního uživatele v '$regPath' na $Value..."

    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name $regKey -Value $Value
    Write-Host "Hotovo. Projeví se po odhlášení/přihlášení uživatele."
}

# ---------------------------------------------------------------------
# 3) Vytvoření a naplnění podklíče registru v HKCU
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

# =========================== PŘÍKLADY VOLÁNÍ ==========================
<#
Set-PrelogonNumLock -Value 2
Set-CurrentUserNumLock -Value 2
Initialize-PlaygroundRegistryKey
#>
