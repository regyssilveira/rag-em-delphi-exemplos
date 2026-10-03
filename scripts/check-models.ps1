# Diagnostico local; nao instala, atualiza ou gera respostas.
param([ValidateRange(1,60)][int]$TimeoutSeconds = 10)
$ErrorActionPreference = 'Stop'
try {
    $examplesRoot = Split-Path -Parent $PSScriptRoot
    $locks = @('embeddings.lock.json', 'generation.lock.json')
    $models = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec $TimeoutSeconds
    foreach ($lockName in $locks) {
        $configuration = Get-Content -LiteralPath (Join-Path $examplesRoot $lockName) -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([string]::IsNullOrWhiteSpace($configuration.model) -or $configuration.digest -notmatch '^[0-9a-fA-F]{64}$') {
            throw "Identidade invalida no arquivo $lockName."
        }
        $matches = @($models.models | Where-Object { $_.name -ceq $configuration.model })
        if ($matches.Count -eq 0) {
            throw "Modelo ausente: $($configuration.model). Prepare-o conforme o livro e repita a verificacao."
        }
        if ($matches.Count -ne 1 -or $matches[0].digest -cne $configuration.digest) {
            throw "Identidade divergente: $($configuration.model). Nao reutilize a base nem altere o lock para esconder a diferenca."
        }
        Write-Output "OK: $($configuration.model) corresponde ao digest registrado."
    }
    Write-Output 'Configuracao local identificada. Ainda confira versao do runtime, recursos da maquina e respostas dos exercicios.'
    exit 0
} catch {
    [Console]::Error.WriteLine('Verificacao nao concluida: ' + $_.Exception.Message)
    exit 1
}
