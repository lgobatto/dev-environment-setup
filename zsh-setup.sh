#!/bin/bash

# =============================================================================
# 🐚 Zsh + Oh My Zsh + Powerlevel10k Setup
# =============================================================================
# Descrição: Script para instalação e configuração completa do Zsh com Oh My Zsh e Powerlevel10k
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
readonly LOG_FILE="/tmp/zsh-setup-$(date +%Y%m%d_%H%M%S).log"

# =============================================================================
# Funções de Utilidade
# =============================================================================

log() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
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
    echo -e "${CYAN}🐚 $1${NC}"
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
    
    # Verificar se é Ubuntu-based
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "${ID,,}" in
            ubuntu|zorin|linuxmint|pop|elementary|kubuntu|xubuntu|lubuntu)
                success "Distribuição Ubuntu-based detectada: $NAME"
                ;;
            *)
                error "Distribuição não suportada: $NAME"
                echo "Este script foi projetado para distribuições baseadas em Ubuntu."
                exit 1
                ;;
        esac
    else
        error "Não foi possível detectar a distribuição"
        exit 1
    fi
    
    # Detectar WSL
    if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        log "Ambiente WSL detectado"
    fi
    
    log "Usuário: $USER"
    log "Shell atual: $SHELL"
}

# =============================================================================
# Funções de Instalação
# =============================================================================

install_zsh() {
    section "Instalando Zsh"
    
    if command -v zsh &>/dev/null; then
        warn "Zsh já está instalado ($(zsh --version))"
        return 0
    fi
    
    log "Atualizando repositórios..."
    sudo apt update || { error "Falha ao atualizar repositórios"; return 1; }
    
    log "Instalando Zsh..."
    if sudo apt install -y zsh; then
        success "Zsh instalado: $(zsh --version)"
    else
        error "Falha ao instalar Zsh"
        return 1
    fi
}

install_oh_my_zsh() {
    section "Instalando Oh My Zsh"
    
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        warn "Oh My Zsh já está instalado"
        return 0
    fi
    
    log "Baixando e instalando Oh My Zsh..."
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        success "Oh My Zsh instalado"
    else
        error "Falha ao instalar Oh My Zsh"
        return 1
    fi
}

install_zsh_plugins() {
    section "Instalando Plugins Essenciais"
    
    local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    
    # zsh-autosuggestions
    if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
        log "Instalando zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"
        success "zsh-autosuggestions instalado"
    else
        warn "zsh-autosuggestions já está instalado"
    fi
    
    # zsh-syntax-highlighting
    if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
        log "Instalando zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
        success "zsh-syntax-highlighting instalado"
    else
        warn "zsh-syntax-highlighting já está instalado"
    fi
}

install_powerlevel10k() {
    section "Instalando Powerlevel10k"
    
    local themes_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes"
    
    if [[ ! -d "$themes_dir/powerlevel10k" ]]; then
        log "Instalando Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$themes_dir/powerlevel10k"
        success "Powerlevel10k instalado"
    else
        warn "Powerlevel10k já está instalado"
    fi
}

extract_bash_vars() {
    local bashrc="$HOME/.bashrc"
    local temp_file="/tmp/bash_vars_$$"
    
    if [[ ! -f "$bashrc" ]]; then
        return 0
    fi
    
    # Extrair variáveis importantes do bashrc
    log "Extraindo variáveis importantes do ~/.bashrc..."
    
    # Buscar por exports e PATHs importantes
    grep -E '^export [A-Z_]+(=|\s)' "$bashrc" | 
        grep -E '(VOLTA|SSH_AUTH_SOCK|LANDO|NODE|JAVA|PYTHON|CARGO|COMPOSER)' > "$temp_file" 2>/dev/null || true
    
    # Buscar por modificações no PATH
    grep -E '^(export )?PATH=' "$bashrc" >> "$temp_file" 2>/dev/null || true
    
    if [[ -s "$temp_file" ]]; then
        success "Variáveis importantes detectadas no bashrc"
        cat "$temp_file" | head -10  # Mostrar algumas das variáveis encontradas
    fi
    
    rm -f "$temp_file"
}

configure_zshrc() {
    section "Configurando .zshrc"
    
    local zshrc="$HOME/.zshrc"
    
    if [[ ! -f "$zshrc" ]]; then
        error "Arquivo .zshrc não encontrado!"
        return 1
    fi
    
    # Extrair variáveis do bashrc primeiro
    extract_bash_vars
    
    # Backup do .zshrc original
    cp "$zshrc" "$zshrc.backup-$(date +%Y%m%d_%H%M%S)"
    log "Backup do .zshrc criado"
    
    # Configurar tema Powerlevel10k
    if ! grep -q "powerlevel10k/powerlevel10k" "$zshrc"; then
        sed -i 's/ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc"
        success "Tema Powerlevel10k configurado"
    fi
    
    # Configurar plugins
    if ! grep -q "zsh-autosuggestions" "$zshrc"; then
        # Criar nova configuração de plugins
        local plugins_config='plugins=(\n  git\n  zsh-autosuggestions\n  zsh-syntax-highlighting\n  docker\n  docker-compose\n  kubectl\n  volta\n  yarn\n  npm\n  composer\n  aws\n  terraform\n  github\n)'
        
        sed -i "/^plugins=(/,/^)/c\\$plugins_config" "$zshrc"
        success "Plugins configurados"
    fi
    
    # Adicionar importação inteligente do bashrc se não existir
    if ! grep -q "Import essential environment variables" "$zshrc"; then
        cat >> "$zshrc" << 'EOF'

# Import essential environment variables from bash configuration
# This ensures compatibility with existing bash setup while avoiding bash-specific commands
if [ -f ~/.bashrc ]; then
    # Source only environment variables and aliases, skip bash-specific functions
    source <(grep -E '^(export|alias|PATH=)' ~/.bashrc 2>/dev/null || true)
fi

# Manually import essential variables from bashrc
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
export SSH_AUTH_SOCK=~/.1password/agent.sock
export PATH="/home/lgobatto/.lando/bin:$PATH"

# Import aliases safely
if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

# Personal aliases
alias zshconfig="code ~/.zshrc"
alias ohmyzsh="code ~/.oh-my-zsh"
alias p10k="p10k configure"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF
        success "Configurações personalizadas adicionadas"
    fi
}

change_default_shell() {
    section "Configurando Shell Padrão"
    
    local current_shell=$(getent passwd "$USER" | cut -d: -f7)
    local zsh_path=$(which zsh)
    
    if [[ "$current_shell" == "$zsh_path" ]]; then
        success "Zsh já é o shell padrão"
        return 0
    fi
    
    if ask_yes_no "Alterar shell padrão para Zsh?"; then
        log "Alterando shell padrão para Zsh..."
        chsh -s "$zsh_path"
        success "Shell padrão alterado para Zsh"
        warn "Será necessário fazer logout/login ou reiniciar o terminal para aplicar a mudança"
    else
        warn "Shell padrão mantido como $current_shell"
        log "Você pode alterar manualmente com: chsh -s $(which zsh)"
    fi
}

test_installation() {
    section "Testando Instalação"
    
    # Testar se Zsh carrega sem erros
    if zsh -c 'echo "✅ Zsh carrega corretamente"' &>/dev/null; then
        success "Zsh está funcionando corretamente"
    else
        error "Problemas detectados no Zsh"
        return 1
    fi
    
    # Verificar se plugins estão disponíveis
    local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    if [[ -d "$plugins_dir/zsh-autosuggestions" && -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
        success "Plugins instalados corretamente"
    else
        warn "Alguns plugins podem não estar disponíveis"
    fi
    
    # Verificar Powerlevel10k
    local themes_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes"
    if [[ -d "$themes_dir/powerlevel10k" ]]; then
        success "Powerlevel10k está disponível"
    else
        warn "Powerlevel10k não foi encontrado"
    fi
}

show_next_steps() {
    section "Próximos Passos"
    
    echo -e "${CYAN}📋 Para concluir a configuração:${NC}"
    echo ""
    echo "1. 🔄 Reinicie o terminal ou faça logout/login"
    echo "2. 🎨 Configure o Powerlevel10k executando:"
    echo "   ${WHITE}p10k configure${NC}"
    echo ""
    echo "3. 🛠️ Personalize mais configurações editando:"
    echo "   ${WHITE}~/.zshrc${NC} - Configuração principal"
    echo "   ${WHITE}~/.p10k.zsh${NC} - Configuração do tema"
    echo ""
    echo -e "${CYAN}🔧 Comandos úteis:${NC}"
    echo "   ${WHITE}zshconfig${NC} - Editar configuração do Zsh"
    echo "   ${WHITE}ohmyzsh${NC} - Abrir diretório do Oh My Zsh"
    echo "   ${WHITE}p10k${NC} - Reconfigurar Powerlevel10k"
    echo ""
    echo -e "${CYAN}🎯 Recursos instalados:${NC}"
    echo "   ✅ Autosugestões de comandos"
    echo "   ✅ Syntax highlighting"
    echo "   ✅ Git integration"
    echo "   ✅ Docker/Kubernetes completions"
    echo "   ✅ Node.js/Yarn/npm completions"
    echo "   ✅ Tema Powerlevel10k customizável"
    echo ""
}

# =============================================================================
# Menu Principal
# =============================================================================

show_menu() {
    title "🐚 Zsh + Oh My Zsh + Powerlevel10k Setup"
    
    echo "Este script irá instalar e configurar:"
    echo ""
    echo "🐚 ${WHITE}Zsh${NC} - Shell avançado e poderoso"
    echo "⚡ ${WHITE}Oh My Zsh${NC} - Framework para Zsh"
    echo "🎨 ${WHITE}Powerlevel10k${NC} - Tema rápido e customizável"
    echo "🔌 ${WHITE}Plugins essenciais:${NC}"
    echo "   • zsh-autosuggestions - Sugestões automáticas"
    echo "   • zsh-syntax-highlighting - Destaque de sintaxe"
    echo "   • git, docker, kubectl, yarn, npm, etc."
    echo ""
    echo "🔄 ${WHITE}Integração:${NC}"
    echo "   • Importa configurações do ~/.bashrc"
    echo "   • Mantém variáveis de ambiente existentes"
    echo "   • Compatível com Volta, 1Password, etc."
    echo ""
}

# =============================================================================
# Função Principal
# =============================================================================

main() {
    show_menu
    
    if ! ask_yes_no "Deseja continuar com a instalação do Zsh + Oh My Zsh + Powerlevel10k?" "n"; then
        echo "Instalação cancelada pelo usuário."
        exit 0
    fi
    
    # Detectar sistema
    detect_system
    
    # Executar instalação
    echo "" | tee -a "$LOG_FILE"
    log "=== INICIANDO INSTALAÇÃO ZSH ===" | tee -a "$LOG_FILE"
    log "Log completo em: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    install_zsh
    install_oh_my_zsh
    install_zsh_plugins
    install_powerlevel10k
    configure_zshrc
    change_default_shell
    test_installation
    
    # Resumo final
    echo ""
    title "📊 Instalação Concluída"
    
    success "Zsh + Oh My Zsh + Powerlevel10k instalados com sucesso!"
    echo ""
    
    show_next_steps
    
    echo -e "${BLUE}📄 Log completo salvo em:${NC} $LOG_FILE"
    echo ""
    
    success "=== SETUP ZSH CONCLUÍDO ==="
}

# Verificar se está sendo executado como root
if [[ $EUID -eq 0 ]]; then
    error "Este script não deve ser executado como root!"
    echo "Execute: bash $SCRIPT_NAME"
    exit 1
fi

# Executar função principal
main "$@"