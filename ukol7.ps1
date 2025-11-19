# URL pro aktualni teplotu v Brne z Open-Meteo API
$apiUrl = "https://api.open-meteo.com/v1/forecast?latitude=49.1951&longitude=16.6068&current_weather=true"

try {
    # Ziskani dat z API
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get
    $temperature = $response.current_weather.temperature

    # Cesta k souboru teploty.txt na plose
    $soubor = "C:\Users\dendi\Desktop\teploty.txt"

    # Zaznam: datum cas - teplota
    $zaznam = "{0:yyyy-MM-dd HH:mm:ss} - {1} C" -f (Get-Date), $temperature

    # Zapis na konec souboru
    Add-Content -Path $soubor -Value $zaznam
}
catch {
    $soubor = "C:\Users\dendi\Desktop\teploty.txt"
    $zaznam = "{0:yyyy-MM-dd HH:mm:ss} - Chyba pri ziskavani dat" -f (Get-Date)
    Add-Content -Path $soubor -Value $zaznam
}


___________________________
Opakování každou hodinu
___________________________
$taskCmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\dendi\Desktop\stupne.ps1"'

schtasks /Create /SC HOURLY /MO 1 /TN "ZapisTeplot" /TR "$taskCmd" /F