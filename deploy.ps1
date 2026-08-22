# Engelsiz Club — Firebase Hosting deploy
# Önce bir kez: firebase login
# Firebase Console'da "engelsizclub" projesi yoksa oluştur, .firebaserc ID'yi eşleştir.

$ErrorActionPreference = "Stop"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Set-Location $PSScriptRoot

Write-Host "==> flutter build web --release" -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Statik bilgi kutuphanesi sayfalari (Flutter build bazen alt klasorleri atlayabilir)
Write-Host "==> Sync bilgi-kutuphanesi static pages" -ForegroundColor Cyan
$staticRoots = @(
  "web\bilgi-kutuphanesi\cvi-egzersizleri-2",
  "web\bilgi-kutuphanesi\0-2-yas-gelisim-rehberi",
  "web\bilgi-kutuphanesi\cvi-gorsel-egzersizler"
)
foreach ($src in $staticRoots) {
  if (Test-Path $src) {
    $dest = Join-Path "build\web" ($src -replace '^web\\', '')
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -Recurse -Force "$src\*" $dest
  }
}

Write-Host "==> firebase deploy --only hosting" -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Deploy tamam. Sonraki adimlar:" -ForegroundColor Green
Write-Host "1) Firebase Console > Hosting > Add custom domain: www.engelsizclub.com"
Write-Host "2) GoDaddy DNS'e Firebase'in verdigi A/CNAME/TXT kayitlarini ekle"
Write-Host "3) Supabase Auth Site URL: https://www.engelsizclub.com"
Write-Host "Detay: DEPLOY.md"
