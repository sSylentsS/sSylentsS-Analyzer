# ─────────── Hack Analyzer ───────────
# Autor: sSylentsS
# Detecta hacks recientes y patrones sospechosos en .jar

# Carpeta a escanear
$scanPaths = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\AppData\Roaming\.minecraft\mods",
    "$env:TEMP"
)

# Diccionario de hacks conocidos recientes
$knownHacks = @{
    "modmenu"     = @{ Name="Meteor"; URL="https://meteorclient.com/archive" }
    "sodium"      = @{ Name="Wurst"; URL="https://www.wurstclient.net/" }
    "appleskin"   = @{ Name="Doomsday"; URL="https://doomsdayclient.com/" }
    "lithium"     = @{ Name="Aristois"; URL="https://aristois.net/" }
    # Puedes añadir más hacks aquí
}

# Patrones sospechosos dentro del JAR
$patterns = @(
    "velocity", "flight", "reach", "scaffold", "speed",
    "aimassist", "autoarmor", "autototem", "crystalaura",
    "killaura", "triggerbot", "freecam", "xray", "autoclicker"
)

function Get-ModulesFromJar {
    param([string]$file)
    $matches = @()
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file)
        foreach($entry in $zip.Entries){
            foreach($p in $patterns){
                if($entry.FullName -match [regex]::Escape($p)){
                    if(-not $matches.Contains($p)){ $matches += $p }
                }
            }
        }
        $zip.Dispose()
    } catch { }
    return $matches
}

function Detect-Hack {
    param([string]$file)
    $lowerFile = ($file | Split-Path -Leaf).ToLower()
    foreach($key in $knownHacks.Keys){
        if($lowerFile -match $key){
            return $knownHacks[$key]
        }
    }
    return $null
}

Write-Host "`n┏━ HACKED CLIENTS ━━━━━━━━━━━━━━━━━━━"
foreach($path in $scanPaths){
    if(Test-Path $path){
        Get-ChildItem -Path $path -Filter *.jar -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $file = $_.FullName
            $modules = Get-ModulesFromJar -file $file
            $hackInfo = Detect-Hack -file $file
            if($hackInfo -or $modules.Count -gt 0){
                $score = $modules.Count * 10
                if($hackInfo){
                    $name = $hackInfo.Name
                    $source = $hackInfo.URL
                } else {
                    $name = "Suspicious"
                    $source = "Unknown"
                }
                Write-Host "File: $file"
                Write-Host "Detected Client: $name"
                Write-Host "Score: $score"
                if($modules.Count -gt 0){
                    Write-Host "Modules: $(($modules -join ', '))"
                }
                Write-Host "Possible Source: $source"
                Write-Host "-----------------------------------"
            }
        }
    }
}
Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
