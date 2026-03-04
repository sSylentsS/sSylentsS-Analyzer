# ======================================================
# sSylentsS Analyzer - Anti-Cheat Profundo
# ======================================================

# Paths
$modsPath = "$env:APPDATA\.minecraft\mods"
$tempPaths = @("$env:TEMP","$env:APPDATA\Roaming")
$prefetchPath = "C:\Windows\Prefetch"
$hashPath = ".\hashes"

# Cargar hashes conocidos
$verifiedHashes = @()
$hackedHashes = @()
if(Test-Path "$hashPath\verified_mods.json"){ $verifiedHashes = Get-Content "$hashPath\verified_mods.json" | ConvertFrom-Json }
if(Test-Path "$hashPath\hacked_clients.json"){ $hackedHashes = Get-Content "$hashPath\hacked_clients.json" | ConvertFrom-Json }

# Patrones sospechosos
$patterns = @{
    High = @("killaura","aimbot","autoclicker","reach","velocity","criticals")
    Medium = @("inject","hook","javaagent","transformer","packet","premain-class","agent-class","xbootclasspath")
    Low = @("mixin","event","listener")
}

# Whitelist mods legítimos
$whitelistMods = @("fabric","forge","optifine","sodium","lithium","iris","architectury","cloth-config")

# -------------------------------
# Funciones
# -------------------------------
function Get-FileSHA256($file){ if(Test-Path $file){ return (Get-FileHash -Algorithm SHA256 -Path $file).Hash }; return $null }

function Analyze-JAR($file){
    $result = @{File=$file; Status="SAFE"; RiskScore=0; Notes=@()}
    if(-not(Test-Path $file)){ $result.Status="ELIMINADO"; $result.Notes+="Archivo borrado"; return $result }

    $hash = Get-FileSHA256 $file
    if($verifiedHashes -contains $hash){ $result.Status="LEGIT MOD"; $result.Notes+="Hash verificado"; return $result }
    if($hackedHashes -contains $hash){ $result.Status="HACKED CLIENT"; $result.Notes+="Hash hack conocido"; return $result }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try{
        $zip=[System.IO.Compression.ZipFile]::OpenRead($file)
        foreach($entry in $zip.Entries){
            if($whitelistMods | ForEach-Object { $entry.FullName -match $_ }){ continue }
            foreach($lvl in $patterns.Keys){
                foreach($pat in $patterns[$lvl]){
                    if($entry.FullName -match $pat){
                        switch($lvl){ High{$result.RiskScore+=50} Medium{$result.RiskScore+=30} Low{$result.RiskScore+=5} }
                        $result.Notes+=" $($entry.FullName)"
                    }
                }
            }
        }
        $zip.Dispose()
    }catch{$result.Notes+="No se pudo analizar el JAR"}

    if($result.RiskScore -ge 60){$result.Status="HACKED CLIENT"}
    elseif($result.RiskScore -ge 30){$result.Status="SUSPICIOUS MOD"}

    return $result
}

function Scan-Prefetch(){
    $results=@()
    if(Test-Path $prefetchPath){
        Get-ChildItem $prefetchPath -Filter "*java*" | ForEach-Object{
            $results+=[PSCustomObject]@{File=$_.Name; Status="LOADER / PREFETCH"; RiskScore=30; Notes="Ejecución histórica"}
        }
        Get-ChildItem $prefetchPath | Where-Object{$_.Name -match "loader|vape|novoline|doomsday"} | ForEach-Object{
            $results+=[PSCustomObject]@{File=$_.Name; Status="LOADER / PREFETCH"; RiskScore=50; Notes="Loader detectado"}
        }
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

function Scan-Temp(){
    $results=@()
    foreach($path in $tempPaths){
        if(Test-Path $path){
            Get-ChildItem -Path $path -Recurse -Force | Where-Object { $_.Name -match "loader|vape|novoline|doomsday" } | ForEach-Object{
                $results+=[PSCustomObject]@{File=$_.FullName; Status="SUSPICIOUS / TEMP"; RiskScore=30; Notes="Archivo sospechoso"}
            }
        }
    }
    return $results
}

# -------------------------------
# Ejecución principal
# -------------------------------
$finalReport=@()
Get-ChildItem -Path $modsPath -Filter *.jar | ForEach-Object{ $finalReport += Analyze-JAR $_.FullName }
$finalReport += Scan-Prefetch
$finalReport += Scan-JavaProcesses
$finalReport += Scan-Temp

# Mostrar resultados en consola con colores
Write-Host "`n===== sSylentsS Analyzer Report =====`n" -ForegroundColor Cyan
foreach($item in $finalReport | Sort-Object RiskScore -Descending){
    switch($item.Status){
        "HACKED CLIENT" { $color="Red" }
        "GHOST CLIENT" { $color="Magenta" }
        "SUSPICIOUS MOD" { $color="Yellow" }
        "LOADER / PREFETCH" { $color="DarkRed" }
        "SUSPICIOUS / TEMP" { $color="DarkYellow" }
        "SAFE" { $color="Green" }
        "LEGIT MOD" { $color="Cyan" }
        default { $color="White" }
    }
    Write-Host ("{0,-50} | {1,-15} | {2}" -f $item.File, $item.Status, ($item.Notes -join ", ")) -ForegroundColor $color
}
Write-Host "`n=====================================`n" -ForegroundColor Cyan
