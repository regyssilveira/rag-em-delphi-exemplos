param(
    [string]$Model,
    [ValidateRange(15000,60000)][int]$IntervalMilliseconds = 15000
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$originalKey = $env:GEMINI_API_KEY
$originalProvider = $env:RAG_GENERATION_PROVIDER
$originalModel = $env:RAG_GENERATION_MODEL
$originalDelay = $env:RAG_EVALUATION_DELAY_MS
$hadFailures = $false
try {
    if ([string]::IsNullOrWhiteSpace($env:GEMINI_API_KEY)) {
        $env:GEMINI_API_KEY = [Environment]::GetEnvironmentVariable('GEMINI_API_KEY','User')
    }
    if ([string]::IsNullOrWhiteSpace($env:GEMINI_API_KEY)) {
        throw 'Configure GEMINI_API_KEY nas variáveis de usuário do Windows. Não envie a chave no chat.'
    }
    if ([string]::IsNullOrWhiteSpace($Model)) {
        $Model = [Environment]::GetEnvironmentVariable('RAG_GENERATION_MODEL','User')
    }
    if ([string]::IsNullOrWhiteSpace($Model)) { throw 'Informe -Model com um identificador disponível na conta.' }
    $env:RAG_GENERATION_PROVIDER = 'gemini'
    $env:RAG_GENERATION_MODEL = $Model
    $env:RAG_EVALUATION_DELAY_MS = [string]$IntervalMilliseconds
    $compiler = Get-Command dcc32.exe -ErrorAction SilentlyContinue
    if ($compiler) { $compilerPath = $compiler.Source }
    else { $compilerPath = Join-Path ${env:ProgramFiles(x86)} 'Embarcadero/Studio/37.0/bin/dcc32.exe' }
    if (-not (Test-Path -LiteralPath $compilerPath)) { throw 'Delphi 13: informe dcc32.exe no PATH.' }
    $runRoot = Join-Path $projectRoot ('bin/remote-evaluation-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $null = New-Item -ItemType Directory -Path $runRoot
    foreach ($program in @('ExtendedAnswers','IntegratedDemo')) {
        $sourcePath = Join-Path $projectRoot "tests/$program.dpr"
        & $compilerPath '-B' "-U$projectRoot/src" "-N0$runRoot" "-E$runRoot" $sourcePath
        if ($LASTEXITCODE -ne 0) { throw "Compilação falhou: $program" }
        $questionFile = if ($program -eq 'ExtendedAnswers') { 'questions-extended.json' } else { 'questions.json' }
        $result = & (Join-Path $runRoot "$program.exe") (Join-Path $projectRoot 'data/corpus') (Join-Path $projectRoot "data/evaluation/$questionFile")
        $evaluationExitCode = $LASTEXITCODE
        $result | Set-Content -LiteralPath (Join-Path $runRoot "$program-output.txt") -Encoding UTF8
        $result | Write-Output
        if ($result -match 'TRANSPORT_ABORT') { throw 'Falha de transporte: execução interrompida. Consulte os artefatos sanitizados da execução.' }
        if ($evaluationExitCode -ne 0) { $hadFailures = $true; Write-Warning "Casos reprovados em $program; a configuração não está aprovada." }
    }
    Write-Output "Resultados: $runRoot"
    Write-Output 'Resultado automático exige leitura semântica conforme tests/SEMANTIC_REVIEW.md.'
    if ($hadFailures) { throw 'Avaliação reprovada; resultados foram preservados.' }
}
finally {
    $env:GEMINI_API_KEY = $originalKey
    $env:RAG_GENERATION_PROVIDER = $originalProvider
    $env:RAG_GENERATION_MODEL = $originalModel
    $env:RAG_EVALUATION_DELAY_MS = $originalDelay
}
