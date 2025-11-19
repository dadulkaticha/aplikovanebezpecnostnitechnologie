1)
# Cesta k registru pro nastavení NumLock při přihlášení
$RegPath = "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard"
$ValueName = "InitialKeyboardIndicators"

# Získání aktuální hodnoty
$CurrentValue = (Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction Stop).$ValueName

# Výpis
Write-Host "Aktuální hodnota InitialKeyboardIndicators: $CurrentValue"

# Nastavení numlocku na hodnotu 2
Set-ItemProperty -Path $RegPath -Name $ValueName -Value "2"

2)
# Nastavení cesty k novému klíči
$registryPath = "HKCU:\Hrátky s PowerShellem"

# Vytvoření klíče
New-Item -Path $registryPath -Force | Out-Null

# Získání požadovaných informací
$username = $env:USERNAME
$computerName = $env:COMPUTERNAME
$currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$psVersion = $PSVersionTable.PSVersion.ToString()

# Vytvoření (nebo přepsání) hodnot v registru
New-ItemProperty -Path $registryPath -Name "Uživatelské_jméno" -Value $username -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name "Jméno_počítače" -Value $computerName -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name "Aktuální_datum" -Value $currentDate -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name "Verze_PowerShellu" -Value $psVersion -PropertyType String -Force | Out-Null

# Výpis uložených informací
Write-Host "Informace byly zapsány do registru:"
Get-ItemProperty -Path $registryPath | Select-Object Uživatelské_jméno, Jméno_počítače, Aktuální_datum, Verze_PowerShellu

