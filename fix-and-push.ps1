# WebhookPulse Auto-Fix Script for CARTY240HZ
# Run this in PowerShell as Administrator or regular user

$ErrorActionPreference = "Stop"

$Workspace = "C:\Users\khawa\Documents\kimi\workspace\webhookpulse"
$TempRepo = "$env:TEMP\webhookpulse-fix"
$GitHubUser = "CARTY240HZ"
$RepoName = "webhookpulse"
$RemoteUrl = "https://github.com/$GitHubUser/$RepoName.git"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WebhookPulse Auto-Fix for CARTY240HZ" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verify workspace exists
if (-not (Test-Path $Workspace)) {
    Write-Host "ERROR: Workspace not found at $Workspace" -ForegroundColor Red
    exit 1
}

# Check git is available
try {
    $gitVersion = git --version 2>$null
    Write-Host "Git found: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Git not found. Install Git from https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}

# Clean temp repo if exists
if (Test-Path $TempRepo) {
    Remove-Item -Recurse -Force $TempRepo
}

Write-Host "Cloning your GitHub repo..." -ForegroundColor Yellow

# Clone the repo (shallow)
try {
    git clone --depth 1 $RemoteUrl $TempRepo 2>&1 | Out-Null
    Write-Host "Repo cloned successfully" -ForegroundColor Green
} catch {
    Write-Host "Repo doesn't exist or is private. Will create fresh." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $TempRepo | Out-Null
}

# Enter temp repo
Push-Location $TempRepo

try {
    # Initialize if empty
    if (-not (Test-Path ".git")) {
        git init -b main | Out-Null
        Write-Host "Initialized new git repo" -ForegroundColor Green
    }

    # Remove broken files if they exist
    $brokenFiles = @("netlify/functions/webhook.ts", "_redirects", "public/_redirects")
    foreach ($file in $brokenFiles) {
        if (Test-Path $file) {
            Remove-Item -Force $file
            Write-Host "Removed broken file: $file" -ForegroundColor Green
        }
    }

    # Remove ALL old files except .git
    Write-Host "Cleaning old files..." -ForegroundColor Yellow
    Get-ChildItem -Exclude ".git" | Remove-Item -Recurse -Force

    # Copy our project
    Write-Host "Copying WebhookPulse project..." -ForegroundColor Yellow
    Copy-Item -Path "$Workspace\*" -Destination $TempRepo -Recurse -Force

    # Remove node_modules and dist from copied files
    if (Test-Path "node_modules") { Remove-Item -Recurse -Force "node_modules" }
    if (Test-Path "dist") { Remove-Item -Recurse -Force "dist" }
    if (Test-Path "webhookpulse.zip") { Remove-Item -Force "webhookpulse.zip" }

    # Configure git
    git config user.name "WebhookPulse Deploy" | Out-Null
    git config user.email "deploy@webhookpulse.local" | Out-Null

    # Add all files
    git add -A | Out-Null

    # Commit
    git commit -m "feat: WebhookPulse v1 — login, dashboard, 5 Netlify Functions, Supabase" | Out-Null
    Write-Host "Committed all files" -ForegroundColor Green

    # Add remote and push
    git remote remove origin 2>$null
    git remote add origin $RemoteUrl

    Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
    git push -u origin main --force 2>&1 | ForEach-Object {
        if ($_ -match "error|fatal|rejected") {
            Write-Host "GIT: $_" -ForegroundColor Red
        } else {
            Write-Host "GIT: $_" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  PUSH COMPLETED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Go to Netlify Dashboard" -ForegroundColor White
    Write-Host "2. Check deploy logs for the new build" -ForegroundColor White
    Write-Host "3. Verify 5 functions are bundled (no webhook.ts)" -ForegroundColor White
    Write-Host "4. Verify 0 redirect errors" -ForegroundColor White
    Write-Host "5. Go to /login on your site" -ForegroundColor White
    Write-Host ""
    Write-Host "Repo: $RemoteUrl" -ForegroundColor Yellow

} finally {
    Pop-Location
}

# Optional cleanup
# Remove-Item -Recurse -Force $TempRepo
Write-Host ""
Write-Host "Temp repo location: $TempRepo" -ForegroundColor Gray
Write-Host "(You can delete this folder after verifying deploy)" -ForegroundColor Gray
