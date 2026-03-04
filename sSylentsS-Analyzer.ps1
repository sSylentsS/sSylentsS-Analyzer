# ================================
# sSylentsS Analyzer v2 PRO
# Estilo MeowModAnalyzer
# ================================

$scanPath = "$env:APPDATA\.minecraft\mods"

# Clientes conocidos con identificadores reales
$clientSignatures = @{
    "Meteor" = @("meteordevelopment","meteorclient","systems/modules/combat","crystalaura","killaura")
    "Wurst" = @("net/wurstclient","wurstclient","wurstplus")
    "Aristois" = @("me/deftware","aristois")
    "Doomsday" = @("doomsdayclient","ddclient","ghostloader")
}

$combatModules = @("killaura","aimbot","autoclicker","triggerbot","reach","velocity","critical")
$movementModules = @("flight","scaffold","speed","bhop")
$renderModules = @("xray","freecam")
$utilityModules = @("autoarmor","autototem","automine","autopot")

function Analyze-Jar {
    param($file)

    $contentMatches = @{}
    $detectedClient = $null

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file)

        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.ToLower()

            # Detectar cliente
            foreach ($client in $clientSignatures.Keys) {
                foreach ($sig in $clientSignatures[$client]) {
                    if ($name -like "*$sig*") {
                        $detectedClient = $client
                    }
                }
            }

            # Detectar módulos reales (solo 1 vez)
            foreach ($mod in $combatModules + $movementModules + $renderModules + $utilityModules) {
                if ($name -like "*$mod*") {
                    $contentMatches[$mod] = $true
                }
            }
        }

        $zip.Dispose()
    }
    catch { }

    return [PSCustomObject]@{
        File = $file
        Client = $detectedClient
        Modules = $contentMatches.Keys
    }
}

$results = @()

Get-ChildItem $scanPath -Filter *.jar | ForEach-Object {
    $results += Analyze-Jar $_.FullName
}

# ================================
# CATEGORÍAS
# ================================

$verified = @()
$suspicious = @()
$hacked = @()

foreach ($r in $results) {

    if ($r.Client) {
        $hacked += $r
    }
    elseif ($r.Modules.Count -gt 0) {
        $suspicious += $r
    }
    else {
        $verified += $r
    }
}

# ================================
# OUTPUT LIMPIO
# ================================

function Print-Section($title, $items, $color) {
    if ($items.Count -eq 0) { return }
    Write-Host "`n┏━ $title ━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $color
    foreach ($i in $items) {
        Write-Host "File: $($i.File)" -ForegroundColor $color
        if ($i.Client) {
            Write-Host "Detected Client: $($i.Client)" -ForegroundColor $color
            Write-Host "Probable Source: https://$($i.Client.ToLower()).com" -ForegroundColor $color
        }
        if ($i.Modules.Count -gt 0) {
            Write-Host "Modules Found: $($i.Modules -join ', ')" -ForegroundColor $color
        }
        Write-Host "-----------------------------------" -ForegroundColor $color
    }
    Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $color
}

Print-Section "VERIFIED MODS" $verified "Cyan"
Print-Section "SUSPICIOUS MODS" $suspicious "Yellow"
Print-Section "HACKED CLIENTS" $hacked "Red"

Write-Host "`nScan Complete."
