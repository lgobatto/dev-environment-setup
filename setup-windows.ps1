#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows Development Environment Setup
    Configures WSL2, .wslconfig, and installs Windows apps via winget.

.DESCRIPTION
    Idempotent — safe to re-run.
    What lives on Windows: VS Code, Cursor, Chrome, Windows Terminal, 1Password (optional)
    What lives on WSL2:    Node, PHP, Composer, Docker Engine, Lando, Claude Code, Git, Zsh

.PARAMETER Install1Password
    Include 1Password and 1Password CLI in Windows app installation.

.PARAMETER SkipApps
    Skip winget app installation (only configure WSL2 and .wslconfig).

.PARAMETER SkipWSL
    Skip WSL2 installation (only install Windows apps and .wslconfig).

.EXAMPLE
    # Full setup:
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\setup-windows.ps1 -Install1Password

    # Only configure WSL2 + .wslconfig:
    .\setup-windows.ps1 -SkipApps
#>

param(
    [switch]$Install1Password,
    [switch]$SkipApps,
    [switch]$SkipWSL
)

# ── Fix console encoding (suporta UTF-8 no PS5.1) ────────────────────────────
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding            = [System.Text.Encoding]::UTF8

# ── Output helpers (ASCII — compativel PS5.1 e PS7) ──────────────────────────
function Write-Step { param($msg) Write-Host "`n  >> $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "     OK  $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "     !!  $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "     XX  $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "  +----------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |      Windows Dev Environment Setup               |" -ForegroundColor Cyan
Write-Host "  |      WSL2 + Ubuntu 24.04 + Apps via winget       |" -ForegroundColor Cyan
Write-Host "  +----------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# ─── 0. Instalar / atualizar PowerShell 7 ────────────────────────────────────
Write-Step "Verificando versao do PowerShell..."

$psMajor = $PSVersionTable.PSVersion.Major
Write-Host "     PowerShell $($PSVersionTable.PSVersion) detectado" -ForegroundColor DarkGray

if ($psMajor -lt 7) {
    Write-Warn "PowerShell $psMajor detectado. Instalando PowerShell 7..."

    $psInstalled = winget list --id Microsoft.PowerShell --accept-source-agreements 2>&1
    if ($LASTEXITCODE -ne 0 -or $psInstalled -notmatch "Microsoft.PowerShell") {
        winget install --id Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
        Write-OK "PowerShell 7 instalado!"
    } else {
        winget upgrade --id Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
        Write-OK "PowerShell 7 atualizado!"
    }

    Write-Host ""
    Write-Host "  +----------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "  |  ACAO NECESSARIA: Reabra o PowerShell com PS7     |" -ForegroundColor Yellow
    Write-Host "  +----------------------------------------------------+" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Execute no novo terminal (como Administrador):" -ForegroundColor White
    Write-Host ""
    Write-Host "    pwsh -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -ForegroundColor Cyan
    if ($Install1Password) {
        Write-Host "    # ou com 1Password:" -ForegroundColor DarkGray
        Write-Host "    pwsh -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -Install1Password" -ForegroundColor Cyan
    }
    Write-Host ""
    exit 0
} else {
    Write-OK "PowerShell $($PSVersionTable.PSVersion) — OK, continuando..."
}

# ─── 1. Detectar hardware e calcular alocacao ideal para .wslconfig ──────────
$totalRAMBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
$totalRAM      = [math]::Round($totalRAMBytes / 1GB)
$totalCPU      = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors

# Formula escalonada: deixa RAM suficiente para Windows + apps
$allocRAM = switch ($true) {
    ($totalRAM -le 8)  { [math]::Max(3, [math]::Round($totalRAM * 0.38)) }  # <=8GB  -> 3GB WSL
    ($totalRAM -le 16) { [math]::Round($totalRAM * 0.40) }                  # 16GB   -> 6GB WSL
    ($totalRAM -le 32) { [math]::Round($totalRAM * 0.44) }                  # 32GB   -> 14GB WSL
    ($totalRAM -le 64) { [math]::Round($totalRAM * 0.40) }                  # 64GB   -> 26GB WSL
    default            { [math]::Min([math]::Round($totalRAM * 0.30), 32) } # >64GB  -> max 32GB WSL
}

# Metade dos cores logicos, min 4, max 12
$allocCPU = [math]::Max([math]::Min([math]::Round($totalCPU / 2), 12), 4)

# Swap: so habilita se RAM for muito limitada
if ($totalRAM -le 8) { $swapLine = "swap=2GB" } else { $swapLine = "swap=0" }
if ($totalRAM -le 8) { $swapLabel = "2GB" }     else { $swapLabel = "off" }

$pctRAM = [math]::Round(100 * $allocRAM / $totalRAM)

Write-Host "  Hardware detectado:" -ForegroundColor DarkGray
Write-Host "    RAM:  ${totalRAM}GB total  ->  ${allocRAM}GB para WSL2 (${pctRAM}%)" -ForegroundColor DarkGray
Write-Host "    CPUs: ${totalCPU} logicas  ->  ${allocCPU} para WSL2" -ForegroundColor DarkGray
Write-Host ""

# ─── 2. Instalar / atualizar WSL2 ────────────────────────────────────────────
if (-not $SkipWSL) {
    Write-Step "Configurando WSL2..."

    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    if ($null -eq $wslFeature -or $wslFeature.State -ne "Enabled") {
        Write-Warn "Habilitando WSL2 (requer reinicializacao)..."
        wsl --install --no-distribution 2>&1 | Out-Null
        Write-Warn "Reinicie o Windows e execute este script novamente."
        exit 0
    }
    Write-OK "WSL2 habilitado"

    Write-Warn "Atualizando WSL para ultima versao..."
    wsl --update 2>&1 | Out-Null
    Write-OK "WSL atualizado"

    $installedDistros = wsl --list --quiet 2>$null
    $hasUbuntu24 = $installedDistros | Where-Object { $_ -match "Ubuntu-24.04" }

    if (-not $hasUbuntu24) {
        Write-Warn "Instalando Ubuntu 24.04 LTS..."
        wsl --install -d Ubuntu-24.04
        Write-OK "Ubuntu 24.04 instalado"
        Write-Warn "Finalize a configuracao inicial (usuario/senha) e execute este script novamente."
        exit 0
    } else {
        Write-OK "Ubuntu 24.04 ja instalado"
    }

    wsl --set-default Ubuntu-24.04 2>&1 | Out-Null
    Write-OK "Ubuntu 24.04 definido como distro padrao"
}

# ─── 3. Escrever .wslconfig ──────────────────────────────────────────────────
Write-Step "Configurando .wslconfig..."

$wslConfigPath = "$env:USERPROFILE\.wslconfig"
$generatedAt   = Get-Date -Format 'yyyy-MM-dd HH:mm'

$wslConfigContent = @"
# Gerado automaticamente por setup-windows.ps1
# Maquina: ${totalRAM}GB RAM | ${totalCPU} CPUs logicas
# Gerado em: ${generatedAt}

[wsl2]
# RAM: ${allocRAM}GB de ${totalRAM}GB disponiveis (${pctRAM}%)
memory=${allocRAM}GB

# CPUs: ${allocCPU} de ${totalCPU} logicas
processors=${allocCPU}

# Swap: desabilitado quando RAM suficiente (evita I/O desnecessario)
${swapLine}

# Fundamental para Lando proxy funcionar corretamente
localhostForwarding=true

# Rede espelhada: melhora resolucao DNS e reduz latencia do proxy
# Requer WSL >= 2.2.0; remova esta linha se o WSL nao iniciar
networkingMode=mirrored

[experimental]
# Libera memoria cached gradualmente de volta ao Windows
autoMemoryReclaim=gradual
"@

Set-Content -Path $wslConfigPath -Value $wslConfigContent -Encoding UTF8
Write-OK ".wslconfig: ${allocRAM}GB RAM | ${allocCPU} CPUs | swap=${swapLabel}"

# ─── 4. Aplicar .wslconfig ───────────────────────────────────────────────────
Write-Step "Aplicando nova configuracao WSL..."
wsl --shutdown 2>&1 | Out-Null
Start-Sleep -Seconds 3
Write-OK "WSL reiniciado com novos recursos"

# ─── 5. Instalar apps Windows via winget ─────────────────────────────────────
if (-not $SkipApps) {
    Write-Step "Instalando aplicacoes Windows via winget..."

    $apps = [ordered]@{
        "Microsoft.PowerShell"       = "PowerShell 7"
        "Microsoft.WindowsTerminal"  = "Windows Terminal"
        "Microsoft.VisualStudioCode" = "VS Code"
        "Anysphere.Cursor"           = "Cursor"
        "Google.Chrome"              = "Google Chrome"
        "GitHub.GitHubDesktop"       = "GitHub Desktop"
        "Postman.Postman"            = "Postman"
    }

    if ($Install1Password) {
        $apps["AgileBits.1Password"]     = "1Password"
        $apps["AgileBits.1Password.CLI"] = "1Password CLI"
    }

    foreach ($id in $apps.Keys) {
        $name        = $apps[$id]
        $checkResult = winget list --id $id --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0 -and ($checkResult | Out-String) -match [regex]::Escape($id)) {
            Write-OK "$name ja instalado"
        } else {
            Write-Warn "Instalando $name..."
            winget install --id $id `
                --accept-source-agreements `
                --accept-package-agreements `
                --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-OK "$name instalado"
            } else {
                Write-Fail "$name falhou -- instale manualmente: https://winget.run/$id"
            }
        }
    }

    Write-Step "Instalando extensoes VS Code para WSL..."
    $vscodeExts = @(
        "ms-vscode-remote.remote-wsl",
        "ms-vscode-remote.vscode-remote-extensionpack",
        "ms-vscode.remote-explorer"
    )
    foreach ($ext in $vscodeExts) {
        code --install-extension $ext --force 2>&1 | Out-Null
        Write-OK $ext
    }
}

# ─── 6. Bootstrap WSL: rodar setup-wsl.sh ────────────────────────────────────
Write-Step "Iniciando setup do ambiente WSL2..."

$thisDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$setupWsl = Join-Path $thisDir "setup-wsl.sh"

if (Test-Path $setupWsl) {
    $wslPath = (wsl wslpath -u "$setupWsl").Trim()
    wsl -d Ubuntu-24.04 -- bash -c "cp '$wslPath' /tmp/setup-wsl.sh && chmod +x /tmp/setup-wsl.sh && bash /tmp/setup-wsl.sh"
} else {
    Write-Warn "setup-wsl.sh nao encontrado ao lado deste script."
    Write-Host ""
    Write-Host "  Execute manualmente no Ubuntu 24.04:" -ForegroundColor Yellow
    Write-Host "  wsl -d Ubuntu-24.04" -ForegroundColor Cyan
    Write-Host "  curl -fsSL https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/setup-wsl.sh | bash" -ForegroundColor Cyan
    Write-Host ""
}

# ─── 7. Instrucoes finais ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "  +----------------------------------------------------+" -ForegroundColor Green
Write-Host "  |              Setup Concluido!                     |" -ForegroundColor Green
Write-Host "  +----------------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  O que foi configurado:" -ForegroundColor White
Write-Host "     OK  PowerShell 7" -ForegroundColor Green
Write-Host "     OK  WSL2 + Ubuntu 24.04 LTS" -ForegroundColor Green
Write-Host "     OK  .wslconfig (${allocRAM}GB RAM, ${allocCPU} CPUs)" -ForegroundColor Green
Write-Host "     OK  Apps Windows via winget" -ForegroundColor Green
Write-Host "     OK  Ambiente WSL2 (Node, PHP, Docker Engine, Lando, Claude Code, Zsh)" -ForegroundColor Green
Write-Host ""
Write-Host "  Proximos passos:" -ForegroundColor White
Write-Host "    1. Abra o Ubuntu 24.04 pelo Windows Terminal" -ForegroundColor White
Write-Host "    2. git config --global user.name 'Seu Nome'" -ForegroundColor White
Write-Host "    3. git config --global user.email 'seu@email.com'" -ForegroundColor White
Write-Host "    4. gh auth login" -ForegroundColor White
Write-Host "    5. cd ~/projects && git clone git@github.com:BrisaBR/brisausa.git --recurse-submodules" -ForegroundColor White
Write-Host "    6. cd brisausa && lando start" -ForegroundColor White
Write-Host ""

if ($Install1Password) {
    Write-Host "  1Password SSH Agent:" -ForegroundColor Cyan
    Write-Host "    1. 1Password > Settings > Developer > Ative SSH Agent" -ForegroundColor White
    Write-Host "    2. Ative 'Integrate with WSL'" -ForegroundColor White
    Write-Host "    3. No terminal WSL, edite ~/.zshrc e descomente SSH_AUTH_SOCK" -ForegroundColor White
    Write-Host ""
}
