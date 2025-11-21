# Vyžaduje spuštění PowerShell jako správce, pokud budete číst některé části registru nebo systémové adresáře

function Get-InstalledPrograms {
    param(
        [switch]$IncludeSystemComponents  # Přidá i systémové komponenty, které jsou normálně skryté
    )

    $programs = @()

    # Cesty v registru, kde jsou instalované programy
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $registryPaths) {
        Write-Host "Načítám programy z registru: $path" -ForegroundColor Cyan
        try {
            Get-ItemProperty -Path $path -ErrorAction Stop | ForEach-Object {
                $props = $_

                # Filtrace položek bez DisplayName (skryté nebo vnitřní komponenty)
                if ($props.DisplayName) {
                    if (-not $IncludeSystemComponents) {
                        # Přeskočíme systémové komponenty
                        if ($props.SystemComponent -eq 1 -or $props.ReleaseType -eq "Security Update" -or $props.ParentKeyName) {
                            return
                        }
                    }

                    $program = [PSCustomObject]@{
                        Name         = $props.DisplayName
                        Version      = $props.DisplayVersion
                        Publisher    = $props.Publisher
                        InstallDate  = $props.InstallDate
                        Source       = if ($path -like "*WOW6432Node*") { "Registry (32bit)" } else { "Registry (64bit/CurrentUser)" }
                    }

                    $programs += $program
                }
            }
        }
        catch {
            Write-Warning "Nelze číst z cesty v registru: $path. Chyba: $_"
        }
    }

    # Získání informací o aplikacích z Get-Package (PowerShell balíčky)
    Write-Host "Načítám balíčky z Get-Package..." -ForegroundColor Cyan
    try {
        Get-Package -ErrorAction Stop | ForEach-Object {
            $program = [PSCustomObject]@{
                Name         = $_.Name
                Version      = $_.Version
                Publisher    = $_.ProviderName
                InstallDate  = $null
                Source       = "Get-Package"
            }
            $programs += $program
        }
    }
    catch {
        Write-Warning "Nelze načíst balíčky přes Get-Package. Chyba: $_"
    }

    # Odebrání duplicit podle názvu a verze
    $uniquePrograms = $programs | Sort-Object Name, Version -Unique

    return $uniquePrograms
}

# Hlavní část skriptu
Write-Host "Zjišťuji seznam nainstalovaných programů..." -ForegroundColor Green
$installedPrograms = Get-InstalledPrograms

if ($installedPrograms.Count -eq 0) {
    Write-Host "Nebyl nalezen žádný nainstalovaný program." -ForegroundColor Yellow
} else {
    Write-Host "Nalezeno $($installedPrograms.Count) programů." -ForegroundColor Green
    $installedPrograms | Sort-Object Name | Format-Table -AutoSize
}

# Možnost filtrování uživatelsky
Write-Host "`nChcete filtrovat výsledky podle názvu programu? (ano/ne)" -NoNewline
$response = Read-Host

if ($response -eq "ano") {
    Write-Host "Zadejte část názvu programu, který hledáte:" -NoNewline
    $filter = Read-Host

    $filteredPrograms = $installedPrograms | Where-Object { $_.Name -like "*$filter*" }

    if ($filteredPrograms.Count -eq 0) {
        Write-Host "Nebyly nalezeny žádné programy odpovídající filtru '$filter'." -ForegroundColor Yellow
    } else {
        Write-Host "Nalezeno $($filteredPrograms.Count) programů odpovídajících filtru '$filter':" -ForegroundColor Green
        $filteredPrograms | Sort-Object Name | Format-Table -AutoSize
    }
}

# Export do CSV
Write-Host "`nChcete exportovat seznam programů do CSV souboru? (ano/ne)" -NoNewline
$exportResponse = Read-Host

if ($exportResponse -eq "ano") {
    $defaultPath = "$env:USERPROFILE\Desktop\installed_programs.csv"
    Write-Host "Zadejte cestu pro export (nebo stiskněte Enter pro výchozí cestu: $defaultPath):" -NoNewline
    $exportPath = Read-Host

    if ([string]::IsNullOrWhiteSpace($exportPath)) {
        $exportPath = $defaultPath
    }

    try {
        $installedPrograms | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
        Write-Host "Seznam byl úspěšně exportován do souboru: $exportPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Nepodařilo se exportovat data do CSV. Chyba: $_"
    }
}

Write-Host "`nHotovo. Stiskněte libovolnou klávesu pro ukončení..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
