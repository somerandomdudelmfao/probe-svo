@echo off
setlocal enabledelayedexpansion
title Sourcevoid Probe - Push to GitHub
cd /d "%~dp0"

echo.
echo  Sourcevoid Probe - Push to GitHub
echo.

:: CHECK GIT
where git >nul 2>&1
if errorlevel 1 (
    echo  ERROR: Git is not installed or not in PATH.
    echo  Download it from https://git-scm.com/download/win
    echo  Make sure to tick "Add Git to PATH" during install.
    pause
    exit /b 1
)

:: FINDINGS SOURCE
set "FINDINGS=%APPDATA%\Godot\app_userdata\Sourcevoid Online\findings"
if not exist "%FINDINGS%" (
    echo  ERROR: findings folder not found at:
    echo    %FINDINGS%
    echo  Have you run a probe yet?
    pause
    exit /b 1
)

:: CLEAN OLD FINDINGS IN REPO
echo  Clearing old findings data...
if exist "findings\" rmdir /s /q "findings"
mkdir "findings"

:: READ PROBE DATA
echo  Reading probe data from AppData...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$findingsDir = $env:APPDATA + '\Godot\app_userdata\Sourcevoid Online\findings'; $sessions = @(); Get-ChildItem -LiteralPath $findingsDir -Directory | ForEach-Object { $mapName = $_.Name; $mapPath = $_.FullName; $txtFiles = Get-ChildItem -LiteralPath $mapPath -Filter '*.txt'; foreach ($txt in $txtFiles) { $base = [System.IO.Path]::GetFileNameWithoutExtension($txt.Name); $session = @{ id = ($mapName + '/' + $base); map = $mapName; imageUrls = @() }; $content = Get-Content -LiteralPath $txt.FullName -Raw; foreach ($line in ($content -split [char]10)) { $line = $line.Trim(); if ($line -match 'MAP NAME:(.+)') { $session['map'] = $Matches[1].Trim() }; if ($line -match 'SEED:(.+)') { $session['seed'] = $Matches[1].Trim() }; if ($line -match '^^STARTING COORDS:\s*\(([^)]+)\)') { $p = $Matches[1] -split ','; $session['startCoords'] = @([float]$p[0],[float]$p[1],[float]$p[2]) } elseif ($line -match '^^COORDS:\s*\(([^)]+)\)') { $p = $Matches[1] -split ','; $session['coords'] = @([float]$p[0],[float]$p[1],[float]$p[2]) } }; if ($session.ContainsKey('coords') -and $session['coords'][1] -le -2900) { $session['floorHit'] = $true } else { $session['floorHit'] = $false }; for ($i = 1; $i -le 4; $i++) { $imgName = $base + '_view_' + $i + '.png'; $imgPath = Join-Path $mapPath $imgName; if (Test-Path -LiteralPath $imgPath) { $session['imageUrls'] += ('findings/' + $mapName + '/' + $imgName) } }; $sessions += $session } }; $out = @{ sessions = $sessions } | ConvertTo-Json -Depth 10 -Compress; [System.IO.File]::WriteAllText((Resolve-Path '.').Path + '\findings.json', $out); Write-Host ('Wrote ' + $sessions.Count + ' session(s) to findings.json')"

if errorlevel 1 (
    echo  ERROR: Failed to build findings.json
    pause
    exit /b 1
)

:: COPY IMAGE FILES
echo  Copying probe images...
set "imgCount=0"
for /d %%M in ("%FINDINGS%\*") do (
    set "mapName=%%~nxM"
    if not exist "findings\!mapName!" mkdir "findings\!mapName!"
    for %%F in ("%%M\*.png") do (
        copy /y "%%F" "findings\!mapName!\" >nul
        set /a imgCount+=1
    )
)
echo   Copied %imgCount% image(s).

:: GIT PUSH
echo.
echo  Pushing to GitHub...

git add findings.json findings\ index.html
git diff --cached --quiet
if errorlevel 1 (
    git commit -m "probe update"
    git push
    if errorlevel 1 (
        echo.
        echo  ERROR: git push failed. Check your internet connection.
        pause
        exit /b 1
    )
    echo.
    echo  Done! Your findings are live on GitHub Pages.
) else (
    echo  Nothing changed since last push - already up to date.
)

echo.
pause