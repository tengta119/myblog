param(
    [string]$Server = "47.115.213.32",
    [string]$User = "root",
    [string]$RemoteDir = "/opt/hexo-blog/html"
)

$ErrorActionPreference = "Stop"

function Assert-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Command not found: $Name"
    }
}

Assert-Command "hexo"

Write-Host "==> Cleaning Hexo cache..."
hexo clean

Write-Host "==> Generating static files..."
hexo generate

if (-not (Test-Path ".\public\index.html")) {
    throw "Build output not found: .\public\index.html"
}

$target = "${User}@${Server}"

Write-Host "==> Uploading public files..."
scp -r ".\public\*" "${target}:${RemoteDir}/"

Write-Host "==> Deployment finished."
Write-Host "scp -r .\public\* root@47.115.213.32:/opt/hexo-blog/html/ "
Write-Host "Visit: https://$Server/ or your configured domain."
