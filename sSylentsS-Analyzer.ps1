# =========================================
# PowerShell Mega Hack & Mod Analyzer v2.0
# =========================================

# Colores para la consola
$Host.UI.RawUI.ForegroundColor = "White"

# Directorios a escanear
$scanPaths = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:TEMP",
    "$env:APPDATA\.minecraft\mods"
)

# Patrones de hacks más de 100 patrones recientes
$suspiciousPatterns = @(
    # Combate
    "AimAssist","AutoCrystal","AutoHitCrystal","TriggerBot","Velocity","Criticals","Reach","Hitboxes","ShieldBreaker","ShieldDisabler","AxeSpam",
    # Movimiento
    "Flight","AntiKnockback","NoKnockback","JumpReset","SprintReset","NoJumpDelay",
    # PvP Utilities
    "AutoTotem","AutoArmor","AutoPot","AutoDoubleHand","InventoryTotem","TotemHit","PopSwitch","LagReach","WTap","FakeLag",
    # Visual
    "BlockESP","Freecam","PackSpoof","PingSpoof","FakeNick","FakeItem",
    # Automatización
    "FastPlace","ChestSteal","Refill","AutoEat","AutoMine","AutoClicker","FastXP",
    # Patrones ofuscados
    "org\.chainlibs\.module\.impl\.modules\..*",
    "じ\.class","ふ\.class","ぶ\.class",
    "KeyboardMixin","ClientPlayerInteractionManagerMixin","LicenseCheckMixin",
    "phantom-refmap\.json","xyz\.greaj",
    "jnativehook","imgui\.gl3","imgui\.glfw"
)

# Clientes conocidos y su página oficial
$knownSources = @{
    "Doomsday"  = "https://doomsdayclient.com/"
    "Meteor"    = "https://meteorclient.com/archive"
    "Aristois"  = "https://aristois.net/"
    "Wurst"     = "https://www.wurstclient.net/"
    "Xenon"     = "https://xenonclient.com/"
    "Prestige"  = "https://prestigeclient.com/"
    "Hellion"   = "https://hellionclient.com/"
    "Donut"     = "https://donutclient.com/"
    "Krypton"   = "https://kryptonclient.net/"
}

$scoreThreshold = 10

function Analyze-Jar($filePath){
    $score = 0
    $foundPatterns = @()
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($filePath)
        foreach($entry in $zip.Entries){
            foreach($pattern in $suspiciousPatterns){
                if($entry.FullName -match $pattern){
                    $score += 10
                    $foundPatterns += $pattern
                }
            }
        }
        $zip.Dispose()
    } catch {
        Write-Host "Error leyendo $filePath" -ForegroundColor Yellow
    }

    # Detectar cliente probable
    $detectedClient = $null
    foreach($client in $knownSources.Keys){
        foreach($pattern in $suspiciousPatterns){
            if($foundPatterns -contains $pattern){
                $detectedClient = $client
                break
            }
        }
    }

    # Detectar fuente de descarga
    $source = "Internet"
    try {
        $zonePath = "$filePath`:Zone.Identifier"
        if(Test-Path $zonePath){
            $zoneContent = Get-Content $zonePath -ErrorAction SilentlyContinue
            if($zoneContent -match "https?://([^`r`n]+)"){
                $source = $matches[0]
            }
        }
    } catch { }

    # Clasificación
    if($score -ge $scoreThreshold){
        $category = "HACKED CLIENTS"
        $color = "Red"
    } elseif($score -gt 0){
        $category = "SUSPICIOUS MODS"
        $color = "Yellow"
    } else {
        $category = "VERIFIED MODS"
        $color = "Green"
    }

    [PSCustomObject]@{
        File = $filePath
        Score = $score
        DetectedClient = if($detectedClient){$detectedClient}else{"-"}
        Patterns = if($foundPatterns.Count -gt 0){$foundPatterns -join ", "}else{"-"}
        Source = $source
        Category = $category
        Color = $color
    }
}

# Escanear todos los directorios y .jar
$results = @()
foreach($path in $scanPaths){
    if(Test-Path $path){
        Get-ChildItem -Path $path -Recurse -Filter *.jar | ForEach-Object {
            $results += Analyze-Jar $_.FullName
        }
    }
}

# Mostrar resultados
foreach($category in @("HACKED CLIENTS","SUSPICIOUS MODS","VERIFIED MODS")){
    $categoryResults = $results | Where-Object {$_.Category -eq $category}
    if($categoryResults.Count -gt 0){
        Write-Host "`n┏━ $category ━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        foreach($r in $categoryResults){
            Write-Host "File: $($r.File)" -ForegroundColor $r.Color
            Write-Host "Detected Client: $($r.DetectedClient)" -ForegroundColor $r.Color
            Write-Host "Score: $($r.Score)" -ForegroundColor $r.Color
            Write-Host "Patterns: $($r.Patterns)" -ForegroundColor $r.Color
            Write-Host "Possible Source: $($r.Source)" -ForegroundColor $r.Color
            Write-Host "-----------------------------------" -ForegroundColor Gray
        }
        Write-Host "┗" + "━" * 30
    }
}
    Write-Host "-----------------------------------" -ForegroundColor White
}
Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor White
