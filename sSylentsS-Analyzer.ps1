# =========================================
# sSylentsS Analyzer - Clean Architecture
# =========================================

Add-Type -AssemblyName System.IO.Compression.FileSystem

$scanPaths = @(
    "$env:APPDATA\.minecraft\mods",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:TEMP"
)

$strongPatterns = @(
    "killaura",
    "crystalaura",
    "triggerbot",
    "autototem",
    "autoarmor",
    "aimassist",
    "scaffold"
)

function Get-SourceInfo($file){
    $zonePath = "$file`:Zone.Identifier"

    if(Test-Path $zonePath){
        try{
            $zone = Get-Content $zonePath -ErrorAction Stop
            $text = $zone -join " "
            if($text -match "discord"){ return "Discord" }
            if($text -match "mediafire"){ return "MediaFire" }
            if($text -match "mega"){ return "Mega" }
            if($text -match "dropbox"){ return "Dropbox" }
            return "Internet"
        } catch { return "Unknown" }
    }

    return "Unknown"
}

function Analyze-Jar($file){

    $patternsFound = @()

    try{
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file)

        foreach($entry in $zip.Entries){
            $name = $entry.FullName.ToLower()

            foreach($pattern in $strongPatterns){
                if($name.Contains($pattern)){
                    if(-not $patternsFound.Contains($pattern)){
                        $patternsFound += $pattern
                    }
                }
            }
        }

        $zip.Dispose()
    }
    catch{
        return $null
    }

    if($patternsFound.Count -ge 2){
        return [PSCustomObject]@{
            File = $file
            Modules = $patternsFound
            Score = $patternsFound.Count * 10
            Source = Get-SourceInfo $file
        }
    }

    return $null
}

$results = @()

foreach($basePath in $scanPaths){

    if(Test-Path $basePath){

        # SOLO JARS DIRECTOS (sin recurse infinito)
        $jars = Get-ChildItem $basePath -Filter *.jar -File -ErrorAction SilentlyContinue

        foreach($jar in $jars){
            $r = Analyze-Jar $jar.FullName
            if($r){ $results += $r }
        }
    }
}

if($results.Count -eq 0){
    Write-Host "`nNo hacked clients detected." -ForegroundColor Green
    return
}

Write-Host "`n┏━ HACKED CLIENTS ━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red

foreach($r in $results){
    Write-Host "File: $($r.File)" -ForegroundColor Red
    Write-Host "Score: $($r.Score)" -ForegroundColor Red
    Write-Host "Modules: $($r.Modules -join ', ')" -ForegroundColor Red
    Write-Host "Possible Source: $($r.Source)" -ForegroundColor Red
    Write-Host "-----------------------------------" -ForegroundColor Red
}

Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
Write-Host "`nScan Complete."
