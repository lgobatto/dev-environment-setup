#!/bin/bash

# =============================================================================
# 🚀 Instalador Master de Ambiente de Desenvolvimento
# =============================================================================
# Descrição: Script master para executar instaladores especializados
# Autor: Leonardo Gobatto (@lgobatto)
# Compatibilidade: Ubuntu, Zorin OS, Linux Mint, WSL
# Versão: 2.0.0
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
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

# =============================================================================
# Funções de Utilidade
# =============================================================================

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
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
    echo -e "${CYAN}🚀 $1${NC}"
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

# =============================================================================
# Detecção do Sistema
# =============================================================================

detect_system() {
    section "Detectando Sistema"
    
    # Detectar WSL
    if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        IS_WSL=true
        log "Ambiente WSL detectado"
    else
        IS_WSL=false
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
    log "Home: $HOME"
}

# =============================================================================
# Funções de Execução
# =============================================================================

run_gui_apps() {
    section "Executando Instalador de Apps GUI"
    
    local script_path="$SCRIPT_DIR/gui-apps.sh"
    
    if [[ ! -f "$script_path" ]]; then
        error "Script gui-apps.sh não encontrado em $SCRIPT_DIR"
        return 1
    fi
    
    log "Executando: $script_path"
    bash "$script_path"
    
    if [[ $? -eq 0 ]]; then
        success "Instalador de Apps GUI concluído"
    else
        error "Falha no instalador de Apps GUI"
        return 1
    fi
}

run_shell_apps() {
    section "Executando Instalador de Apps Shell"
    
    local script_path="$SCRIPT_DIR/shell-apps.sh"
    
    if [[ ! -f "$script_path" ]]; then
        error "Script shell-apps.sh não encontrado em $SCRIPT_DIR"
        return 1
    fi
    
    log "Executando: $script_path"
    bash "$script_path"
    
    if [[ $? -eq 0 ]]; then
        success "Instalador de Apps Shell concluído"
    else
        error "Falha no instalador de Apps Shell"
        return 1
    fi
}

run_ssh_git_setup() {
    section "Executando Configurador SSH + Git"
    
    local script_path="$SCRIPT_DIR/ssh-git-setup.sh"
    
    if [[ ! -f "$script_path" ]]; then
        error "Script ssh-git-setup.sh não encontrado em $SCRIPT_DIR"
        return 1
    fi
    
    log "Executando: $script_path"
    bash "$script_path"
    
    if [[ $? -eq 0 ]]; then
        success "Configurador SSH + Git concluído"
    else
        error "Falha no configurador SSH + Git"
        return 1
    fi
}

run_all_scripts() {
    section "Executando Todos os Scripts"
    
    log "Executando instalação completa..."
    echo ""
    
    # Executar em ordem lógica
    run_shell_apps
    echo ""
    
    if [[ "$IS_WSL" != "true" ]]; then
        run_gui_apps
        echo ""
    else
        warn "Pulando apps GUI no WSL (pode executar manualmente se necessário)"
        echo ""
    fi
    
    run_ssh_git_setup
    echo ""
    
    success "Todos os scripts executados!"
}

# =============================================================================
# Menu Principal
# =============================================================================

show_menu() {
    title "🚀 Instalador Master de Ambiente de Desenvolvimento"
    
    echo "Escolha uma das opções abaixo:"
    echo ""
    echo -e "${CYAN}1)${NC} 🖥️  Apps GUI - Aplicações gráficas"
    echo "   • Visual Studio Code, Cursor AI"
    echo "   • Google Chrome"
    echo "   • Warp Terminal"
    echo "   • Discord, Slack, Spotify"
    echo "   • Postman, DBeaver"
    echo "   • 1Password Desktop, Termius"
    echo "   • Nerd Fonts"
    echo ""
    echo -e "${CYAN}2)${NC} ⚡ Apps Shell - Ferramentas de terminal"
    echo "   • Volta + Node.js + Yarn"
    echo "   • Docker Engine + Docker Compose"
    echo "   • PHP + Composer, Python + pip"
    echo "   • AWS CLI, GitHub CLI"
    echo "   • kubectl, Terraform"
    echo "   • Lando, 1Password CLI"
    echo "   • Zsh + Oh My Zsh"
    echo ""
    echo -e "${CYAN}3)${NC} 🔧 SSH + Git - Configuração e identidades"
    echo "   • SSH + 1Password integration"
    echo "   • Git configuração global"
    echo "   • Múltiplas identidades Git"
    echo "   • Hosts SSH customizados"
    echo ""
    echo -e "${CYAN}4)${NC} 🚀 Instalar Tudo - Executar todos os scripts"
    echo ""
    echo -e "${CYAN}5)${NC} ❌ Sair"
    echo ""
}

show_script_status() {
    section "Status dos Scripts"
    
    local scripts=("gui-apps.sh" "shell-apps.sh" "ssh-git-setup.sh" "nerdfonts-install.sh")
    
    for script in "${scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            echo -e "• $script: ${GREEN}✅ Disponível${NC}"
        else
            echo -e "• $script: ${RED}❌ Não encontrado${NC}"
        fi
    done
    echo ""
}

# =============================================================================
# Função Principal
# =============================================================================

main() {
    # Detectar sistema
    detect_system
    echo ""
    
    while true; do
        show_menu
        show_script_status
        
        read -p "Digite sua escolha [1-5]: " choice
        
        case $choice in
            1)
                echo ""
                if ask_yes_no "Executar instalador de Apps GUI?"; then
                    run_gui_apps
                    echo ""
                    read -p "Pressione Enter para continuar..."
                fi
                ;;
            2)
                echo ""
                if ask_yes_no "Executar instalador de Apps Shell?"; then
                    run_shell_apps
                    echo ""
                    read -p "Pressione Enter para continuar..."
                fi
                ;;
            3)
                echo ""
                if ask_yes_no "Executar configurador SSH + Git?"; then
                    run_ssh_git_setup
                    echo ""
                    read -p "Pressione Enter para continuar..."
                fi
                ;;
            4)
                echo ""
                if ask_yes_no "Executar todos os scripts de instalação?"; then
                    run_all_scripts
                    echo ""
                    read -p "Pressione Enter para continuar..."
                fi
                ;;
            5)
                echo ""
                log "Saindo do instalador..."
                exit 0
                ;;
            *)
                echo ""
                error "Opção inválida. Digite um número de 1 a 5."
                echo ""
                read -p "Pressione Enter para continuar..."
                ;;
        esac
        
        clear
    done
}

# Verificar se está sendo executado como root
if [[ $EUID -eq 0 ]]; then
    error "Este script não deve ser executado como root!"
    echo "Execute: bash $SCRIPT_NAME"
    exit 1
fi

# Limpar tela e executar
clear
main "$@"