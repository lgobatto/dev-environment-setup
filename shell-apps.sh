#!/bin/bash

# =============================================================================
# ⚡ Instalador de Aplicações Shell/Terminal
# =============================================================================
# Descrição: Script para instalação de ferramentas de linha de comando e desenvolvimento
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
readonly LOG_FILE="/tmp/shell-apps-installer-$(date +%Y%m%d_%H%M%S).log"
readonly TEMP_DIR="/tmp/shell-apps-installer-$$"

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
    echo -e "${CYAN}⚡ $1${NC}"
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
# Funções de Instalação - Apps Shell
# =============================================================================

install_basic_dependencies() {
    section "Instalando Dependências Básicas"
    
    log "Atualizando repositórios..."
    sudo apt update || { error "Falha ao atualizar repositórios"; return 1; }
    
    local basic_packages=(
        "curl" "wget" "git" "unzip" "software-properties-common"
        "apt-transport-https" "ca-certificates" "gnupg" "lsb-release"
        "build-essential" "xclip" "tree" "htop" "vim" "nano"
        "jq" "zip" "net-tools"
    )
    
    log "Instalando pacotes básicos..."
    if sudo apt install -y "${basic_packages[@]}"; then
        success "Dependências básicas"
    else
        error "Dependências básicas"
        return 1
    fi
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
        
        success "Volta + Node.js"
    else
        error "Volta + Node.js"
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
        success "Yarn"
    else
        error "Volta não encontrado. Instale Volta primeiro."
        return 1
    fi
}

install_docker() {
    section "Docker Engine"
    
    if command -v docker &>/dev/null; then
        warn "Docker já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Docker Engine + Docker Compose?"; then
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
    
    success "Docker Engine + Compose"
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
    sudo apt install -y php8.3-cli php8.3-common php8.3-opcache php8.3-curl php8.3-mbstring php8.3-xml php8.3-zip php8.3-mysql php8.3-sqlite3 php8.3-gd php8.3-intl
    
    if ! command -v composer &>/dev/null; then
        log "Instalando Composer..."
        curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
    fi
    
    success "PHP 8.3 + Composer"
}

install_python_tools() {
    section "Python Tools"
    
    if ! ask_yes_no "Instalar Python3 + pip3 + ferramentas essenciais?"; then
        return 0
    fi
    
    log "Instalando Python3 e pip3..."
    sudo apt install -y python3 python3-pip python3-dev python3-venv python3-setuptools
    
    log "Atualizando pip..."
    python3 -m pip install --user --upgrade pip
    
    log "Instalando ferramentas Python essenciais..."
    python3 -m pip install --user pipenv virtualenv black isort flake8
    
    success "Python3 + pip3 + ferramentas"
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
    success "AWS CLI v2"
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
    
    success "kubectl + kubectx/kubens"
}

install_terraform() {
    section "Terraform"
    
    if command -v terraform &>/dev/null; then
        warn "Terraform já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Terraform?"; then
        return 0
    fi
    
    log "Adicionando chave GPG do Terraform..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    
    log "Adicionando repositório do Terraform..."
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    
    log "Instalando Terraform..."
    sudo apt update && sudo apt install -y terraform
    
    if command -v terraform &>/dev/null; then
        success "Terraform"
    else
        error "Terraform"
        return 1
    fi
}

install_gh_cli() {
    section "GitHub CLI"
    
    if command -v gh &>/dev/null; then
        warn "GitHub CLI já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar GitHub CLI (gh)?"; then
        return 0
    fi
    
    log "Instalando GitHub CLI..."
    type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    
    sudo apt update && sudo apt install -y gh
    
    if command -v gh &>/dev/null; then
        success "GitHub CLI"
    else
        error "GitHub CLI"
        return 1
    fi
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
        success "Lando"
    else
        error "Lando"
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
    
    success "1Password CLI"
}

install_zsh_ohmyzsh() {
    section "Zsh + Oh My Zsh"
    
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        warn "Oh My Zsh já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Zsh + Oh My Zsh?"; then
        return 0
    fi
    
    log "Instalando Zsh..."
    sudo apt install -y zsh
    
    log "Instalando Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    log "Configurando plugins essenciais..."
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    
    success "Zsh + Oh My Zsh"
    warn "Execute 'chsh -s $(which zsh)' para tornar Zsh o shell padrão"
}

# =============================================================================
# Menu Principal
# =============================================================================

show_menu() {
    title "⚡ Instalador de Aplicações Shell/Terminal"
    
    echo "Este script irá guiá-lo através da instalação de:"
    echo ""
    echo "🚀 Runtime & Gerenciadores:"
    echo "  • Volta + Node.js LTS + Yarn"
    echo "  • PHP 8.3 CLI + Composer"
    echo "  • Python3 + pip3 + ferramentas"
    echo ""
    echo "🐳 Containers & Deploy:"
    echo "  • Docker Engine + Docker Compose"
    echo "  • Lando (desenvolvimento local)"
    echo ""
    echo "☸️  Kubernetes & Infrastructure:"
    echo "  • kubectl + kubectx/kubens"
    echo "  • Terraform"
    echo ""
    echo "☁️  Cloud & APIs:"
    echo "  • AWS CLI v2"
    echo "  • GitHub CLI"
    echo ""
    echo "🔐 Segurança:"
    echo "  • 1Password CLI"
    echo ""
    echo "🐚 Shell:"
    echo "  • Zsh + Oh My Zsh"
    echo ""
    echo -e "${YELLOW}Nota:${NC} Apps GUI estão em script separado (gui-apps.sh)"
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
    
    if ! ask_yes_no "Deseja continuar com a instalação das ferramentas de terminal?" "n"; then
        echo "Instalação cancelada pelo usuário."
        exit 0
    fi
    
    # Detectar sistema
    detect_system
    
    # Instalar ferramentas
    echo "" | tee -a "$LOG_FILE"
    log "=== INICIANDO INSTALAÇÕES SHELL ===" | tee -a "$LOG_FILE"
    log "Log completo em: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # Dependências básicas (obrigatório)
    install_basic_dependencies || { error "Falha crítica nas dependências básicas"; exit 1; }
    
    # Ferramentas shell
    install_volta_nodejs
    install_yarn
    install_docker
    install_php_composer
    install_python_tools
    install_aws_cli
    install_kubectl_tools
    install_terraform
    install_gh_cli
    install_lando
    install_1password_cli
    install_zsh_ohmyzsh
    
    # Resumo final
    echo ""
    title "📊 Resumo da Instalação Shell"
    
    if [[ ${#INSTALLED_TOOLS[@]} -gt 0 ]]; then
        echo -e "${GREEN}✅ Ferramentas shell instaladas com sucesso:${NC}"
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
    echo "   • Execute gui-apps.sh para aplicações gráficas"
    echo "   • Execute ssh-git-setup.sh para configurar Git e SSH"
    echo "   • Configure suas ferramentas (gh auth login, aws configure, etc.)"
    echo ""
    echo -e "${BLUE}📄 Log completo salvo em:${NC} $LOG_FILE"
    echo ""
    
    success "=== INSTALAÇÃO SHELL CONCLUÍDA ==="
}

# Verificar se está sendo executado como root
if [[ $EUID -eq 0 ]]; then
    error "Este script não deve ser executado como root!"
    echo "Execute: bash $SCRIPT_NAME"
    exit 1
fi

# Executar função principal
main "$@"