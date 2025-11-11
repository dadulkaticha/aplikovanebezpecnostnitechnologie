<# =====================================================================
 ÚKOL 5: Interaktivní textové rozhraní pro procházení adresářů
 Ovládání:
  - Stiskni číslo adresáře (lze vícemístné) a potvrď Enter -> vstup do adresáře
  - Stiskni U -> o úroveň výš
  - Stiskni Q -> konec programu
 Zobrazuje se: počet souborů, nejmenší a největší soubor (název + velikost) v každém podadresáři.
 Pozn.: Statistiky jsou pro obsah daného adresáře (bez rekurze).
===================================================================== #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DirStats {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    $result = [ordered]@{
        FileCount = 0
        MinName   = '-'
        MinSize   = 0
        MaxName   = '-'
        MaxSize   = 0
    }

    try {
        $files = Get-ChildItem -LiteralPath $Path -File -Force -ErrorAction Stop
    } catch {
        return $result
    }

    if (-not $files) { return $result }

    $result.FileCount = $files.Count
    $min = $files | Sort-Object Length | Select-Object -First 1
    $max = $files | Sort-Object Length -Descending | Select-Object -First 1
    $result.MinName = $min.Name
    $result.MinSize = $min.Length
    $result.MaxName = $max.Name
    $result.MaxSize = $max.Length
    return $result
}

function Show-Directory {
    param(
        [Parameter(Mandatory)]
        [string]$CurrentPath
    )
    Clear-Host
    Write-Host "Aktuální složka:" -NoNewline
    Write-Host " $CurrentPath" -ForegroundColor Cyan

    # Načti podadresáře (bez rekurze)
    try {
        $dirs = Get-ChildItem -LiteralPath $CurrentPath -Directory -Force -ErrorAction Stop
    } catch {
        Write-Host "Nelze načíst obsah. Důvod: $($_.Exception.Message)" -ForegroundColor Red
        $dirs = @()
    }

    if (-not $dirs) {
        Write-Host "(Žádné podadresáře)"
    } else {
        # Sestav tabulku se statistikami
        $table = @()
        $i = 1
        foreach ($d in $dirs) {
            $stats = Get-DirStats -Path $d.FullName
            $table += [pscustomobject]@{
                '#'          = $i
                'Adresář'    = $d.Name
                'Souborů'    = $stats.FileCount
                'Nejmenší'   = if ($stats.FileCount -gt 0) { "{0} ({1} B)" -f $stats.MinName, $stats.MinSize } else { "-" }
                'Největší'   = if ($stats.FileCount -gt 0) { "{0} ({1} B)" -f $stats.MaxName, $stats.MaxSize } else { "-" }
            }
            $i++
        }

        $table | Format-Table -AutoSize | Out-String | Write-Host
    }

    Write-Host ""
    Write-Host "Ovládání: zadej číslo a ENTER = vstoupit  |  U = výš  |  Q = konec"
}

function Start-DirectoryBrowser {
    param(
        [string]$StartPath = (Get-Location).Path
    )

    $stack = New-Object System.Collections.Stack
    $current = (Resolve-Path -LiteralPath $StartPath).Path

    while ($true) {
        Show-Directory -CurrentPath $current

        # Čtení vstupu: číslo (vícemístné) + Enter, nebo U/Q
        Write-Host -NoNewline "> "
        $input = Read-Host

        if ([string]::IsNullOrWhiteSpace($input)) { continue }

        switch -Regex ($input.ToUpperInvariant()) {
            '^Q$' { break }
            '^U$' {
                $parent = Split-Path -LiteralPath $current -Parent
                if ($parent -and $parent -ne $current) {
                    $current = $parent
                }
                continue
            }
            '^\d+$' {
                # volba adresáře podle pořadí
                try {
                    $dirs = Get-ChildItem -LiteralPath $current -Directory -Force -ErrorAction Stop
                } catch {
                    continue
                }
                $index = [int]$input
                if ($index -ge 1 -and $index -le $dirs.Count) {
                    $chosen = $dirs[$index-1]
                    $stack.Push($current)
                    $current = $chosen.FullName
                } else {
                    Write-Host "Neplatná volba." -ForegroundColor Yellow
                    Start-Sleep -Milliseconds 900
                }
                continue
            }
            default {
                Write-Host "Neznámý příkaz. Použij: číslo + Enter, U, Q." -ForegroundColor Yellow
                Start-Sleep -Milliseconds 900
            }
        }
    }
}

# Spuštění (lze upravit startovní cestu)
Start-DirectoryBrowser  # nebo: Start-DirectoryBrowser -StartPath "C:\\"
