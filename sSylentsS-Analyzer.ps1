# =============================================
# PowerShell Hacked Clients Detector (Full)
# =============================================
# Carpetas a escanear
$scanPaths = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:TEMP",
    "$env:APPDATA\.minecraft\mods"
)

# Tabla de Hacked Clients y patrones
$hackedClients = @{
    "Meteor" = @("KillAura","AutoTotem","AutoArmor","Velocity","Flight","Scaffold","TriggerBot","Reach","Criticals","AutoMine","FastPlace","ChestSteal")
    "Doomsday" = @("KillAura","AutoTotem","AutoArmor","Velocity","Flight","Criticals","Scaffold","FastPlace","AutoXP","InventoryManipulation")
    "Aristois" = @("KillAura","AutoTotem","AutoArmor","Speed","Flight","TriggerBot","Velocity","ChestSteal","FastPlace","AutoMine")
    "Wurst" = @("KillAura","AutoTotem","AutoArmor","Speed","Flight","Reach","AutoClicker","FastPlace","InventoryTweaks")
    "ThunderHack" = @("KillAura","AutoTotem","AutoArmor","Flight","Velocity","Criticals","TriggerBot","FastPlace","AutoMine","ChestSteal","AutoEat")
    "LiquidBounce" = @("KillAura","Velocity","Flight","Scaffold","FastPlace","ChestSteal","AutoMine")
    "Asteria" = @("KillAura","AutoArmor","Velocity","Flight","Scaffold","FastPlace","AutoTotem")
    "Prestige" = @("KillAura","AutoTotem","AutoArmor","Flight","Criticals","AutoMine","ChestSteal")
    "Xenon" = @("KillAura","AutoArmor","AutoTotem","Flight","FastPlace","InventoryTweaks")
    "Argon" = @("KillAura","AutoTotem","AutoArmor","Velocity","Flight","FastPlace","AutoXP")
    "Krypton" = @("KillAura","AutoTotem","AutoArmor","Velocity","Flight","FastPlace","AutoXP")
}

# Función para analizar un .jar
function Analyze-Jar($jarPath) {
    $scoreTable = @{}
    $modulesDetected = @()

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        $entries = $zip.Entries | ForEach-Object { $_.FullName }
        $zip.Dispose()

        foreach ($client in $hackedClients.Keys) {
            $score = 0
            $modules = @()
            foreach ($pattern in $hackedClients[$client]) {
                foreach ($entry in $entries) {
                    if ($entry -match [regex]::Escape($pattern)) {
                        $score += 10
                        $modules += $pattern
                    }
                }
            }
            $scoreTable[$client] = [PSCustomObject]@{
                Score = $score
                Modules = ($modules | Sort-Object -Unique) -join ", "
            }
        }

        # Elegir cliente con mayor score
        $bestClient = $scoreTable.GetEnumerator() | Sort-Object -Property Value.Score -Descending | Select-Object -First 1
        if ($bestClient.Value.Score -ge 50) {
            # HACKED CLIENT
            Write-Host "🔴 File: $jarPath" -ForegroundColor Red
            Write-Host "Detected Client: $($bestClient.Key)"
            Write-Host "Score: $($bestClient.Value.Score)"
            Write-Host "Modules: $($bestClient.Value.Modules)"
        } else {
            # VERIFIED MOD / UNKNOWN
            Write-Host "🟢 File: $jarPath"
            Write-Host "Verified Mod / Unknown"
        }
        Write-Host "-----------------------------------"
    } catch {
        Write-Host "❌ Error reading $jarPath"
    }
}

# Escaneo de todas las carpetas
foreach ($path in $scanPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Recurse -Filter *.jar | ForEach-Object {
            Analyze-Jar $_.FullName
        }
    }
}
