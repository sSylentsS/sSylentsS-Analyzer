# ================================================
# sSylentsS Analyzer
# Escanea Hacks y Mods en Windows
# ================================================

# Carpeta a escanear
$scanPaths = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:LOCALAPPDATA\Temp",
    "$env:APPDATA\.minecraft\mods"
)

# Hacks conocidos (hashes o patrones)
$knownHacks = @{
    "Doomsday" = @{
        "Patterns" = @("appleskin","client-intermediary","じ.class","ふ.class","ぶ.class")
        "Source" = "https://doomsdayclient.com/"
    }
    "Meteor" = @{
        "Patterns" = @("modmenu")
        "Source" = "https://meteorclient.com/archive"
    }
    "Aristois" = @{
        "Patterns" = @("lithium-fabric")
        "Source" = "https://aristois.net/"
    }
    "Wurst" = @{
        "Patterns" = @("sodium-fabric")
        "Source" = "https://www.wurstclient.net/"
    }
}

# Colores para salida
$colorHack = "Red"
$colorVerified = "Green"
$colorSuspicious = "Yellow"

# Función para detectar hacks según nombre o patrón
function Get-HackInfo($file) {
    foreach ($hack in $knownHacks.Keys) {
        foreach ($pattern in $knownHacks[$hack]["Patterns"]) {
            if ($file.Name -match [regex]::Escape($pattern)) {
                return @{Client=$hack; Source=$knownHacks[$hack]["Source"]}
            }
        }
    }
    return $null
}

# Función para verificar si es un mod oficial (simplificado)
function Is-VerifiedMod($file) {
    # Solo ejemplo básico: archivos .jar con versión numérica y nombre oficial
    if ($file.Name -match "\d+\.\d+\.\d+") { return $true }
    return $false
}

# Escaneo principal
$foundHacks = @()
$foundVerified = @()

foreach ($path in $scanPaths) {
    if (-Not (Test-Path $path)) { continue }
    $files = Get-ChildItem $path -Recurse -Filter *.jar -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $hackInfo = Get-HackInfo $f
        if ($hackInfo) {
            $foundHacks += @{
                File = $f.FullName
                Client = $hackInfo.Client
                Modules = "Pattern Match"
                Source = $hackInfo.Source
            }
        } elseif (Is-VerifiedMod $f) {
            $foundVerified += @{
                File = $f.FullName
                Mod = $f.Name
                Source = "Verified"
            }
        }
    }
}

# Mostrar resultados
Write-Host "`n┏━ HACKED CLIENTS ━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
foreach ($h in $foundHacks) {
    Write-Host "File: $($h.File)" -ForegroundColor $colorHack
    Write-Host "Detected Client: $($h.Client)" -ForegroundColor $colorHack
    Write-Host "Modules: $($h.Modules)" -ForegroundColor $colorHack
    Write-Host "Possible Source: $($h.Source)" -ForegroundColor $colorHack
    Write-Host "-----------------------------------" -ForegroundColor White
}
Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor White

Write-Host "┏━ VERIFIED MODS ━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
foreach ($v in $foundVerified) {
    Write-Host "File: $($v.File)" -ForegroundColor $colorVerified
    Write-Host "Verified Mod: $($v.Mod)" -ForegroundColor $colorVerified
    Write-Host "Source: $($v.Source)" -ForegroundColor $colorVerified
    Write-Host "-----------------------------------" -ForegroundColor White
}
Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor White
