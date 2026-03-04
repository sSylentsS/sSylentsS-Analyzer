# =========================================
# sSylentsS Analyzer
# File Analysis Only - Advanced Detection
# =========================================

$scanPaths = @(
    "$env:APPDATA\.minecraft\mods",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:TEMP"
)

$ignorePatterns = @(
    "\libraries\",
    "\versions\",
    "\remappedJars\",
    "client-intermediary",
    "forge-",
    "fabric-loader",
    "minecraft-"
)

# ===============================
# EDITABLE HASH DATABASE (SHA256)
# ===============================
$hashDatabase = @{
    # "SHA256HASH" = "ClientName"
}

# ===============================
# Pattern Score System
# ===============================
$patternWeights = @{
    "killaura" = 6
    "crystalaura" = 6
    "triggerbot" = 5
    "autoarmor" = 4
    "autototem" = 4
    "scaffold" = 4
    "aimassist" = 5
    "reach" = 1
    "speed" = 1
    "flight" = 2
    "velocity" = 2
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Should-Ignore($path){
    foreach($pattern in $ignorePatterns){
        if($path -match $pattern){ return $true }
    }
    return $false
}

function Get-ZoneScore($file){
    try{
        $zone = Get-Content "$file`:Zone.Identifier" -ErrorAction Stop
        $zoneText = $zone -join " "
        if($zoneText -match "discord|mediafire|mega|dropbox"){
            return 3
        }
    } catch {}
    return 0
}

function Analyze-Jar {
    param($file)

    if(Should-Ignore $file){ return $null }

    $score = 0
    $detectedPatterns = @()

    # ---------------- HASH CHECK ----------------
    try{
        $hash = (Get-FileHash $file -Algorithm SHA256).Hash
        if($hashDatabase.ContainsKey($hash)){
            return [PSCustomObject]@{
                File = $file
                Client = $hashDatabase[$hash]
                Score = 100
                Confidence = "HIGH (Hash Match)"
                Patterns = @()
            }
        }
    } catch {}

    # ---------------- CONTENT ANALYSIS ----------------
    try{
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file)

        foreach($entry in $zip.Entries){
            $name = $entry.FullName.ToLower()

            foreach($pattern in $patternWeights.Keys){
                if($name -like "*$pattern*"){
                    if(-not $detectedPatterns.Contains($pattern)){
                        $detectedPatterns += $pattern
                        $score += $patternWeights[$pattern]
                    }
                }
            }

            if($name -eq "fabric.mod.json"){
                $reader = New-Object System.IO.StreamReader($entry.Open())
                $content = $reader.ReadToEnd().ToLower()
                $reader.Close()

                foreach($pattern in $patternWeights.Keys){
                    if($content -like "*$pattern*"){
                        if(-not $detectedPatterns.Contains($pattern)){
                            $detectedPatterns += $pattern
                            $score += $patternWeights[$pattern]
                        }
                    }
                }
            }
        }

        $zip.Dispose()
    } catch {}

    # ---------------- ZONE IDENTIFIER ----------------
    $score += Get-ZoneScore $file

    # ---------------- CLASSIFICATION ----------------
    if($score -ge 18){
        return [PSCustomObject]@{
            File = $file
            Client = "Unknown"
            Score = $score
            Confidence = "HIGH (Pattern Score)"
            Patterns = $detectedPatterns
        }
    }

    if($score -ge 10){
        return [PSCustomObject]@{
            File = $file
            Client = "Unknown"
            Score = $score
            Confidence = "MEDIUM (Suspicious Patterns)"
            Patterns = $detectedPatterns
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

$hacked = $results | Where-Object { $_.Score -ge 18 }
$suspicious = $results | Where-Object { $_.Score -lt 18 }

function Print-Section($title,$items,$color){
    if($items.Count -eq 0){ return }
    Write-Host "`n┏━ $title ━━━━━━━━━━━━━━━━━━━" -ForegroundColor $color
    foreach($i in $items){
        Write-Host "File: $($i.File)" -ForegroundColor $color
        Write-Host "Score: $($i.Score)" -ForegroundColor $color
        Write-Host "Confidence: $($i.Confidence)" -ForegroundColor $color
        if($i.Patterns.Count -gt 0){
            Write-Host "Patterns: $($i.Patterns -join ', ')" -ForegroundColor $color
        }
        Write-Host "-----------------------------------" -ForegroundColor $color
    }
    Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $color
}

Print-Section "HACKED CLIENTS" $hacked "Red"
Print-Section "SUSPICIOUS FILES" $suspicious "Yellow"

Write-Host "`nScan Complete."
