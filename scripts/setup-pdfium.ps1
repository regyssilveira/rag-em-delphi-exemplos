$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$lock = Get-Content -LiteralPath (Join-Path $projectRoot 'pdfium.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$runtimeDir = Join-Path $projectRoot 'bin/pdfium'
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
$archivePath = Join-Path $runtimeDir 'pdfium-win-x86.tgz'
if (-not (Test-Path -LiteralPath $archivePath)) {
    Invoke-WebRequest -Uri $lock.url -OutFile $archivePath
}
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $lock.archiveSha256) {
    throw 'Hash do pacote PDFium não corresponde à versão fixada.'
}
$entries = @(tar -tf $archivePath)
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível listar o pacote.' }
if ($entries | Where-Object { $_.StartsWith('/') -or $_.Contains(':') -or $_.Contains([char]92) -or ($_.Split('/') -contains '..') }) {
    throw 'Caminho inesperado dentro do pacote.'
}
tar -xf $archivePath -C $runtimeDir
if ($LASTEXITCODE -ne 0) { throw 'Extração PDFium falhou.' }
$dllPath = Join-Path $runtimeDir 'bin/pdfium.dll'
if ((Get-FileHash -LiteralPath $dllPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $lock.dllSha256) {
    throw 'Hash da DLL não corresponde à versão fixada.'
}
Write-Host "PDFium Win32 preparado: $dllPath"
Write-Host 'Preserve LICENSE e licenses/ do pacote em qualquer redistribuição.'
