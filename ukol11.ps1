param(
    [string]$Url,
    [int]$Delka
)

function Show-Help {
    Write-Host "Použití skriptu:" -ForegroundColor Yellow
    Write-Host "  powershell -File .\ukol9.ps1 -Url ""https://www.example.com"" -Delka 5"
    Write-Host ""
    Write-Host "Parametry:" -ForegroundColor Yellow
    Write-Host "  -Url    URL webové stránky, ze které se budou číst data."
    Write-Host "  -Delka  Požadovaná délka slov, která se mají vypsat."
    Write-Host ""
    Write-Host "Popis:" -ForegroundColor Yellow
    Write-Host "  Skript stáhne obsah zadané URL, odstraní HTML značky a vypíše všechna"
    Write-Host "  jedinečná slova přesně o dané délce (bez rozlišení velikosti písmen)."
}

function Get-UniqueWordsFromUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [int]$Delka
    )

    Write-Host "Načítám obsah z URL: $Url" -ForegroundColor Cyan

    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Host "Chyba při načítání URL:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return @()
    }

    if (-not $response.Content) {
        Write-Host "Z URL se nepodařilo získat žádný obsah." -ForegroundColor Yellow
        return @()
    }

    # Původní HTML
    $html = $response.Content

    # Dekódování HTML entit (např. &amp;, &nbsp; atd.)
    $decoded = [System.Net.WebUtility]::HtmlDecode($html)

    # Odstranění HTML tagů
    $textOnly = [regex]::Replace($decoded, "<[^>]+>", " ")

    # Nahrazení více bílých znaků jednou mezerou
    $normalized = [regex]::Replace($textOnly, "\s+", " ")

    # Rozdělení na "slova"
    # \p{L} = písmena (včetně diakritiky), \p{Nd} = číslice
    $rawWords = $normalized -split "[^\p{L}\p{Nd}]+"

    if (-not $rawWords -or $rawWords.Count -eq 0) {
        Write-Host "V textu se nepodařilo najít žádná slova." -ForegroundColor Yellow
        return @()
    }

    # Filtrování slov podle délky a převod na malá písmena
    $filteredWords =
        $rawWords |
        Where-Object { $_ -and $_.Length -eq $Delka } |
        ForEach-Object { $_.ToLowerInvariant() } |
        Sort-Object -Unique

    return $filteredWords
}

# Kontrola parametrů – pokud chybí, zobrazí se nápověda
if (-not $Url -or -not $Delka) {
    Show-Help
    exit 1
}

Write-Host "Extrahuji jedinečná slova o délce $Delka z URL:" -ForegroundColor Green
Write-Host "  $Url" -ForegroundColor Green

$uniqueWords = Get-UniqueWordsFromUrl -Url $Url -Delka $Delka

if (-not $uniqueWords -or $uniqueWords.Count -eq 0) {
    Write-Host "Nebylo nalezeno žádné slovo o délce $Delka." -ForegroundColor Yellow
}
else {
    Write-Host "Nalezeno $($uniqueWords.Count) jedinečných slov o délce ${Delka}:" -ForegroundColor Green
    Write-Host ""

    # Vypsání slov v jednoduchém sloupci
    $uniqueWords | ForEach-Object {
        Write-Host $_
    }
}

Write-Host ""
Write-Host "Hotovo." -ForegroundColor Cyan
