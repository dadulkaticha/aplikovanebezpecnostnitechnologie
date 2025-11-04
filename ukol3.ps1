<# =====================================================================
 ÚKOL 3: Práce s CIM a účty
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
# 3) Kontrola a přejmenování disku C: (vyžaduje admin)
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
        Write-Host ("Disk C: se jmenuje '{0}'. Přejmenovávám na '{1}'..." -f $c.Label, $TargetLabel)
        $res = Invoke-CimMethod -InputObject $c -MethodName SetLabel -Arguments @{ Label = $TargetLabel }
        if ($res.ReturnValue -eq 0) {
            Write-Host "Přejmenování dokončeno."
        } else {
            throw "Přejmenování selhalo. Kód návratu: $($res.ReturnValue)"
        }
    } else {
        Write-Host "Disk C: se již jmenuje '$TargetLabel'."
    }
}


# ---------------------------------------------------------------------
# 5) Seznam nepoužitých a uzamčených účtů (LDAP / ADSI)
# ---------------------------------------------------------------------
function Get-ADAccountsByLdap {
    [CmdletBinding()]
    param()

    Write-Host "--- Nepoužité účty (LDAP dotaz: lastLogonTimestamp neexistuje) ---"
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.PageSize = 1000
    $searcher.Filter = "(&(objectCategory=person)(objectClass=user)(!(lastLogonTimestamp=*)))"
    $unused = $searcher.FindAll()
    foreach ($res in $unused) {
        $sam = $res.Properties.samaccountname
        if ($sam) { $sam | ForEach-Object { $_ } }
    }

    Write-Host "`n--- Uzamčené účty (LDAP dotaz: lockoutTime>0) ---"
    $searcher.Filter = "(&(objectCategory=person)(objectClass=user)(lockoutTime>0))"
    $locked = $searcher.FindAll()
    foreach ($res in $locked) {
        $sam = $res.Properties.samaccountname
        if ($sam) { $sam | ForEach-Object { $_ } }
    }
}
