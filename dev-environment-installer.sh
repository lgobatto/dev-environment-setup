#!/bin/bash

# =============================================================================
# 🚀 Instalador Interativo de Ambiente de Desenvolvimento
# =============================================================================
# Descrição: Script completo para configurar ambiente de desenvolvimento em distribuições Ubuntu-based
# Autor: Leonardo Gobatto (@lgobatto)
# Compatibilidade: Ubuntu, Zorin OS, Linux Mint, WSL
# Versão: 1.0.0
# =============================================================================

set -euo pipefail

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Configurações globais
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/tmp/dev-installer-$(date +%Y%m%d_%H%M%S).log"
readonly TEMP_DIR="/tmp/dev-installer-$$"

# Arrays para controle de instalação
declare -a INSTALLED_TOOLS=()
declare -a FAILED_TOOLS=()

# Variáveis de ambiente
IS_WSL=false
IS_UBUNTU_BASED=false
DISTRO_NAME=""
USER_HOME="$HOME"

# =============================================================================
# Funções de Utilidade
# =============================================================================

log() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
    INSTALLED_TOOLS+=("$1")
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    FAILED_TOOLS+=("$1")
}

title() {
    echo ""
    echo -e "${WHITE}============================================================${NC}"
    echo -e "${WHITE} $1${NC}"
    echo -e "${WHITE}============================================================${NC}"
    echo ""
}

section() {
    echo ""
    echo -e "${CYAN}📦 $1${NC}"
    echo "------------------------------------------------------------"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-}"
    
    while true; do
        if [[ -n "$default" ]]; then
            read -p "$prompt [y/N]: " answer
            answer=${answer:-$default}
        else
            read -p "$prompt [y/n]: " answer
        fi
        
        case ${answer,,} in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Por favor, responda com 'y' ou 'n'." ;;
        esac
    done
}

cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

# =============================================================================
# Detecção do Sistema
# =============================================================================

detect_system() {
    section "Detectando Sistema"
    
    # Detectar WSL
    if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        IS_WSL=true
        log "Ambiente WSL detectado"
    fi
    
    # Detectar distribuição
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_NAME="$NAME"
        
        case "${ID,,}" in
            ubuntu|zorin|linuxmint|pop|elementary|kubuntu|xubuntu|lubuntu)
                IS_UBUNTU_BASED=true
                success "Distribuição Ubuntu-based detectada: $DISTRO_NAME"
                ;;
            *)
                error "Distribuição não suportada: $DISTRO_NAME"
                echo "Este script foi projetado para distribuições baseadas em Ubuntu."
                exit 1
                ;;
        esac
    else
        error "Não foi possível detectar a distribuição"
        exit 1
    fi
    
    log "Sistema: $DISTRO_NAME"
    log "WSL: $([ "$IS_WSL" == "true" ] && echo "Sim" || echo "Não")"
    log "Usuário: $USER"
    log "Home: $USER_HOME"
}

# =============================================================================
# Funções de Instalação
# =============================================================================

install_basic_dependencies() {
    section "Instalando Dependências Básicas"
    
    log "Atualizando repositórios..."
    sudo apt update || { error "Falha ao atualizar repositórios"; return 1; }
    
    local basic_packages=(
        "curl" "wget" "git" "unzip" "software-properties-common"
        "apt-transport-https" "ca-certificates" "gnupg" "lsb-release"
        "build-essential" "fontconfig" "xclip" "tree" "htop"
    )
    
    log "Instalando pacotes básicos..."
    if sudo apt install -y "${basic_packages[@]}"; then
        success "Dependências básicas instaladas"
    else
        error "Falha ao instalar dependências básicas"
        return 1
    fi
}

install_vscode() {
    section "Visual Studio Code"
    
    if command -v code &>/dev/null; then
        warn "VS Code já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Visual Studio Code?"; then
        return 0
    fi
    
    log "Instalando Microsoft GPG key..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    
    log "Adicionando repositório do VS Code..."
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    
    log "Atualizando e instalando VS Code..."
    sudo apt update && sudo apt install -y code
    
    if command -v code &>/dev/null; then
        success "Visual Studio Code instalado"
    else
        error "Falha na instalação do VS Code"
        return 1
    fi
    
    rm -f packages.microsoft.gpg
}

install_volta_nodejs() {
    section "Volta + Node.js"
    
    if command -v volta &>/dev/null; then
        warn "Volta já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Volta (gerenciador de Node.js) + Node.js LTS?"; then
        return 0
    fi
    
    log "Instalando Volta..."
    if curl https://get.volta.sh | bash; then
        export VOLTA_HOME="$HOME/.volta"
        export PATH="$VOLTA_HOME/bin:$PATH"
        
        log "Instalando Node.js LTS..."
        volta install node
        
        success "Volta + Node.js instalados"
    else
        error "Falha na instalação do Volta"
        return 1
    fi
}

install_yarn() {
    section "Yarn"
    
    if command -v yarn &>/dev/null; then
        warn "Yarn já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Yarn (via Volta)?"; then
        return 0
    fi
    
    if command -v volta &>/dev/null; then
        volta install yarn
        success "Yarn instalado via Volta"
    else
        error "Volta não encontrado. Instale Volta primeiro."
        return 1
    fi
}

install_docker() {
    section "Docker"
    
    if command -v docker &>/dev/null; then
        warn "Docker já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Docker Engine?"; then
        return 0
    fi
    
    log "Removendo versões antigas do Docker..."
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    log "Instalando dependências..."
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    log "Adicionando Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    log "Adicionando repositório Docker..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    log "Instalando Docker..."
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log "Configurando Docker para uso sem sudo..."
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker "$USER"
    
    log "Iniciando serviços Docker..."
    sudo systemctl enable docker
    sudo systemctl start docker
    
    success "Docker instalado"
    warn "Será necessário fazer logout/login para usar Docker sem sudo"
}

install_php_composer() {
    section "PHP + Composer"
    
    if ! ask_yes_no "Instalar PHP 8.3 CLI + Composer?"; then
        return 0
    fi
    
    log "Adicionando repositório ondrej/php..."
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update
    
    log "Instalando PHP 8.3 CLI..."
    sudo apt install -y php8.3-cli php8.3-common php8.3-curl php8.3-zip php8.3-gd php8.3-mysql php8.3-xml php8.3-mbstring php8.3-json php8.3-intl php8.3-bcmath
    
    if ! command -v composer &>/dev/null; then
        log "Instalando Composer..."
        curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
    fi
    
    success "PHP 8.3 + Composer instalados"
}

install_aws_cli() {
    section "AWS CLI"
    
    if command -v aws &>/dev/null; then
        warn "AWS CLI já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar AWS CLI v2?"; then
        return 0
    fi
    
    log "Baixando AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    
    rm -rf aws awscliv2.zip
    success "AWS CLI v2 instalado"
}

install_kubectl_tools() {
    section "Kubernetes Tools"
    
    if ! ask_yes_no "Instalar kubectl + kubectx/kubens?"; then
        return 0
    fi
    
    # kubectl
    log "Instalando kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    # kubectx/kubens
    log "Instalando kubectx/kubens..."
    sudo apt install -y kubectx
    
    success "Kubernetes tools instalados"
}

install_python_tools() {
    section "Python Tools"
    
    if ! ask_yes_no "Instalar Python3 + pip3?"; then
        return 0
    fi
    
    log "Instalando Python3 e pip3..."
    sudo apt install -y python3 python3-pip python3-dev
    
    success "Python3 + pip3 instalados"
}

install_lando() {
    section "Lando"
    
    if command -v lando &>/dev/null; then
        warn "Lando já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Lando (requer Docker)?"; then
        return 0
    fi
    
    log "Instalando Lando..."
    if /bin/bash -c "$(curl -fsSL https://get.lando.dev/setup-lando.sh)"; then
        success "Lando instalado"
    else
        error "Falha na instalação do Lando"
        return 1
    fi
}

install_1password_cli() {
    section "1Password CLI"
    
    if command -v op &>/dev/null; then
        warn "1Password CLI já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar 1Password CLI?"; then
        return 0
    fi
    
    log "Instalando 1Password CLI..."
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list
    sudo apt update && sudo apt install -y 1password-cli
    
    success "1Password CLI instalado"
}

install_podman_desktop() {
    section "Podman Desktop (para gerenciar Docker)"
    
    if [[ "$IS_WSL" == "true" ]]; then
        warn "Pulando Podman Desktop no WSL (interface gráfica não disponível)"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Podman Desktop para gerenciar containers Docker?"; then
        return 0
    fi
    
    log "Baixando Podman Desktop..."
    curl -L https://github.com/podman-desktop/podman-desktop/releases/download/v1.22.0/podman-desktop-1.22.0.tar.gz -o /tmp/podman-desktop-1.22.0.tar.gz
    
    cd /tmp
    tar -xzf podman-desktop-1.22.0.tar.gz
    sudo mv podman-desktop-1.22.0 /opt/podman-desktop
    sudo chmod +x /opt/podman-desktop/podman-desktop
    sudo ln -sf /opt/podman-desktop/podman-desktop /usr/local/bin/podman-desktop
    
    # Baixar ícone
    curl -L https://raw.githubusercontent.com/containers/podman-desktop/main/buildResources/icon.png -o /tmp/podman-desktop-icon.png
    sudo cp /tmp/podman-desktop-icon.png /usr/share/pixmaps/podman-desktop.png
    
    # Criar .desktop
    cat > /tmp/podman-desktop.desktop << 'EOF'
[Desktop Entry]
Name=Podman Desktop
Comment=Desktop application for managing containers and Kubernetes
Exec=/opt/podman-desktop/podman-desktop %U
Terminal=false
Type=Application
Icon=podman-desktop
Categories=Development;System;Utility;
StartupWMClass=Podman Desktop
MimeType=x-scheme-handler/podman-desktop;
EOF
    
    sudo mv /tmp/podman-desktop.desktop /usr/share/applications/
    sudo chmod 644 /usr/share/applications/podman-desktop.desktop
    sudo update-desktop-database
    
    rm -f /tmp/podman-desktop-*.tar.gz /tmp/podman-desktop-icon.png
    success "Podman Desktop instalado"
}

install_nerd_fonts() {
    section "Nerd Fonts"
    
    if ! ask_yes_no "Instalar Nerd Fonts (FiraCode, JetBrains Mono, etc.)?"; then
        return 0
    fi
    
    log "Instalando Nerd Fonts via script..."
    if curl -fsSL https://gist.githubusercontent.com/lgobatto/4037ca8adf9ee7068fac0ce20e937240/raw/nerdfonts.sh | bash; then
        success "Nerd Fonts instaladas"
    else
        error "Falha na instalação das Nerd Fonts"
        return 1
    fi
}

configure_ssh_1password() {
    section "Configuração SSH + 1Password"
    
    if ! ask_yes_no "Configurar SSH para uso com 1Password?"; then
        return 0
    fi
    
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Criar config SSH básico
    if [[ ! -f ~/.ssh/config ]]; then
        cat > ~/.ssh/config << 'EOF'
# Include 1Password SSH configuration
Include ~/.ssh/1Password/config

# Default configuration for all hosts
Host *
    IdentityAgent ~/.1password/agent.sock
    AddKeysToAgent yes

# GitHub - Default
Host github.com
    HostName github.com
    User git
    IdentitiesOnly yes

# GitLab - Default  
Host gitlab.com
    HostName gitlab.com
    User git
    IdentitiesOnly yes
EOF
        chmod 644 ~/.ssh/config
        success "Configuração SSH criada"
    else
        warn "Arquivo ~/.ssh/config já existe"
    fi
    
    # Configurar SSH Auth Socket no bashrc
    if ! grep -q "SSH_AUTH_SOCK.*1password" ~/.bashrc; then
        echo 'export SSH_AUTH_SOCK=~/.1password/agent.sock' >> ~/.bashrc
        success "SSH Auth Socket configurado no bashrc"
    fi
}

# =============================================================================
# Menu Principal
# =============================================================================

show_menu() {
    title "🚀 Instalador de Ambiente de Desenvolvimento"
    
    echo "Este script irá guiá-lo através da instalação de:"
    echo ""
    echo "📝 Editores:"
    echo "  • Visual Studio Code"
    echo ""
    echo "⚡ Runtime & Ferramentas:"
    echo "  • Volta + Node.js LTS + Yarn"
    echo "  • PHP 8.3 CLI + Composer"
    echo "  • Python3 + pip3"
    echo ""
    echo "🐳 Containers & Deploy:"
    echo "  • Docker Engine + Docker Compose"
    echo "  • Lando (desenvolvimento local)"
    echo "  • Podman Desktop (interface gráfica)"
    echo ""
    echo "☸️  Kubernetes:"
    echo "  • kubectl + kubectx/kubens"
    echo ""
    echo "☁️  Cloud:"
    echo "  • AWS CLI v2"
    echo ""
    echo "🔐 Segurança:"
    echo "  • 1Password CLI + SSH Agent"
    echo ""
    echo "🎨 Fontes:"
    echo "  • Nerd Fonts (FiraCode, JetBrains Mono, etc.)"
    echo ""
    echo -e "${YELLOW}Nota:${NC} Configuração Git será tratada em script separado."
    echo ""
}

# =============================================================================
# Função Principal
# =============================================================================

main() {
    # Criar diretório temporário
    mkdir -p "$TEMP_DIR"
    
    # Mostrar informações iniciais
    show_menu
    
    if ! ask_yes_no "Deseja continuar com a instalação?" "n"; then
        echo "Instalação cancelada pelo usuário."
        exit 0
    fi
    
    # Detectar sistema
    detect_system
    
    # Instalar ferramentas
    echo "" | tee -a "$LOG_FILE"
    log "=== INICIANDO INSTALAÇÕES ===" | tee -a "$LOG_FILE"
    log "Log completo em: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # Dependências básicas (obrigatório)
    install_basic_dependencies || { error "Falha crítica nas dependências básicas"; exit 1; }
    
    # Ferramentas opcionais
    install_vscode
    install_volta_nodejs
    install_yarn
    install_docker
    install_php_composer
    install_aws_cli
    install_kubectl_tools
    install_python_tools
    install_lando
    install_1password_cli
    install_podman_desktop
    install_nerd_fonts
    configure_ssh_1password
    
    # Resumo final
    echo ""
    title "📊 Resumo da Instalação"
    
    if [[ ${#INSTALLED_TOOLS[@]} -gt 0 ]]; then
        echo -e "${GREEN}✅ Ferramentas instaladas com sucesso:${NC}"
        printf '   • %s\n' "${INSTALLED_TOOLS[@]}"
        echo ""
    fi
    
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Falhas na instalação:${NC}"
        printf '   • %s\n' "${FAILED_TOOLS[@]}"
        echo ""
    fi
    
    echo -e "${CYAN}📋 Próximos passos:${NC}"
    echo "   • Reinicie o terminal ou faça logout/login"
    echo "   • Configure o Git com script separado"
    echo "   • Configure suas chaves SSH no 1Password"
    echo "   • Teste as ferramentas instaladas"
    echo ""
    echo -e "${BLUE}📄 Log completo salvo em:${NC} $LOG_FILE"
    echo ""
    
    success "=== INSTALAÇÃO CONCLUÍDA ==="
}

# Verificar se está sendo executado como root
if [[ $EUID -eq 0 ]]; then
    error "Este script não deve ser executado como root!"
    echo "Execute: bash $SCRIPT_NAME"
    exit 1
fi

# Executar função principal
main "$@"