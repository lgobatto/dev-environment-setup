#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Bootstrap launcher - compativel com PowerShell 5.1+
    Instala o PowerShell 7 se necessario e delega para setup-windows.ps1

.EXAMPLE
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\install.ps1
    .\install.ps1 -Install1Password
#>

param(
    [switch]$Install1Password,
    [switch]$SkipApps,
    [switch]$SkipWSL
)

Write-Host ""
Write-Host "  Dev Environment Setup" -ForegroundColor Cyan
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
Write-Host ""

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "  PowerShell 5.1 detectado. Instalando PowerShell 7..." -ForegroundColor Yellow

    winget install --id Microsoft.PowerShell `
        --accept-source-agreements `
        --accept-package-agreements `
        --silent

    Write-Host ""
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  PowerShell 7 instalado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "  Falha ao instalar via winget. Instale manualmente:" -ForegroundColor Red
        Write-Host "  https://github.com/PowerShell/PowerShell/releases/latest" -ForegroundColor Cyan
        exit 1
    }

    Write-Host ""
    Write-Host "  Reabra o terminal e execute:" -ForegroundColor Yellow
    Write-Host ""

    $scriptPath = $MyInvocation.MyCommand.Path
    $args_str   = ""
    if ($Install1Password) { $args_str += " -Install1Password" }
    if ($SkipApps)         { $args_str += " -SkipApps" }
    if ($SkipWSL)          { $args_str += " -SkipWSL" }

    Write-Host "    pwsh -ExecutionPolicy Bypass -File ""$scriptPath""$args_str" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

Write-Host "  PowerShell 7+ OK. Iniciando setup..." -ForegroundColor Green
Write-Host ""

# Localizar setup-windows.ps1 — pode estar ao lado deste script (clone local)
# ou precisar ser baixado (execucao via irm | iex ou arquivo isolado)
$setup = Join-Path $PSScriptRoot "setup-windows.ps1"

if (-not (Test-Path $setup)) {
    $repoUrl  = "https://github.com/lgobatto/dev-environment-setup.git"
    $repoDir  = "$env:USERPROFILE\dev-environment-setup"

    Write-Host "  setup-windows.ps1 nao encontrado localmente." -ForegroundColor Yellow
    Write-Host "  Clonando repositorio em: $repoDir" -ForegroundColor Cyan
    Write-Host ""

    if (Test-Path $repoDir) {
        Write-Host "  Atualizando repositorio existente..." -ForegroundColor DarkGray
        git -C $repoDir pull --quiet
    } else {
        git clone --depth=1 $repoUrl $repoDir
    }

    $setup = Join-Path $repoDir "setup-windows.ps1"

    if (-not (Test-Path $setup)) {
        Write-Host "  ERRO: nao foi possivel obter setup-windows.ps1" -ForegroundColor Red
        Write-Host "  Clone manualmente: git clone $repoUrl" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "  Repositorio pronto." -ForegroundColor Green
    Write-Host ""
}

$passArgs = @{}
if ($Install1Password) { $passArgs["Install1Password"] = $true }
if ($SkipApps)         { $passArgs["SkipApps"]         = $true }
if ($SkipWSL)          { $passArgs["SkipWSL"]           = $true }

& $setup @passArgs
