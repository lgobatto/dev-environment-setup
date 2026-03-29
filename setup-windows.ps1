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
    # Full setup with 1Password:
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\setup-windows.ps1 -Install1Password

    # Only configure WSL2 (no apps):
    .\setup-windows.ps1 -SkipApps
#>

param(
    [switch]$Install1Password,
    [switch]$SkipApps,
    [switch]$SkipWSL
)

# ─── Output helpers ──────────────────────────────────────────────────────────
function Write-Step { param($msg) Write-Host "`n  ▶ $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "    ✔ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "    ⚠ $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "    ✖ $msg" -ForegroundColor Red }

Write-Host @"

  ╔══════════════════════════════════════════════════════╗
  ║        Windows Dev Environment Setup               ║
  ║        WSL2 + Ubuntu 24.04 + Apps via winget       ║
  ╚══════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ─── 1. Detectar hardware e calcular alocação ideal para .wslconfig ─────────
$totalRAMBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
$totalRAM      = [math]::Round($totalRAMBytes / 1GB)
$totalCPU      = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors

# ── Fórmula escalonada de RAM ────────────────────────────────────────────────
# Deixa RAM suficiente para Windows + apps (VS Code, Cursor, Chrome, etc.)
# Escala com o tamanho da máquina — não penaliza máquinas menores
$allocRAM = switch ($true) {
    ($totalRAM -le 8)  { [math]::Max(3, [math]::Round($totalRAM * 0.38)) }  # ≤8GB  → 3GB WSL
    ($totalRAM -le 16) { [math]::Round($totalRAM * 0.40) }                  # 16GB  → 6GB WSL
    ($totalRAM -le 32) { [math]::Round($totalRAM * 0.44) }                  # 32GB  → 14GB WSL
    ($totalRAM -le 64) { [math]::Round($totalRAM * 0.40) }                  # 64GB  → 26GB WSL
    default            { [math]::Min([math]::Round($totalRAM * 0.30), 32) } # >64GB → máx 32GB WSL
}

# ── Fórmula escalonada de CPUs ───────────────────────────────────────────────
# Metade dos cores lógicos, mín 4, máx 12 (acima disso raramente é útil para dev)
$allocCPU = [math]::Max([math]::Min([math]::Round($totalCPU / 2), 12), 4)

# ── Windows Pagefile como referência de swap ─────────────────────────────────
# WSL2 não precisa de swap quando tem RAM suficiente — elimina I/O desnecessário
$swapLine = if ($totalRAM -le 8) { "swap=2GB" } else { "swap=0" }

Write-Host "  Hardware detectado:" -ForegroundColor DarkGray
Write-Host "    RAM:  ${totalRAM}GB total  →  ${allocRAM}GB para WSL2 ($(100*$allocRAM/$totalRAM -as [int])%)" -ForegroundColor DarkGray
Write-Host "    CPUs: ${totalCPU} lógicas  →  ${allocCPU} para WSL2" -ForegroundColor DarkGray
Write-Host ""

# ─── 2. Instalar / atualizar WSL2 ────────────────────────────────────────────
if (-not $SkipWSL) {
    Write-Step "Configurando WSL2..."

    # Verifica se WSL está disponível
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    if ($null -eq $wslFeature -or $wslFeature.State -ne "Enabled") {
        Write-Warn "Habilitando WSL2 (requer reinicialização)..."
        wsl --install --no-distribution 2>&1 | Out-Null
        Write-Warn "Reinicie o Windows e execute este script novamente para continuar."
        exit 0
    }
    Write-OK "WSL2 habilitado"

    # Atualizar WSL para versão mais recente
    Write-Warn "Atualizando WSL para última versão..."
    wsl --update 2>&1 | Out-Null
    Write-OK "WSL atualizado"

    # Verificar se Ubuntu 24.04 está instalado
    $installedDistros = wsl --list --quiet 2>$null
    $hasUbuntu24 = $installedDistros | Where-Object { $_ -match "Ubuntu-24.04" }

    if (-not $hasUbuntu24) {
        Write-Warn "Instalando Ubuntu 24.04 LTS..."
        wsl --install -d Ubuntu-24.04
        Write-OK "Ubuntu 24.04 instalado"
        Write-Warn "Finalize a configuração inicial do Ubuntu (defina usuário/senha) e execute este script novamente."
        exit 0
    } else {
        Write-OK "Ubuntu 24.04 já instalado"
    }

    # Definir Ubuntu 24.04 como padrão
    wsl --set-default Ubuntu-24.04 2>&1 | Out-Null
    Write-OK "Ubuntu 24.04 definido como distro padrão"
}

# ─── 3. Escrever .wslconfig ──────────────────────────────────────────────────
Write-Step "Configurando .wslconfig (~/.wslconfig)..."

$wslConfigPath = "$env:USERPROFILE\.wslconfig"
$wslConfigContent = @"
# Gerado automaticamente por setup-windows.ps1
# Máquina: ${totalRAM}GB RAM | ${totalCPU} CPUs lógicas
# Gerado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm')

[wsl2]
# RAM: ${allocRAM}GB de ${totalRAM}GB disponíveis ($(100*$allocRAM/$totalRAM -as [int])%)
memory=${allocRAM}GB

# CPUs: ${allocCPU} de ${totalCPU} lógicas
processors=${allocCPU}

# Swap: desabilitado quando RAM >= 16GB (evita I/O desnecessário)
$swapLine

# Fundamental para Lando proxy funcionar corretamente
localhostForwarding=true

# Rede espelhada — melhora resolução DNS e reduz latência do proxy
# Requer WSL >= 2.2.0; remova esta linha se o WSL não iniciar
networkingMode=mirrored

[experimental]
# Libera memória cached gradualmente de volta ao Windows
autoMemoryReclaim=gradual
"@

Set-Content -Path $wslConfigPath -Value $wslConfigContent -Encoding UTF8
Write-OK ".wslconfig escrito: ${allocRAM}GB RAM | ${allocCPU} CPUs | swap=$($totalRAM -le 8 ? '2GB' : 'off')"

# ─── 4. Aplicar .wslconfig ───────────────────────────────────────────────────
Write-Step "Aplicando nova configuração WSL..."
wsl --shutdown 2>&1 | Out-Null
Start-Sleep -Seconds 3
Write-OK "WSL reiniciado com novos recursos"

# ─── 5. Instalar apps Windows via winget ─────────────────────────────────────
if (-not $SkipApps) {
    Write-Step "Instalando aplicações Windows via winget..."

    # Apps essenciais
    $apps = [ordered]@{
        "Microsoft.WindowsTerminal"  = "Windows Terminal"
        "Microsoft.VisualStudioCode" = "VS Code"
        "Anysphere.Cursor"           = "Cursor"
        "Google.Chrome"              = "Google Chrome"
        "GitHub.GitHubDesktop"       = "GitHub Desktop"
        "Postman.Postman"            = "Postman"
        "DBngin.DBngin"              = "DBngin (DB GUI)"
    }

    # 1Password opcional
    if ($Install1Password) {
        $apps["AgileBits.1Password"]     = "1Password"
        $apps["AgileBits.1Password.CLI"] = "1Password CLI"
    }

    foreach ($id in $apps.Keys) {
        $name = $apps[$id]
        $checkResult = winget list --id $id --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0 -and $checkResult -match [regex]::Escape($id)) {
            Write-OK "$name já instalado"
        } else {
            Write-Warn "Instalando $name..."
            $result = winget install --id $id `
                --accept-source-agreements `
                --accept-package-agreements `
                --silent 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-OK "$name instalado"
            } else {
                Write-Fail "$name falhou — instale manualmente de https://winget.run/$id"
            }
        }
    }

    # ─── Extensões VS Code para WSL ──────────────────────────────────────────
    Write-Step "Instalando extensões VS Code para WSL..."
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

# Copiar o setup-wsl.sh para dentro do WSL e executar
$thisDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$setupWsl  = Join-Path $thisDir "setup-wsl.sh"
$wslTarget = "/tmp/setup-wsl.sh"

if (Test-Path $setupWsl) {
    # Converter path Windows para WSL
    $wslPath = wsl wslpath -u "$setupWsl"
    wsl -d Ubuntu-24.04 -- bash -c "cp '$wslPath' $wslTarget && chmod +x $wslTarget && bash $wslTarget"
} else {
    Write-Warn "setup-wsl.sh não encontrado ao lado deste script."
    Write-Warn "Execute manualmente no Ubuntu 24.04:"
    Write-Host @"

    wsl -d Ubuntu-24.04
    curl -fsSL https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/setup-wsl.sh | bash

"@ -ForegroundColor Yellow
}

# ─── 7. Instruções finais ─────────────────────────────────────────────────────
Write-Host @"

  ╔══════════════════════════════════════════════════════╗
  ║                 Setup Concluído!                   ║
  ╚══════════════════════════════════════════════════════╝

  O que foi configurado:
    ✔  WSL2 + Ubuntu 24.04 LTS
    ✔  .wslconfig (${allocRAM}GB RAM, ${allocCPU} CPUs, networkingMode=mirrored)
    ✔  Apps Windows via winget
    ✔  Ambiente WSL2 (Node, PHP, Docker Engine, Lando, Claude Code, Zsh)

  Próximos passos:
    1. Abra o Ubuntu 24.04 pelo Windows Terminal
    2. Configure seus dados Git:
         git config --global user.name "Seu Nome"
         git config --global user.email "seu@email.com"
    3. Autentique o GitHub CLI:
         gh auth login
    4. Clone seus projetos:
         cd ~/projects
         git clone git@github.com:BrisaBR/brisausa.git --recurse-submodules
    5. Abra no VS Code via WSL:
         cd ~/projects/brisausa && code .
    6. Inicie o Lando:
         lando start

"@ -ForegroundColor Green

if ($Install1Password) {
    Write-Host @"
  1Password SSH Agent:
    1. Abra 1Password > Settings > Developer
    2. Ative "SSH Agent"
    3. Ative "Integrate with WSL"
    4. No terminal WSL, edite ~/.zshrc e descomente:
         export SSH_AUTH_SOCK=...

"@ -ForegroundColor Cyan
}
