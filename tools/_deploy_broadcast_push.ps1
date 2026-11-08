$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

function Import-DotEnvFile([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return }
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

Import-DotEnvFile (Join-Path (Get-Location) '.env')
Import-DotEnvFile (Join-Path (Get-Location) '.env.local')
Write-Host '==> supabase functions deploy broadcast-push'
npx --yes supabase functions deploy broadcast-push --no-verify-jwt --project-ref qycrkqwqrysypvqaipqn
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host '==> broadcast-push OK'
