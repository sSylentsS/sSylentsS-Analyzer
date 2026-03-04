# ==========================================
# sSylentsS Analyzer
# Escaneo de Minecraft Hacks - Consola
# ==========================================

# Carpeta a escanear
$scanPaths = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:TEMP",
    "$env:APPDATA\.minecraft\mods"
)

# Definición de patrones de hacks (simplificado para ejemplo)
$hackPatterns = @{
    "Meteor"    = @{
        Patterns = "autoarmor","autototem","killaura","flight","scaffold"
        Source   = "https://meteorclient.com/archive"
    }
    "Doomsday"  = @{
        Patterns = "autototem","autoarmor","aimassist","killaura","flight"
        Source   = "https://doomsdayclient.com/"
    }
    "Aristois"  = @{
        Patterns = "killaura","velocity","reach","scaffold","triggerbot"
        Source   = "https://aristois.net/"
    }
    "Wurst"     = @{
        Patterns = "aimassist","autoarmor","autototem","flight","scaffold"
        Source   = "https://www.wurstclient.net/"
    }
}

# Función para analizar un archivo .jar
function Analyze-Jar {
    param($file)

    $contentPatterns = @()
    try {
        # Listar archivos dentro del jar
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file)
        foreach ($entry in $zip.Entries) {
            $contentPatterns += $entry.FullName
        }
        $zip.Dispose()
    } catch {}

    $matchedHack = $null
    $score = 0
    $modules = @()

    foreach ($hack in $hackPatterns.Keys) {
        $hackInfo = $hackPatterns[$hack]
        foreach ($pattern in $hackInfo.Patterns) {
            foreach ($entry in $contentPatterns) {
                if ($entry -match [regex]::Escape($pattern)) {
                    $modules += $pattern
                    $score += 10
                }
            }
        }
        if ($modules.Count -gt 0) {
            $matchedHack = $hack
            break
        }
    }

    if ($matchedHack) {
        # Hack detectado
        Write-Host "File: $file" -ForegroundColor Red
        Write-Host "Detected Client: $matchedHack" -ForegroundColor Red
        Write-Host "Score: $score" -ForegroundColor Red
        Write-Host "Modules: $($modules -join ', ')" -ForegroundColor Red
        Write-Host "Possible Source: $($hackPatterns[$matchedHack].Source)" -ForegroundColor Red
        Write-Host "-----------------------------------" -ForegroundColor Red
    } else {
        # Mod verificado / seguro
        Write-Host "File: $file" -ForegroundColor Green
        Write-Host "Verified Mod / Unknown" -ForegroundColor Green
        Write-Host "-----------------------------------" -ForegroundColor Green
    }
}

# Escaneo de todas las carpetas
foreach ($path in $scanPaths) {
    if (Test-Path $path) {
        Get-ChildItem $path -Recurse -Filter *.jar -ErrorAction SilentlyContinue | ForEach-Object {
            Analyze-Jar $_.FullName
        }
    }
}
