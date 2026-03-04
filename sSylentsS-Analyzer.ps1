# ===============================
# sSylentsS Analyzer v3
# Detección avanzada real
# ===============================

$scanPaths = @(
    "$env:APPDATA\.minecraft",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:TEMP"
)

# Módulos reales de hack (no mixin)
$realHackModules = @(
    "killaura",
    "crystalaura",
    "triggerbot",
    "aimbot",
    "reach",
    "velocity",
    "flight",
    "scaffold",
    "bhop",
    "speed",
    "xray",
    "freecam",
    "autoarmor",
    "autototem",
    "automine",
    "autopot"
)

# Firmas más profundas de clientes
$clientIndicators = @{
    "Meteor" = @("meteordevelopment","meteorclient","systems/modules")
    "Wurst" = @("wurstclient","net/wurstclient")
    "Aristois" = @("me/deftware","aristois")
    "Doomsday" = @("ghost","combat/aura","module/combat","ddclient")
}

function Analyze-Jar {
    param($file)

    $foundModules = @{}
    $foundClient = $null

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file)

        foreach ($entry in $zip.Entries) {

            $name = $entry.FullName.ToLower()

            # Detectar cliente por firmas
            foreach ($client in $clientIndicators.Keys) {
                foreach ($sig in $clientIndicators[$client]) {
                    if ($name -like "*$sig*") {
                        $foundClient = $client
                    }
                }
            }

            # Detectar módulos reales (una sola vez)
            foreach ($mod in $realHackModules) {
                if ($name -like "*$mod*") {
                    $foundModules[$mod] = $true
                }
            }
        }

        $zip.Dispose()
    }
    catch { }

    return [PSCustomObject]@{
        File = $file
        Client = $foundClient
        Modules = $foundModules.Keys
    }
}

$results = @()

foreach ($path in $scanPaths) {
    if (Test-Path $path) {
        Get-ChildItem $path -Recurse -Filter *.jar -ErrorAction SilentlyContinue | ForEach-Object {
            $results += Analyze-Jar $_.FullName
        }
    }
}

# ===============================
# Clasificación estilo Meow
# ===============================

$verified = @()
$suspicious = @()
$hacked = @()

foreach ($r in $results) {

    if ($r.Client) {
        $hacked += $r
    }
    elseif ($r.Modules.Count -ge 2) {
        # Si tiene múltiples módulos de combate/movimiento
        $suspicious += $r
    }
    else {
        $verified += $r
    }
}

# ===============================
# OUTPUT LIMPIO
# ===============================

function Print-Section($title,$items,$color){
    if($items.Count -eq 0){return}
    Write-Host "`n┏━ $title ━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $color
    foreach($i in $items){
        Write-Host "File: $($i.File)" -ForegroundColor $color
        if($i.Client){
            Write-Host "Detected Client: $($i.Client)" -ForegroundColor $color
        }
        if($i.Modules.Count -gt 0){
            Write-Host "Modules: $($i.Modules -join ', ')" -ForegroundColor $color
        }
        Write-Host "-----------------------------------" -ForegroundColor $color
    }
    Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $color
}

Print-Section "VERIFIED MODS" $verified "Cyan"
Print-Section "SUSPICIOUS FILES" $suspicious "Yellow"
Print-Section "HACKED CLIENTS" $hacked "Red"

Write-Host "`nScan Complete."
Print-Section "HACKED CLIENTS" $hacked "Red"

Write-Host "`nScan Complete."
