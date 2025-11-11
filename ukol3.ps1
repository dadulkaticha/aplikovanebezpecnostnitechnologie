<# =====================================================================
 ÚKOL 3: Práce s CIM a účty  (aktualizováno dle připomínek)
 - Přejmenování svazku C: pomocí Set-CimInstance (ne Invoke-CimMethod).
 - Nepoužité a uzamčené účty řešeno pro lokální stanici:
     * Get-LocalUser (nepoužité = nikdy se nepřihlásily / LastLogon -eq $null)
     * Win32_UserAccount (Lockout = True) pro zjištění uzamčení
===================================================================== #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    try {
        $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        Write-Warning "Nelze ověřit oprávnění administrátora: $($_.Exception.Message)"
        return $false
    }
}

# ---------------------------------------------------------------------
# 1) Vlastnosti třídy Win32_Printer (CIM)
# ---------------------------------------------------------------------
function Show-PrinterClassInfo {
    [CmdletBinding()]
    param(
        [switch]$Methods
    )
    Write-Host "Načítám informace o třídě Win32_Printer..."

    $cls = Get-CimClass -ClassName Win32_Printer
    if ($Methods) {
        $cls.CimClassMethods | Sort-Object Name | Format-Table Name, ReturnType, Qualifiers -AutoSize
    } else {
        $cls.CimClassProperties | Sort-Object Name | Format-Table Name, CimType, Qualifiers -AutoSize
    }
}

# ---------------------------------------------------------------------
# 2) Změna umístění tiskárny 'Fax'
# ---------------------------------------------------------------------
function Set-FaxLocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Location
    )
    Write-Host "Hledám tiskárnu 'Fax' přes CIM..."
    $fax = Get-CimInstance -ClassName Win32_Printer -Filter "Name = 'Fax'"
    if ($null -eq $fax) {
        Write-Host "Tiskárna s názvem 'Fax' nebyla nalezena."
        return
    }
    Write-Host "Nastavuji umístění na: $Location"
    Set-CimInstance -InputObject $fax -Property @{ Location = $Location }
    Write-Host "Hotovo: Umístění tiskárny 'Fax' změněno."
}

# ---------------------------------------------------------------------
# 3) Kontrola a přejmenování disku C: pomocí Set-CimInstance (vyžaduje admin)
# ---------------------------------------------------------------------
function Ensure-DriveCLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TargetLabel
    )
    if (-not (Test-IsAdmin)) {
        throw "Tato operace vyžaduje spuštění PowerShellu jako SPRÁVCE."
    }

    Write-Host "Načítám svazek C: přes Win32_Volume..."
    $c = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = 'C:'"
    if ($null -eq $c) {
        throw "Svazek C: nebyl nalezen."
    }

    if ($c.Label -ne $TargetLabel) {
        Write-Host ("Disk C: se jmenuje '{0}'. Přejmenovávám na '{1}' pomocí Set-CimInstance..." -f $c.Label, $TargetLabel)
        # Některé systémy nemusí mít metodu SetLabel; aktualizujme vlastnost Label přímo.
        $c | Set-CimInstance -Property @{ Label = $TargetLabel }
        # Ověření
        $c2 = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = 'C:'"
        if ($c2.Label -eq $TargetLabel) {
            Write-Host "Přejmenování dokončeno."
        } else {
            throw "Přejmenování se nepotvrdilo. Aktuální label: '$($c2.Label)'. Zkontrolujte oprávnění a spuštění jako správce."
        }
    } else {
        Write-Host "Disk C: se již jmenuje '$TargetLabel'."
    }
}

# ---------------------------------------------------------------------
# 4) Lokální účty – nepoužité a uzamčené
#    Varianta A: Get-LocalUser (nepoužité = LastLogon -eq $null)
# ---------------------------------------------------------------------
function Get-LocalUnusedAccounts {
    [CmdletBinding()]
    param()
    Write-Host "--- Lokální účty, které se nikdy nepřihlásily (Get-LocalUser) ---"
    try {
        Get-LocalUser | Where-Object { $_.LastLogon -eq $null } |
            Select-Object Name, Enabled, LastLogon |
            Format-Table -AutoSize
    } catch {
        throw "Get-LocalUser není k dispozici. Spouštíte PowerShell 5.1+? ($($_.Exception.Message))"
    }
}

# ---------------------------------------------------------------------
# 5) Lokální účty – uzamčené (Win32_UserAccount s Lockout = True)
# ---------------------------------------------------------------------
function Get-LocalLockedOutAccounts {
    [CmdletBinding()]
    param()
    Write-Host "--- Lokální uzamčené účty (Win32_UserAccount) ---"
    $locked = Get-CimInstance -ClassName Win32_UserAccount -Filter "LocalAccount = True AND Lockout = True"
    if ($locked) {
        $locked | Select-Object Name, Domain, Disabled, Lockout | Format-Table -AutoSize
    } else {
        Write-Host "Nebyly nalezeny žádné uzamčené lokální účty."
    }
}

# =========================== PŘÍKLADY VOLÁNÍ ==========================
<#
Show-PrinterClassInfo            # vlastnosti
Show-PrinterClassInfo -Methods   # metody
Set-FaxLocation -Location "Zasedací místnost (Přízemí)"
Ensure-DriveCLabel -TargetLabel "Systém"
Get-LocalUnusedAccounts
Get-LocalLockedOutAccounts
#>
