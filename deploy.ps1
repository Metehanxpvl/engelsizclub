# Engelsiz Club — Firebase Hosting deploy
# Önce bir kez: firebase login
# Firebase Console'da "engelsizclub" projesi yoksa oluştur, .firebaserc ID'yi eşleştir.

$ErrorActionPreference = "Stop"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Set-Location $PSScriptRoot

Write-Host "==> flutter build web --release" -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> firebase deploy --only hosting" -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Deploy tamam. Sonraki adimlar:" -ForegroundColor Green
Write-Host "1) Firebase Console > Hosting > Add custom domain: www.engelsizclub.com"
Write-Host "2) GoDaddy DNS'e Firebase'in verdigi A/CNAME/TXT kayitlarini ekle"
Write-Host "3) Supabase Auth Site URL: https://www.engelsizclub.com"
Write-Host "Detay: DEPLOY.md"
