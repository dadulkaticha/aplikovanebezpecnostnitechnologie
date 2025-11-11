<# =====================================================================
 ÚKOL 6: Číselné a textové úlohy
  1) Vygenerovat 10 náhodných čísel (10..100) a vypsat je se čtverci do 2 sloupců.
  2) Setřídit znaky v textu "Kobyla má malý bok" vzestupně dle abecedy.
  3) Najít nejmenší a největší palindrom jako součin dvou trojciferných čísel.
===================================================================== #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------- 1) Náhodná čísla ---------------------------
function Show-RandomSquares {
    [CmdletBinding()]
    param(
        [int]$Count = 10
    )
    Write-Host "Náhodná čísla a jejich druhé mocniny:"
    # Hlavička (první sloupec od 1. pozice doprava, druhý od 6. pozice doprava)
    "{0,5}{1,10}" -f "x", "x^2" | Write-Host
    for ($i=0; $i -lt $Count; $i++) {
        $n = Get-Random -Minimum 10 -Maximum 101  # 10..100 včetně
        $sq = [int64]$n * [int64]$n
        "{0,5}{1,10}" -f $n, $sq | Write-Host
    }
    Write-Host ""
}

# ----------------- 2) Třídění znaků v českém textu -------------------
function Sort-TextCharacters {
    [CmdletBinding()]
    param(
        [string]$Text = "Kobyla má malý bok",
        [switch]$IgnoreSpaces
    )

    $chars = $Text.ToCharArray() | ForEach-Object { [string]$_ }
    if ($IgnoreSpaces) {
        $chars = $chars | Where-Object { $_ -ne ' ' }
    }

    # Setřiď podle češtiny, nerozlišuj velikost písmen
    try {
        $sorted = $chars | Sort-Object -Culture 'cs-CZ'
    } catch {
        # Fallback bez explicitní kultury (starší PowerShell)
        $sorted = $chars | Sort-Object
    }

    $joined = -join $sorted
    Write-Host "Původní: $Text"
    if ($IgnoreSpaces) {
        Write-Host "Seřazeno (bez mezer): $joined"
    } else {
        Write-Host "Seřazeno: $joined"
    }
    Write-Host ""
}

# --------------- 3) Palindromy ze součinu trojciferných čísel --------
function Test-IsPalindrome {
    param([int]$Number)
    $s = [string]$Number
    return ($s -eq -join ($s.ToCharArray() | [Array]::Reverse([char[]]$s.ToCharArray()); $s.ToCharArray()))
}

function Find-ThreeDigitPalindromeExtremes {
    [CmdletBinding()]
    param()

    $minPal = [int]::MaxValue
    $minA = $null; $minB = $null
    $maxPal = -1
    $maxA = $null; $maxB = $null

    for ($a = 100; $a -le 999; $a++) {
        for ($b = 100; $b -le 999; $b++) {
            $p = $a * $b
            # Ověření palindromu (rychle stringově)
            $s = [string]$p
            $rs = -join ($s.ToCharArray() | Sort-Object -Descending) # WRONG
        }
    }
}

# Oprava palindrom testu – pomocná čistá funkce
function Is-Palindrome {
    param([int]$n)
    $s = [string]$n
    $chars = $s.ToCharArray()
    [Array]::Reverse($chars)
    return ($s -eq (-join $chars))
}

function Find-ThreeDigitPalindromeExtremes2 {
    [CmdletBinding()]
    param()

    $minPal = [int]::MaxValue
    $minA = $null; $minB = $null
    $maxPal = -1
    $maxA = $null; $maxB = $null

    for ($a = 100; $a -le 999; $a++) {
        for ($b = 100; $b -le 999; $b++) {
            $p = $a * $b
            if (Is-Palindrome -n $p) {
                if ($p -lt $minPal) { $minPal = $p; $minA = $a; $minB = $b }
                if ($p -gt $maxPal) { $maxPal = $p; $maxA = $a; $maxB = $b }
            }
        }
    }

    Write-Host "Nejmenší palindrom: $minPal = $minA × $minB"
    Write-Host "Největší palindrom: $maxPal = $maxA × $maxB"
    Write-Host ""
}

# ------------------------------ Spuštění ------------------------------
Show-RandomSquares
Sort-TextCharacters                 # s mezerami
Sort-TextCharacters -IgnoreSpaces   # bez mezer
Find-ThreeDigitPalindromeExtremes2
