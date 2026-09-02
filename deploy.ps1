# Engelsiz Club — Firebase Hosting deploy
# Once bir kez: firebase login
# Firebase Console'da "engelsizclub" projesi yoksa olustur, .firebaserc ID'yi eslestir.

$ErrorActionPreference = "Stop"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Set-Location $PSScriptRoot

# Gitignored .env / .env.local — process environment wins; values are never printed.
function Import-DotEnvFile([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return }
  Write-Host ("==> Loading names from " + (Split-Path $path -Leaf) + " (values hidden)") -ForegroundColor Cyan
  Get-Content -LiteralPath $path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    if ($line.StartsWith('export ')) { $line = $line.Substring(7).Trim() }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { return }
    $k = $line.Substring(0, $eq).Trim()
    $v = $line.Substring($eq + 1).Trim()
    if ($v.Length -ge 2 -and (
      ($v.StartsWith('"') -and $v.EndsWith('"')) -or
      ($v.StartsWith("'") -and $v.EndsWith("'"))
    )) {
      $v = $v.Substring(1, $v.Length - 2)
    }
    $existing = [Environment]::GetEnvironmentVariable($k)
    if ([string]::IsNullOrWhiteSpace($existing)) {
      [Environment]::SetEnvironmentVariable($k, $v)
    }
  }
}
Import-DotEnvFile (Join-Path $PSScriptRoot '.env')
Import-DotEnvFile (Join-Path $PSScriptRoot '.env.local')

# .env.example aliases → dart-define names (still no values printed)
if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('R2_BUCKET'))) {
  $bucketAlias = [Environment]::GetEnvironmentVariable('R2_BUCKET_NAME')
  if (-not [string]::IsNullOrWhiteSpace($bucketAlias)) {
    [Environment]::SetEnvironmentVariable('R2_BUCKET', $bucketAlias)
  }
}
if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('R2_PUBLIC_BASE_URL'))) {
  $publicAlias = [Environment]::GetEnvironmentVariable('R2_PUBLIC_URL')
  if (-not [string]::IsNullOrWhiteSpace($publicAlias)) {
    [Environment]::SetEnvironmentVariable('R2_PUBLIC_BASE_URL', $publicAlias)
  }
}

# Optional compile-time secrets from the process environment / .env (never hardcoded).
$defineNames = @(
  'GEMINI_API_KEY', 'GROQ_API_KEY', 'GEMINI_MODEL', 'GROQ_MODEL',
  'GEMINI_PROXY_URL',
  'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_ENDPOINT', 'R2_BUCKET',
  'R2_PUBLIC_BASE_URL', 'R2_WORKER_URL', 'R2_ACCOUNT_ID'
)
$defines = @()
$presentDefines = @()
$webSkipSecrets = @('GEMINI_API_KEY', 'GROQ_API_KEY')
foreach ($name in $defineNames) {
  if ($webSkipSecrets -contains $name) { continue }
  $val = [Environment]::GetEnvironmentVariable($name)
  if (-not [string]::IsNullOrWhiteSpace($val)) {
    $defines += "--dart-define=$name=$val"
    $presentDefines += $name
  }
}
if ($presentDefines.Count -gt 0) {
  Write-Host ("==> dart-defines from env: " + ($presentDefines -join ', ')) -ForegroundColor Cyan
} else {
  Write-Host "==> No GEMINI/R2 dart-defines in environment; live barcode LLM/R2 client keys will be empty (R2 public URL/endpoint have code defaults)." -ForegroundColor Yellow
}

# Cloud Function proxy skipped: Blaze required. Use Cloudflare Worker /gemini
# or Supabase Edge Function gemini-proxy instead (see cloudflare/wrangler.toml).
Write-Host "==> Gemini CORS proxy: Cloudflare Worker POST /gemini (prefer) or Supabase gemini-proxy" -ForegroundColor Cyan

$geminiForProxy = [Environment]::GetEnvironmentVariable('GEMINI_API_KEY')
$workerDir = Join-Path $PSScriptRoot 'cloudflare'
if (Test-Path (Join-Path $workerDir 'wrangler.toml')) {
  Push-Location $workerDir
  try {
    Write-Host "==> wrangler deploy (engelsizclub-r2)" -ForegroundColor Cyan
    $wranglerOut = npx --yes wrangler deploy 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
      Write-Host "==> Worker deploy OK" -ForegroundColor Green
      $m = [regex]::Match($wranglerOut, 'https://[a-zA-Z0-9._-]+\.workers\.dev')
      if ($m.Success) {
        $workerUrl = $m.Value.TrimEnd('/')
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('R2_WORKER_URL'))) {
          [Environment]::SetEnvironmentVariable('R2_WORKER_URL', $workerUrl)
        }
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('GEMINI_PROXY_URL'))) {
          [Environment]::SetEnvironmentVariable('GEMINI_PROXY_URL', ($workerUrl + '/gemini'))
        }
        Write-Host "==> Worker URL captured for dart-define (value not printed)" -ForegroundColor Cyan
      }
    } else {
      Write-Host "==> wrangler deploy skipped/failed (login: npx wrangler login). Flutter will use Supabase gemini-proxy." -ForegroundColor Yellow
    }
  } catch {
    Write-Host "==> wrangler deploy skipped." -ForegroundColor Yellow
  } finally {
    Pop-Location
  }
}

# Web bundle is public — LLM keys stay on Worker / Supabase, not in main.dart.js.
$webSkipSecrets = @('GEMINI_API_KEY', 'GROQ_API_KEY')
$defines = @()
$presentDefines = @()
foreach ($name in $defineNames) {
  if ($webSkipSecrets -contains $name) { continue }
  $val = [Environment]::GetEnvironmentVariable($name)
  if (-not [string]::IsNullOrWhiteSpace($val)) {
    $defines += "--dart-define=$name=$val"
    $presentDefines += $name
  }
}
if ($presentDefines.Count -gt 0) {
  Write-Host ("==> dart-defines from env: " + ($presentDefines -join ', ')) -ForegroundColor Cyan
}

# Supabase Edge Function (ücretsiz; login veya SUPABASE_ACCESS_TOKEN gerekir).
# Yalnız GEMINI_API_KEY gönderilir; değer yazdırılmaz. JWT kapalı (misafir tarama).
Write-Host "==> supabase functions deploy gemini-proxy (secret value hidden)" -ForegroundColor Cyan
function Get-DotEnvValue([string]$path, [string]$name) {
  if (-not (Test-Path $path)) { return $null }
  foreach ($line in Get-Content -LiteralPath $path) {
    $t = $line.Trim()
    if ($t.StartsWith('#') -or -not $t.Contains('=')) { continue }
    $i = $t.IndexOf('=')
    if ($t.Substring(0, $i).Trim() -ne $name) { continue }
    return $t.Substring($i + 1).Trim().Trim('"').Trim("'")
  }
  return $null
}
$geminiKey = Get-DotEnvValue (Join-Path $PSScriptRoot '.env') 'GEMINI_API_KEY'
if ([string]::IsNullOrWhiteSpace($geminiKey)) {
  $geminiKey = Get-DotEnvValue (Join-Path $PSScriptRoot 'functions\.env') 'GEMINI_API_KEY'
}
$token = [Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN')
if ([string]::IsNullOrWhiteSpace($token)) {
  $token = Get-DotEnvValue (Join-Path $PSScriptRoot '.env') 'SUPABASE_ACCESS_TOKEN'
}
if (-not [string]::IsNullOrWhiteSpace($token)) {
  $env:SUPABASE_ACCESS_TOKEN = $token
}
try {
  if (-not [string]::IsNullOrWhiteSpace($geminiKey)) {
    $tmp = Join-Path $env:TEMP ('ec-gemini-' + [guid]::NewGuid().ToString('N') + '.env')
    Set-Content -LiteralPath $tmp -Value ('GEMINI_API_KEY=' + $geminiKey) -NoNewline
    try {
      npx --yes supabase secrets set --env-file $tmp --project-ref qycrkqwqrysypvqaipqn | Out-Null
    } finally {
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
  }
  npx --yes supabase functions deploy gemini-proxy --no-verify-jwt --project-ref qycrkqwqrysypvqaipqn
  if ($LASTEXITCODE -eq 0) {
    Write-Host "==> gemini-proxy Edge Function OK" -ForegroundColor Green
  } else {
    Write-Host "==> supabase functions deploy skipped (npx supabase login). Dashboard: Edge Functions → gemini-proxy → Secrets." -ForegroundColor Yellow
  }
} catch {
  Write-Host "==> supabase functions deploy skipped." -ForegroundColor Yellow
}

Write-Host "==> flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --no-tree-shake-icons" -ForegroundColor Cyan
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --no-tree-shake-icons @defines
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Statik sayfalar (Flutter build bazen alt klasorleri atlayabilir)
Write-Host "==> Sync static pages (bilgi-kutuphanesi, daha-fazlasi, fotografli-puzzle)" -ForegroundColor Cyan
$staticRoots = @(
  "web\bilgi-kutuphanesi",
  "web\daha-fazlasi",
  "web\fotografli-puzzle.html"
)
foreach ($src in $staticRoots) {
  if (Test-Path $src) {
    $rel = $src -replace '^web\\', ''
    $dest = Join-Path "build\web" $rel
    if (Test-Path $src -PathType Leaf) {
      $destDir = Split-Path $dest -Parent
      New-Item -ItemType Directory -Force -Path $destDir | Out-Null
      Copy-Item -Force $src $dest
    } else {
      New-Item -ItemType Directory -Force -Path $dest | Out-Null
      Copy-Item -Recurse -Force "$src\*" $dest
    }
  }
}

Write-Host "==> firebase deploy --only hosting --project engelsizclub-e5842" -ForegroundColor Cyan
firebase deploy --only hosting --project engelsizclub-e5842
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Deploy tamam. Sonraki adimlar:" -ForegroundColor Green
Write-Host "1) npx wrangler login + wrangler secret put GEMINI_API_KEY (Cloudflare /gemini)"
Write-Host "   veya npx supabase login + secrets set GEMINI_API_KEY + functions deploy gemini-proxy"
Write-Host "2) Live: https://www.engelsizclub.com  (Ctrl+F5)"
Write-Host "3) Supabase Auth Site URL: https://www.engelsizclub.com"
Write-Host "Detay: DEPLOY.md ve cloudflare/wrangler.toml"
