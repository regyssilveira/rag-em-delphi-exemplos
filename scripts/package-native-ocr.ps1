# Creates an unsigned development MSIX. Does not install or change certificate trust.
param([Parameter(Mandatory=$true)][string]$MakeAppxPath)
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
$taskOutput = Join-Path $examplesRoot 'bin/RagAssistant.msix'
& $taskTool pack /d $taskStage /p $taskOutput /o
if ($LASTEXITCODE -ne 0) { throw 'Empacotamento MSIX falhou.' }
Write-Output ('MSIX nao assinado: ' + $taskOutput)
Write-Output 'Assinatura e instalacao sao etapas separadas. Nao embuta o manifesto de identidade MSIX externa neste executavel.'