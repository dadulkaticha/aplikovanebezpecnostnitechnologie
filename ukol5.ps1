# Interactive Directory Browser (PowerShell)
# Ovládání: 1-9 = vstup do adresáře, N = další stránka, P = předchozí stránka, U = o úroveň výš, Q = konec

function Format-Size {
    param([long]$Bytes)
    if ($null -eq $Bytes) { return "-" }
    $units = "B","KB","MB","GB","TB","PB"
    $i = 0; $value = [double]$Bytes
    while ($value -ge 1024 -and $i -lt $units.Length-1) { $value /= 1024; $i++ }
    "{0:N2} {1}" -f $value, $units[$i]
}

function Get-DirStats {
    param([string]$Path)
    $result = [PSCustomObject]@{ FileCount=0; SmallestName="-"; SmallestSize=$null; LargestName="-"; LargestSize=$null }
    try { $files = Get-ChildItem -LiteralPath $Path -File -ErrorAction Stop } catch { return $result }
    if (-not $files) { return $result }
    $result.FileCount = $files.Count
    $smallest = $files | Sort-Object Length, Name | Select-Object -First 1
    $largest  = $files | Sort-Object @{Expression='Length';Descending=$true}, Name | Select-Object -First 1
    $result.SmallestName = $smallest.Name; $result.SmallestSize = $smallest.Length
    $result.LargestName  = $largest.Name;  $result.LargestSize  = $largest.Length
    $result
}

function Write-Row {
    param([int]$Index, [System.IO.DirectoryInfo]$Dir, $Stats)
    $idxStr = ("[{0,1}]" -f $Index)
    $name   = $Dir.Name
    $count  = ("{0,5}" -f $Stats.FileCount)
    $smin   = if ($Stats.SmallestSize) { (Format-Size $Stats.SmallestSize) } else { "-" }
    $smax   = if ($Stats.LargestSize)  { (Format-Size $Stats.LargestSize)  } else { "-" }
    $minName = if ($Stats.SmallestName -and $Stats.SmallestName -ne "-") { $Stats.SmallestName } else { "-" }
    $maxName = if ($Stats.LargestName  -and $Stats.LargestName  -ne "-") { $Stats.LargestName  } else { "-" }
    if ($minName.Length -gt 32) { $minName = $minName.Substring(0,29) + "..." }
    if ($maxName.Length -gt 32) { $maxName = $maxName.Substring(0,29) + "..." }
    "{0} {1,-40} | souborů: {2} | nejmenší: {3,-12} {4,-32} | největší: {5,-12} {6,-32}" -f `
        $idxStr, $name, $count, $smin, $minName, $smax, $maxName
}

$ErrorActionPreference = 'Stop'
$pageSize = 9
$current = Get-Location
$page = 1

while ($true) {
    Clear-Host
    try {
        $dirs = Get-ChildItem -LiteralPath $current.Path -Directory | Sort-Object Name
    } catch {
        Write-Host "Nelze načíst obsah: $($current.Path)" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "Stiskněte libovolnou klávesu pro návrat o úroveň výš..."
        [void][Console]::ReadKey($true)
        $parentItem = (Get-Item -LiteralPath $current.Path).Parent
        if ($parentItem) { Set-Location -LiteralPath $parentItem.FullName; $current = Get-Location; continue } else { break }
    }

    $total = $dirs.Count
    $pages = [Math]::Max(1, [int][Math]::Ceiling($total / $pageSize))
    if ($page -gt $pages) { $page = $pages }
    $start = ($page - 1) * $pageSize
    $slice = if ($total -gt 0) { $dirs[$start..([Math]::Min($start + $pageSize - 1, $total - 1))] } else { @() }

    Write-Host "Prohlížeč adresářů (nerekurzivní statistiky souborů)" -ForegroundColor Cyan
    Write-Host "Aktuální cesta: $($current.Path)"
    Write-Host ("Stránka {0}/{1}  |  Adresáře: {2}" -f $page, $pages, $total)
    Write-Host ""

    if ($slice.Count -eq 0) {
        Write-Host "(Žádné podadresáře)" -ForegroundColor DarkYellow
    } else {
        Write-Host ("{0,-4} {1,-40} | {2,-11} | {3,-48} | {4,-48}" -f "#", "Adresář", "Souborů", "Nejmenší (velikost)", "Největší (velikost)") -ForegroundColor DarkGray
        Write-Host ("-" * 140) -ForegroundColor DarkGray
        for ($i = 0; $i -lt $slice.Count; $i++) {
            $dir = $slice[$i]
            $stats = Get-DirStats -Path $dir.FullName
            Write-Host (Write-Row -Index ($i+1) -Dir $dir -Stats $stats)
        }
    }

    Write-Host ""
    Write-Host "Ovládání: [1–9] vstup | N = další | P = předchozí | U = o úroveň výš | Q = konec" -ForegroundColor DarkCyan

    # Čti klávesu POUZE JEDNOU
    $key = [Console]::ReadKey($true)

    if ($key.Key -eq 'Q') {
        break
    }
    elseif ($key.Key -eq 'U') {
        try {
            $parentItem = (Get-Item -LiteralPath $current.Path).Parent
            if ($null -ne $parentItem) {
                Set-Location -LiteralPath $parentItem.FullName
                $current = Get-Location
                $page = 1
            }
        } catch {
            Write-Host "Nelze zjistit nadřazený adresář: $($_.Exception.Message)" -ForegroundColor Red
            [void][Console]::ReadKey($true)
        }
    }
    elseif ($key.Key -eq 'N') {
        if ($page -lt $pages) { $page++ }
    }
    elseif ($key.Key -eq 'P') {
        if ($page -gt 1) { $page-- }
    }
    elseif ($key.KeyChar -match '^[1-9]$') {
        $idx = [int]::Parse($key.KeyChar)
        if ($idx -ge 1 -and $idx -le $slice.Count) {
            $target = $slice[$idx - 1]
            try {
                Set-Location -LiteralPath $target.FullName
                $current = Get-Location
                $page = 1
            } catch {
                Write-Host "Nelze vstoupit do adresáře '$($target.FullName)': $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Pokračujte libovolnou klávesou..."
                [void][Console]::ReadKey($true)
            }
        }
    }
}

Write-Host "Ukončeno." -ForegroundColor Green