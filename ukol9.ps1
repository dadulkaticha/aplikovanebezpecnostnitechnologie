# watch-clipboard.ps1
# Pravidelné sledování schránky a hledání klíčových slov "password" a "token"

# --- KONFIGURACE ---
# Klíčová slova (lze upravit / rozšířit)
$keywords = @("password", "token", "secret", "heslo", "klíč")

# interval kontroly schránky v sekundách
$checkIntervalSeconds = 20

# --- INTERNÍ PROMĚNNÉ ---
$lastClipboard = $null
# Předpřipravení REGEXU pro detekci klíčových slov
$detectionPattern = ($keywords | ForEach-Object { [regex]::Escape($_) }) -join "|"
# objekt Regex pro rychlejší opakované použití
$keywordRegex = [regex]::new($detectionPattern, 'IgnoreCase')

# -----------------------------------------------------------

function Write-Highlighted {
    param(
        [string] $Text,
        [regex] $KeywordRegex
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return
    }

    # předpřipravený Regex pro nalezení všech shod
    $foundMatches = $KeywordRegex.Matches($Text)

    if ($foundMatches.Count -eq 0) {
        # nic nenalezeno, vypíšeme řádek
        Write-Host $Text
        return
    }

    $pos = 0

    foreach ($match in $foundMatches) {
        # neobarvená část před nalezeným slovem
        if ($match.Index -gt $pos) {
            $plainPart = $Text.Substring($pos, $match.Index - $pos)
            Write-Host -NoNewline $plainPart
        }

        # nalezené klíčové slovo – barevně
        Write-Host -NoNewline $match.Value -ForegroundColor Yellow

        # posun za nalezené slovo
        $pos = $match.Index + $match.Length
    }

    # zbytek řádku za posledním klíčovým slovem
    if ($pos -lt $Text.Length) {
        $rest = $Text.Substring($pos)
        Write-Host $rest
    } else {
        Write-Host ""
    }
}

# -----------------------------------------------------------

Write-Host "Monitoring clipboardu – ukonči pomocí Ctrl+C. 💾" -ForegroundColor Green
Write-Host "Sledují se klíčová slova: $($keywords -join ', ')" -ForegroundColor DarkGray
Write-Host "Kontrola probíhá každých $($checkIntervalSeconds) sekund (dle zadání)." -ForegroundColor DarkGray
Write-Host ""

while ($true) {
    try {
        # -Raw aby se zachovaly nové řádky jako jeden string
        $current = Get-Clipboard -Raw -ErrorAction Stop
    }
    catch {
        # Když je schránka prázdná / nepodporovaný formát, nebo dojde k chybě
        $current = $null
    }

    # Reagujeme jen pokud se obsah skutečně změnil a není prázdný
    if ($current -ne $lastClipboard -and -not [string]::IsNullOrWhiteSpace($current)) {
        $lastClipboard = $current

        # Zkontrolujeme, jestli text obsahuje nějaké z klíčových slov pomocí předpřipraveného Regexu
        if ($keywordRegex.IsMatch($current)) {
            $time = Get-Date -Format "HH:mm:ss"
            Write-Host ""
            Write-Host "[$time] 🚨 NALEZENO KLÍČOVÉ SLOVO VE SCHRÁNCE:" -ForegroundColor Red
            Write-Host "==============================================" -ForegroundColor Red

            # Zachováme formátování – po řádcích
            $lines = $current -split "`r?`n"
            foreach ($line in $lines) {
                Write-Highlighted -Text $line -KeywordRegex $keywordRegex
            }

            Write-Host "==============================================" -ForegroundColor Red
        }
    }

    # Počkáme definovaný interval a pak kontrolujeme znovu
    Start-Sleep -Seconds $checkIntervalSeconds
}