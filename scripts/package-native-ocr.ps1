# Creates an unsigned development MSIX. Does not install or change certificate trust.
param([Parameter(Mandatory=$true)][string]$MakeAppxPath, [switch]$IncludePdfium)
$ErrorActionPreference = 'Stop'
$examplesRoot = Split-Path -Parent $PSScriptRoot
$taskTool = (Resolve-Path -LiteralPath $MakeAppxPath).Path
$taskExe = Join-Path $examplesRoot 'bin/RagAssistant.exe'
if (-not (Test-Path -LiteralPath $taskExe -PathType Leaf)) { throw 'Compile primeiro com scripts/build.ps1.' }
$taskStage = Join-Path $examplesRoot ('bin/msix-stage-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskStage | Out-Null
Copy-Item -LiteralPath $taskExe -Destination $taskStage
Copy-Item -LiteralPath (Join-Path $examplesRoot 'app/msix/AppxManifest.xml') -Destination $taskStage
Copy-Item -LiteralPath (Join-Path $examplesRoot 'app/msix/Assets') -Destination $taskStage -Recurse
if ($IncludePdfium) {
    $taskPdfium = Join-Path $examplesRoot 'bin/pdfium'
    $taskLock = Get-Content -LiteralPath (Join-Path $examplesRoot 'pdfium.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $taskDll = Join-Path $taskPdfium 'bin/pdfium.dll'
    foreach ($taskRequired in @($taskDll, (Join-Path $taskPdfium 'LICENSE'), (Join-Path $taskPdfium 'licenses'))) {
        if (-not (Test-Path -LiteralPath $taskRequired)) { throw 'Prepare scripts/setup-pdfium.ps1 antes de incluir PDFium.' }
    }
    if ((Get-FileHash -LiteralPath $taskDll -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskLock.dllSha256) {
        throw 'PDFium difere da DLL Win32 fixada.'
    }
    $taskPdfStage = Join-Path $taskStage 'pdfium'
    New-Item -ItemType Directory -Path (Join-Path $taskPdfStage 'bin') -Force | Out-Null
    Copy-Item -LiteralPath $taskDll -Destination (Join-Path $taskPdfStage 'bin/pdfium.dll')
    Copy-Item -LiteralPath (Join-Path $taskPdfium 'LICENSE') -Destination $taskPdfStage
    Copy-Item -LiteralPath (Join-Path $taskPdfium 'licenses') -Destination $taskPdfStage -Recurse
}
$taskOutput = Join-Path $examplesRoot 'bin/RagAssistant.msix'
& $taskTool pack /d $taskStage /p $taskOutput /o
if ($LASTEXITCODE -ne 0) { throw 'Empacotamento MSIX falhou.' }
Write-Output ('MSIX nao assinado: ' + $taskOutput)
Write-Output 'Assinatura e instalacao sao etapas separadas. Nao embuta o manifesto de identidade MSIX externa neste executavel.'