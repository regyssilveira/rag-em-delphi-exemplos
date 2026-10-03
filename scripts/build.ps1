# Compila a aplicacao Win32; nao instala dependencias nem chama modelos.
param([string]$CompilerPath, [switch]$RunFoundation)
$ErrorActionPreference = 'Stop'
$locationPushed = $false
try {
    $examplesRoot = Split-Path -Parent $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($CompilerPath)) {
        $compiler = Get-Command dcc32.exe -CommandType Application -ErrorAction SilentlyContinue
        if ($null -eq $compiler) {
            throw 'dcc32.exe nao encontrado. Use o terminal Delphi 13 configurado ou informe -CompilerPath com o caminho completo do compilador.'
        }
        $CompilerPath = $compiler.Source
    }
    $CompilerPath = (Resolve-Path -LiteralPath $CompilerPath).Path
    if (-not (Test-Path -LiteralPath $CompilerPath -PathType Leaf)) {
        throw 'O caminho do compilador deve indicar um arquivo executavel.'
    }
    $outputDirectory = Join-Path $examplesRoot 'bin'
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    Push-Location -LiteralPath $examplesRoot
    $locationPushed = $true
    $searchPath = (Join-Path $examplesRoot 'src') + ';' + (Join-Path $examplesRoot 'app') + ';' + (Join-Path $examplesRoot 'experimental/ocr')
    $projects = @('app/RagAssistant.dpr')
    if ($RunFoundation) { $projects += 'tests/FoundationTests.dpr' }
    foreach ($project in $projects) {
        & $CompilerPath '-B' ('-U' + $searchPath) ('-N0' + $outputDirectory) ('-E' + $outputDirectory) (Join-Path $examplesRoot $project)
        if ($LASTEXITCODE -ne 0) { throw "Compilacao falhou: $project. Nenhum programa sera iniciado." }
    }
    if ($RunFoundation) {
        & (Join-Path $outputDirectory 'FoundationTests.exe') (Join-Path $examplesRoot 'data/corpus')
        if ($LASTEXITCODE -ne 0) { throw 'A verificacao da fundacao falhou.' }
    }
    Write-Output ('Aplicacao compilada: ' + (Join-Path $outputDirectory 'RagAssistant.exe'))
    Write-Output 'Configure os modelos e as dependencias dos formatos antes de importar e consultar, conforme o README.'
} catch {
    [Console]::Error.WriteLine('Construcao nao concluida: ' + $_.Exception.Message)
    if ($locationPushed) { Pop-Location }
    exit 1
}
if ($locationPushed) { Pop-Location }
exit 0
