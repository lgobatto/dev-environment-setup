#Requires -RunAsAdministrator
#Requires -Version 7.0
<#
.SYNOPSIS
    Windows Development Environment Setup (requer PowerShell 7+)
    Use install.ps1 para executar — ele garante a versao correta.

.DESCRIPTION
    Idempotent — seguro para re-executar.
    Windows: VS Code, Cursor, Chrome, Windows Terminal, 1Password (opcional)
    WSL2:    Node, PHP, Composer, Docker Engine, Lando, Claude Code, Git, Zsh
#>

param(
    [switch]$Install1Password,
    [switch]$SkipApps,
    [switch]$SkipWSL
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding            = [System.Text.Encoding]::UTF8

function Write-Step { param($msg) Write-Host "`n  >> $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "     OK  $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "     !!  $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "     XX  $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "  +------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   Windows Dev Environment Setup                     |" -ForegroundColor Cyan
Write-Host "  |   WSL2 + Ubuntu 24.04 + Apps via winget             |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# ── 1. Detectar hardware ──────────────────────────────────────────────────────
$totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$totalCPU = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors

$allocRAM = switch ($true) {
    ($totalRAM -le 8)  { [math]::Max(3, [math]::Round($totalRAM * 0.38)) }
    ($totalRAM -le 16) { [math]::Round($totalRAM * 0.40) }
    ($totalRAM -le 32) { [math]::Round($totalRAM * 0.44) }
    ($totalRAM -le 64) { [math]::Round($totalRAM * 0.40) }
    default            { [math]::Min([math]::Round($totalRAM * 0.30), 32) }
}
$allocCPU  = [math]::Max([math]::Min([math]::Round($totalCPU / 2), 12), 4)
$swapLine  = if ($totalRAM -le 8) { "swap=2GB" } else { "swap=0" }
$swapLabel = if ($totalRAM -le 8) { "2GB" } else { "off" }
$pctRAM    = [math]::Round(100 * $allocRAM / $totalRAM)

Write-Host "  Hardware detectado:" -ForegroundColor DarkGray
Write-Host "    RAM:  ${totalRAM}GB  ->  ${allocRAM}GB para WSL2 (${pctRAM}%)" -ForegroundColor DarkGray
Write-Host "    CPUs: ${totalCPU} logicas  ->  ${allocCPU} para WSL2" -ForegroundColor DarkGray
Write-Host ""

# ── 2. WSL2 + Ubuntu 24.04 ────────────────────────────────────────────────────
if (-not $SkipWSL) {
    Write-Step "Configurando WSL2..."

    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    if ($null -eq $wslFeature -or $wslFeature.State -ne "Enabled") {
        Write-Warn "Habilitando WSL2 (requer reinicializacao)..."
        wsl --install --no-distribution 2>&1 | Out-Null
        Write-Warn "Reinicie o Windows e execute novamente."
        exit 0
    }
    Write-OK "WSL2 habilitado"

    wsl --update 2>&1 | Out-Null
    Write-OK "WSL atualizado"

    # wsl --list retorna UTF-16 com null bytes entre chars — strip necessario
    $distros = (wsl --list --quiet 2>&1) -replace "`0", "" -join " "
    if ($distros -notmatch "Ubuntu-24\.04") {
        Write-Warn "Instalando Ubuntu 24.04 LTS..."
        wsl --install -d Ubuntu-24.04
        Write-Warn "Configure usuario/senha no Ubuntu e execute novamente."
        exit 0
    }
    Write-OK "Ubuntu 24.04 presente"

    wsl --set-default Ubuntu-24.04 2>&1 | Out-Null
    Write-OK "Ubuntu 24.04 definido como padrao"
}

# ── 3. .wslconfig ─────────────────────────────────────────────────────────────
Write-Step "Configurando .wslconfig..."

$wslConfigPath = "$env:USERPROFILE\.wslconfig"
$generatedAt   = Get-Date -Format 'yyyy-MM-dd HH:mm'

# Construir conteudo sem heredoc para evitar ambiguidades de encoding
$lines = @(
    "# Gerado por setup-windows.ps1 em ${generatedAt}",
    "# Maquina: ${totalRAM}GB RAM | ${totalCPU} CPUs logicas",
    "",
    "[wsl2]",
    "# RAM: ${allocRAM}GB de ${totalRAM}GB (${pctRAM}%)",
    "memory=${allocRAM}GB",
    "",
    "# CPUs: ${allocCPU} de ${totalCPU} logicas",
    "processors=${allocCPU}",
    "",
    "# Swap",
    $swapLine,
    "",
    "# Necessario para o proxy do Lando funcionar",
    "localhostForwarding=true",
    "",
    "# Melhora resolucao DNS e latencia do proxy (requer WSL >= 2.2.0)",
    "networkingMode=mirrored",
    "",
    "[experimental]",
    "autoMemoryReclaim=gradual"
)
Set-Content -Path $wslConfigPath -Value $lines -Encoding UTF8

Write-OK ".wslconfig: ${allocRAM}GB RAM | ${allocCPU} CPUs | swap=${swapLabel}"

wsl --shutdown 2>&1 | Out-Null
Start-Sleep -Seconds 2
Write-OK "WSL reiniciado com nova configuracao"

# ── 4. Apps Windows via winget ────────────────────────────────────────────────
if (-not $SkipApps) {
    Write-Step "Instalando apps Windows via winget..."

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
        $name   = $apps[$id]
        $listed = (winget list --id $id --accept-source-agreements 2>&1) | Out-String
        if ($LASTEXITCODE -eq 0 -and $listed -match [regex]::Escape($id)) {
            Write-OK "$name ja instalado"
        } else {
            Write-Warn "Instalando $name..."
            winget install --id $id --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-OK "$name instalado"
            } else {
                Write-Fail "$name falhou -- https://winget.run/$id"
            }
        }
    }

    Write-Step "Instalando extensoes VS Code para WSL..."
    foreach ($ext in @("ms-vscode-remote.remote-wsl", "ms-vscode-remote.vscode-remote-extensionpack", "ms-vscode.remote-explorer")) {
        code --install-extension $ext --force 2>&1 | Out-Null
        Write-OK $ext
    }
}

# ── 5. Bootstrap WSL ──────────────────────────────────────────────────────────
Write-Step "Iniciando setup do WSL2..."

# Montar env vars para passar ao script bash
$wslEnv = "GIT_NAME='$env:USERNAME'"
if ($Install1Password) { $wslEnv = "INSTALL_1PASSWORD=1 $wslEnv" }

$setupWsl = Join-Path $PSScriptRoot "setup-wsl.sh"
if (Test-Path $setupWsl) {
    $wslPath = (wsl wslpath -u "$setupWsl").Trim()
    wsl -d Ubuntu-24.04 -- bash -c "cp '$wslPath' /tmp/setup-wsl.sh && chmod +x /tmp/setup-wsl.sh && env $wslEnv bash /tmp/setup-wsl.sh"
} else {
    Write-Warn "setup-wsl.sh nao encontrado. Execute manualmente:"
    Write-Host "  wsl -d Ubuntu-24.04" -ForegroundColor Cyan
    Write-Host "  INSTALL_1PASSWORD=1 curl -fsSL https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/setup-wsl.sh | bash" -ForegroundColor Cyan
}

# ── 6. Conclusao ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  +------------------------------------------------------+" -ForegroundColor Green
Write-Host "  |              Setup Concluido!                       |" -ForegroundColor Green
Write-Host "  +------------------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  OK  PowerShell 7" -ForegroundColor Green
Write-Host "  OK  WSL2 + Ubuntu 24.04" -ForegroundColor Green
Write-Host "  OK  .wslconfig (${allocRAM}GB RAM, ${allocCPU} CPUs)" -ForegroundColor Green
Write-Host "  OK  Apps Windows via winget" -ForegroundColor Green
Write-Host "  OK  WSL2: Node, PHP, Docker Engine, Lando, Claude Code" -ForegroundColor Green
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
    Write-Host "    1Password > Settings > Developer > SSH Agent + Integrate with WSL" -ForegroundColor White
    Write-Host "    Depois edite ~/.zshrc e descomente SSH_AUTH_SOCK" -ForegroundColor White
    Write-Host ""
}
