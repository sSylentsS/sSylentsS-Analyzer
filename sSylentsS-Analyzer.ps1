# ======================================================
# sSylentsS Analyzer - Anti-Cheat Profundo Avanzado
# ======================================================

# Configuración de carpetas a escanear
$scanPaths = @(
    "$env:APPDATA\.minecraft\mods",
    "$env:TEMP",
    "$env:APPDATA\Roaming",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop"
)
$prefetchPath = "C:\Windows\Prefetch"

# Patrones de riesgo
$patternsHigh = "killaura","aimbot","autoclicker","triggerbot","velocity","critical","autototem","autocrystal","automine","autopot","autoarmor","flight","reach","freecam","xray","scaffold","cheststeal","discord","friends","imgui"
$patternsMedium = "inject","hook","javaagent","transformer","premain-class","agent-class","xbootclasspath","clientplayerinteractionmanagermixin","keyboardmixin","clientplayerinteractionmanageraccessor"
$patternsLow = "mixin","event","listener"

# Whitelist mods legítimos
$whitelistMods = "fabric","forge","optifine","sodium","lithium","iris","architectury","cloth-config"

# Funciones
function Get-FileSHA256($file){if(Test-Path $file){return (Get-FileHash -Algorithm SHA256 -Path $file).Hash}return $null}

function Analyze-JAR($file){
    $result = @{File=$file; Status="SAFE"; RiskScore=0; Notes=@()}
    if(-not(Test-Path $file)){$result.Status="ELIMINADO";$result.Notes+="Archivo borrado";return $result}

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try{
        $zip=[System.IO.Compression.ZipFile]::OpenRead($file)
        foreach($entry in $zip.Entries){
            if($whitelistMods | ForEach-Object { $entry.FullName -match $_ }){ continue }
            foreach($pat in $patternsHigh){if($entry.FullName -match $pat){$result.RiskScore+=50;$result.Notes+="$pat"}}
            foreach($pat in $patternsMedium){if($entry.FullName -match $pat){$result.RiskScore+=30;$result.Notes+="$pat"}}
            foreach($pat in $patternsLow){if($entry.FullName -match $pat){$result.RiskScore+=5;$result.Notes+="$pat"}}
        }
        $zip.Dispose()
    }catch{$result.Notes+="No se pudo analizar el JAR"}

    try{
        $tempDir=Join-Path $env:TEMP ([GUID]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($file,$tempDir)
        Get-ChildItem $tempDir -Recurse | ForEach-Object {
            foreach($pat in $patternsHigh){if($_.Name -match $pat){$result.RiskScore+=50;$result.Notes+="$pat"}}
            foreach($pat in $patternsMedium){if($_.Name -match $pat){$result.RiskScore+=30;$result.Notes+="$pat"}}
            foreach($pat in $patternsLow){if($_.Name -match $pat){$result.RiskScore+=5;$result.Notes+="$pat"}}
        }
        Remove-Item $tempDir -Recurse -Force
    }catch{$result.Notes+="No se pudo analizar archivos internos"}

    if($result.RiskScore -ge 60){$result.Status="HACKED CLIENT"}
    elseif($result.RiskScore -ge 30){$result.Status="SUSPICIOUS MOD"}

    return $result
}

function Scan-Folders(){
    $results=@()
    foreach($path in $scanPaths){
        if(Test-Path $path){
            Get-ChildItem -Path $path -Recurse -Filter *.jar -Force | ForEach-Object{$results+=[PSCustomObject]$(Analyze-JAR $_.FullName)}
        }
    }
    return $results
}

function Scan-Prefetch(){
    $results=@()
    if(Test-Path $prefetchPath){
        Get-ChildItem $prefetchPath -Filter "*java*" | ForEach-Object{$results+=[PSCustomObject]@{File=$_.Name; Status="LOADER / PREFETCH"; RiskScore=30; Notes="Ejecución histórica"}}
        Get-ChildItem $prefetchPath | Where-Object{$_.Name -match "loader|vape|novoline|doomsday"} | ForEach-Object{$results+=[PSCustomObject]@{File=$_.Name; Status="LOADER / PREFETCH"; RiskScore=50; Notes="Loader detectado"}}
    }
    return $results
}

function Scan-JavaProcesses(){
    $results=@()
    Get-CimInstance Win32_Process | Where-Object{$_.Name -like "java*"} | ForEach-Object{
        $args=$_.CommandLine;$risk=0;$notes=@()
        if($args -match "-javaagent" -or $args -match "Xbootclasspath" -or $args -match "Premain-Class" -or $args -match "Agent-Class"){$risk+=60;$notes+="Argumentos JVM sospechosos"}
        $status="SAFE";if($risk -ge 30){$status="GHOST CLIENT"}
        $results+=[PSCustomObject]@{File=$_.Name; Status=$status; RiskScore=$risk; Notes=$notes}
    }
    return $results
}

# Ejecución principal
$finalReport=@()
$finalReport += Scan-Folders
$finalReport += Scan-Prefetch
$finalReport += Scan-JavaProcesses

# Impresión estilo legible
function Print-Block($title,$list,$color){if($list.Count -eq 0){return};Write-Host "┏━ $title ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $color;foreach($item in $list){Write-Host "File: $($item.File)" -ForegroundColor $color; if($item.Notes.Count -gt 0){Write-Host "Detected Patterns:" -ForegroundColor $color; foreach($note in $item.Notes){Write-Host "  • $note" -ForegroundColor $color}};Write-Host "---------------------------------------" -ForegroundColor $color};Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $color}

$verified = $finalReport | Where-Object { $_.Status -eq "LEGIT MOD" }
$unknown = $finalReport | Where-Object { $_.Status -eq "SAFE" -and $_.Notes.Count -gt 0 }
$suspicious = $finalReport | Where-Object { $_.Status -eq "SUSPICIOUS MOD" }
$hacks = $finalReport | Where-Object { $_.Status -eq "HACKED CLIENT" }
$ghost = $finalReport | Where-Object { $_.Status -eq "GHOST CLIENT" }
$loader = $finalReport | Where-Object { $_.Status -eq "LOADER / PREFETCH" }

Print-Block "VERIFIED MODS" $verified "Cyan"
Print-Block "UNKNOWN MODS" $unknown "White"
Print-Block "SUSPICIOUS MODS" $suspicious "Yellow"
Print-Block "HACKED CLIENTS" $hacks "Red"
Print-Block "GHOST CLIENTS" $ghost "Magenta"
Print-Block "LOADERS / PREFETCH" $loader "DarkRed"

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host ("Total scanned: {0}" -f $finalReport.Count) -ForegroundColor Cyan
Write-Host ("Verified: {0}" -f $verified.Count) -ForegroundColor Cyan
Write-Host ("Unknown: {0}" -f $unknown.Count) -ForegroundColor Cyan
Write-Host ("Suspicious: {0}" -f $suspicious.Count) -ForegroundColor Cyan
Write-Host ("Hacked Clients: {0}" -f $hacks.Count) -ForegroundColor Cyan
Write-Host ("Ghost Clients: {0}" -f $ghost.Count) -ForegroundColor Cyan
Write-Host ("Loaders / Prefetch: {0}" -f $loader.Count) -ForegroundColor Cyan
Write-Host "`n=====================================`n" -ForegroundColor Cyan
