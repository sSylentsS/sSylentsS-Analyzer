# =========================================
# sSylentsS Analyzer - Stable Final
# =========================================

$scanPaths = @(
    "$env:APPDATA\.minecraft\mods",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:TEMP"
)

$ignoreFolders = @(
    "\libraries\",
    "\versions\",
    "\remappedJars\"
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

$strongPatterns = @(
    "killaura",
    "crystalaura",
    "triggerbot",
    "autototem",
    "autoarmor",
    "aimassist",
    "scaffold"
)

function Should-Ignore($path){
    $lower = $path.ToLower()

    foreach($folder in $ignoreFolders){
        if($lower.Contains($folder)){ return $true }
    }

    return $false
}

function Get-SourceInfo($file){

    $zonePath = "$file`:Zone.Identifier"

    if(Test-Path $zonePath){
        try{
            $zone = Get-Content $zonePath -ErrorAction Stop
            $zoneText = $zone -join " "

            if($zoneText -match "discord"){
                return "Discord"
            }
            elseif($zoneText -match "mediafire"){
                return "MediaFire"
            }
            elseif($zoneText -match "mega"){
                return "Mega"
            }
            elseif($zoneText -match "dropbox"){
                return "Dropbox"
            }
            elseif($zoneText -match "browser"){
                return "Web Browser"
            }
            else{
                return "Internet Download"
            }
        }
        catch{
            return "Unknown"
        }
    }

    return "Unknown"
}

function Analyze-Jar {
    param($file)

    if(Should-Ignore $file){ return $null }

    $patternsFound = @()
    $score = 0

    try{
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file)

        foreach($entry in $zip.Entries){
            $name = $entry.FullName.ToLower()

            foreach($pattern in $strongPatterns){
                if($name.Contains($pattern)){
                    if(-not $patternsFound.Contains($pattern)){
                        $patternsFound += $pattern
                        $score += 10
                    }
                }
            }

            if($name -eq "fabric.mod.json"){
                $reader = New-Object System.IO.StreamReader($entry.Open())
                $content = $reader.ReadToEnd().ToLower()
                $reader.Close()

                foreach($pattern in $strongPatterns){
                    if($content.Contains($pattern)){
                        if(-not $patternsFound.Contains($pattern)){
                            $patternsFound += $pattern
                            $score += 10
                        }
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
            Score = $score
            Modules = $patternsFound
            Source = Get-SourceInfo $file
        }
    }

    return $null
}

$results = @()

foreach($path in $scanPaths){
    if(Test-Path $path){
        Get-ChildItem $path -Recurse -Filter *.jar -ErrorAction SilentlyContinue | ForEach-Object{
            $r = Analyze-Jar $_.FullName
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
