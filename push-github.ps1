param(
  [Parameter(Mandatory = $false)]
  [string]$Message = "Engelsiz Club: guncel kod"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "==> git status" -ForegroundColor Cyan
git status -sb

git branch --unset-upstream 2>$null

Write-Host "==> git add -A" -ForegroundColor Cyan
git add -A

$status = git status --porcelain
if (-not $status) {
  Write-Host "Commit edilecek degisiklik yok." -ForegroundColor Yellow
  exit 0
}

Write-Host "==> git commit" -ForegroundColor Cyan
git commit -m $Message
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> git push -u origin main" -ForegroundColor Cyan
git push -u origin main
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Tamam. https://github.com/Metehanxpvl/engelsizclub" -ForegroundColor Green
git status -sb
