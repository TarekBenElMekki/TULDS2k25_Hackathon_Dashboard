$ErrorActionPreference = "Stop"

$repoUrl = "https://github.com/TarekBenElMekki/TU-LDs_hackathon_dashboard.git"

if (-not (Test-Path "README.md")) {
    Set-Content -Path "README.md" -Value "# TU-LDs_hackathon_dashboard"
} else {
    $content = Get-Content "README.md" -Raw
    if ($content -notmatch "TU-LDs_hackathon_dashboard") {
        Add-Content -Path "README.md" -Value "`r`n# TU-LDs_hackathon_dashboard"
    }
}

if (-not (Test-Path ".git")) {
    git init
}

git add README.md

try {
    git commit -m "v1"
} catch {
    Write-Host "Nothing new to commit, continuing..."
}

git branch -M main

$hasOrigin = git remote | Select-String "^origin$"

if ($hasOrigin) {
    git remote set-url origin $repoUrl
} else {
    git remote add origin $repoUrl
}

git push -u origin main



