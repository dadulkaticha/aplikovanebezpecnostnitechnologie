# Vyžaduje spuštění PowerShell jako správce, pokud budete číst HKLM klíče

function Get‑InstalledFromRegistry {
    param ([string[]] $paths)
    $results = @()
    foreach ($path in $paths) {
        if (Test‑Path $path) {
            Get‑ChildItem ‑Path $path ‑ErrorAction SilentlyContinue |
            ForEach‑Object {
                try {
                    $props = Get‑ItemProperty ‑Path $_.PSPath ‑ErrorAction SilentlyContinue
                    if ($props.DisplayName) {
                        $results += [pscustomobject]@{
                            Name     = $props.DisplayName
                            Version  = $props.DisplayVersion
                            Publisher= $props.Publisher
                            Source   = "Registry: $path"
                        }
                    }
                }
                catch { }
            }
        }
    }
    return $results
}

function Get‑InstalledFromGetPackage {
    $results = @()
    try {
        Get‑Package ‑Provider Programs ‑ErrorAction SilentlyContinue |
        ForEach‑Object {
            $results += [pscustomobject]@{
                Name      = $_.Name
                Version   = $_.Version
                Publisher = $_.ProviderName
                Source    = "Get‑Package"
            }
        }
    }
    catch { }
    return $results
}

function Get‑InstalledFromAppx {
    $results = @()
    try {
        Get‑AppxPackage |
        ForEach‑Object {
            $results += [pscustomobject]@{
                Name      = $_.Name
                Version   = $_.Version
                Publisher = $_.Publisher
                Source    = "Appx"
            }
        }
    }
    catch { }
    return $results
}

$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$regResults   = Get‑InstalledFromRegistry ‑paths $regPaths
$pkgResults   = Get‑InstalledFromGetPackage
$appxResults  = Get‑InstalledFromAppx

$allResults = $regResults + $pkgResults + $appxResults

$uniqueResults = $allResults | Sort‑Object Name, Version, Publisher –Unique

$uniqueResults | Select‑Object Name, Version, Publisher, Source | Format‑Table ‑AutoSize
