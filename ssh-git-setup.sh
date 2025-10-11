#!/bin/bash

# =============================================================================
# 🔧 Configurador SSH + Git com Múltiplas Identidades
# =============================================================================
# Descrição: Script para configurar SSH e Git com suporte a múltiplas identidades via 1Password
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
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

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
    echo -e "${CYAN}🔧 $1${NC}"
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

ask_input() {
    local prompt="$1"
    local default="${2:-}"
    local value=""
    
    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " value
        value=${value:-$default}
    else
        read -p "$prompt: " value
    fi
    
    echo "$value"
}

# =============================================================================
# Configurações Git
# =============================================================================

configure_git_global() {
    section "Configuração Git Global"
    
    local name email
    
    # Obter configurações atuais se existirem
    local current_name current_email
    current_name=$(git config --global user.name 2>/dev/null || echo "")
    current_email=$(git config --global user.email 2>/dev/null || echo "")
    
    echo "Configure suas credenciais Git padrão:"
    echo ""
    
    name=$(ask_input "Seu nome completo" "$current_name")
    email=$(ask_input "Seu e-mail" "$current_email")
    
    # Configurar Git
    git config --global user.name "$name"
    git config --global user.email "$email"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global push.autoSetupRemote true
    git config --global core.editor "code --wait" 2>/dev/null || git config --global core.editor "nano"
    
    success "Configuração global do Git definida"
    log "Nome: $name"
    log "Email: $email"
}

setup_ssh_hosts() {
    section "Configuração de Hosts SSH Customizados"
    
    if ! ask_yes_no "Configurar hosts SSH customizados para projetos específicos?"; then
        return 0
    fi
    
    echo ""
    echo "Este recurso permite usar diferentes chaves SSH para diferentes projetos:"
    echo "• github.com / gitlab.com (identidade padrão)"
    echo "• github-empresa / gitlab-empresa (identidade específica)"
    echo ""
    
    local company_name
    company_name=$(ask_input "Nome da empresa/projeto (ex: pipefy, acme, client1)" "")
    
    if [[ -z "$company_name" ]]; then
        warn "Nome da empresa não fornecido. Pulando configuração de hosts customizados."
        return 0
    fi
    
    # Verificar se ~/.ssh/config existe
    if [[ ! -f ~/.ssh/config ]]; then
        warn "Arquivo ~/.ssh/config não encontrado."
        if ask_yes_no "Criar arquivo ~/.ssh/config básico?"; then
            mkdir -p ~/.ssh
            chmod 700 ~/.ssh
            
            cat > ~/.ssh/config << 'EOF'
# Include 1Password SSH configuration
Include ~/.ssh/1Password/config

# Default configuration for all hosts
Host *
    IdentityAgent ~/.1password/agent.sock
    AddKeysToAgent yes
EOF
            chmod 644 ~/.ssh/config
            log "Arquivo ~/.ssh/config criado"
        else
            return 0
        fi
    fi
    
    # Adicionar hosts customizados
    log "Adicionando hosts customizados para $company_name..."
    
    cat >> ~/.ssh/config << EOF

# GitHub - $company_name
Host github-$company_name
    HostName github.com
    User git
    IdentitiesOnly yes

# GitLab - $company_name
Host gitlab-$company_name
    HostName gitlab.com
    User git
    IdentitiesOnly yes

# Bitbucket - $company_name
Host bitbucket-$company_name
    HostName bitbucket.org
    User git
    IdentitiesOnly yes
EOF
    
    success "Hosts SSH customizados adicionados para $company_name"
    
    # Configurar Git condicional
    setup_conditional_git_config "$company_name"
}

setup_conditional_git_config() {
    local company_name="$1"
    
    section "Configuração Git Condicional"
    
    echo "Configure as credenciais Git específicas para $company_name:"
    echo ""
    
    local company_name_display company_email work_directory
    
    company_name_display=$(ask_input "Nome para exibição" "")
    company_email=$(ask_input "E-mail da empresa" "")
    work_directory=$(ask_input "Diretório de trabalho" "~/work/$company_name")
    
    # Expandir ~ para path completo
    work_directory="${work_directory/#~/$HOME}"
    
    # Criar diretório de configuração Git se não existir
    mkdir -p ~/.config/git
    
    # Criar arquivo de configuração específico
    cat > ~/.config/git/config-$company_name << EOF
[user]
    name = $company_name_display
    email = $company_email

[core]
    sshCommand = ssh -F ~/.ssh/config

# Use hosts customizados para $company_name:
# git clone git@github-$company_name:organization/repo.git
# git clone git@gitlab-$company_name:organization/repo.git
EOF
    
    # Adicionar includeIf ao .gitconfig global
    git config --global includeIf.gitdir:$work_directory/.path ~/.config/git/config-$company_name
    
    # Criar diretório de trabalho
    mkdir -p "$work_directory"
    
    success "Configuração Git condicional criada para $company_name"
    log "Diretório: $work_directory"
    log "Config: ~/.config/git/config-$company_name"
    
    echo ""
    echo -e "${CYAN}Como usar:${NC}"
    echo "1. Clone repositórios em: $work_directory"
    echo "2. Use hosts customizados:"
    echo "   • git clone git@github-$company_name:org/repo.git"
    echo "   • git clone git@gitlab-$company_name:org/repo.git"
    echo "3. O Git usará automaticamente as credenciais de $company_name"
    echo ""
}

test_git_configuration() {
    section "Testando Configuração"
    
    echo "Configuração Git Global:"
    echo "• Nome: $(git config --global user.name)"
    echo "• Email: $(git config --global user.email)"
    echo "• Branch padrão: $(git config --global init.defaultBranch)"
    echo ""
    
    # Testar SSH se disponível
    if command -v ssh &>/dev/null && [[ -f ~/.ssh/config ]]; then
        echo "Testando conectividade SSH:"
        
        for host in "github.com" "gitlab.com"; do
            if timeout 5 ssh -T git@$host 2>&1 | grep -q "successfully authenticated\|Welcome"; then
                success "SSH para $host: ✅ Funcionando"
            else
                warn "SSH para $host: ⚠️  Não testado (configuração pendente)"
            fi
        done
    fi
    
    # Mostrar configurações condicionais
    if git config --global --get-regexp "includeIf" &>/dev/null; then
        echo ""
        echo "Configurações condicionais encontradas:"
        git config --global --get-regexp "includeIf" | sed 's/^/• /'
    fi
}

show_usage_examples() {
    section "Exemplos de Uso"
    
    echo -e "${CYAN}Para projetos padrão:${NC}"
    echo "  git clone git@github.com:username/repo.git"
    echo "  git clone git@gitlab.com:username/repo.git"
    echo ""
    
    if git config --global --get-regexp "includeIf" &>/dev/null; then
        echo -e "${CYAN}Para projetos específicos da empresa:${NC}"
        git config --global --get-regexp "includeIf" | while read -r line; do
            local path=$(echo "$line" | cut -d'.' -f2 | sed 's|/\.path||')
            local config_file=$(echo "$line" | cut -d' ' -f2)
            local company=$(basename "$config_file" | sed 's/config-//')
            
            echo "  # Para projetos em: $path"
            echo "  git clone git@github-$company:org/repo.git"
            echo "  git clone git@gitlab-$company:org/repo.git"
            echo ""
        done
    fi
    
    echo -e "${CYAN}Verificar configuração atual:${NC}"
    echo "  git config user.name"
    echo "  git config user.email"
    echo ""
}

# =============================================================================
# Menu Principal
# =============================================================================

configure_ssh_1password() {
    section "Configuração SSH + 1Password"
    
    if ! ask_yes_no "Configurar SSH para uso com 1Password?"; then
        return 0
    fi
    
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Criar config SSH básico se não existir
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
        success "Arquivo ~/.ssh/config já existe"
    fi
    
    # Configurar SSH Auth Socket no bashrc se necessário
    if ! grep -q "SSH_AUTH_SOCK.*1password" ~/.bashrc 2>/dev/null; then
        echo 'export SSH_AUTH_SOCK=~/.1password/agent.sock' >> ~/.bashrc
        success "SSH Auth Socket configurado no bashrc"
    fi
    
    # Se usando Zsh, configurar também no .zshrc
    if [[ -f ~/.zshrc ]] && ! grep -q "SSH_AUTH_SOCK.*1password" ~/.zshrc 2>/dev/null; then
        echo 'export SSH_AUTH_SOCK=~/.1password/agent.sock' >> ~/.zshrc
        success "SSH Auth Socket configurado no zshrc"
    fi
}

show_menu() {
    title "🔧 Configurador SSH + Git com Múltiplas Identidades"
    
    echo "Este script irá configurar:"
    echo ""
    echo "🔐 SSH + 1Password:"
    echo "  • Configuração SSH básica com 1Password Agent"
    echo "  • Integração automática com chaves SSH do 1Password"
    echo ""
    echo "🔧 Git Global:"
    echo "  • Nome e e-mail padrão"
    echo "  • Configurações básicas (branch, push, editor)"
    echo ""
    echo "🏢 Múltiplas Identidades:"
    echo "  • Hosts SSH customizados (github-empresa, gitlab-empresa)"
    echo "  • Configuração Git condicional por diretório"
    echo "  • Suporte a múltiplas chaves SSH"
    echo ""
    echo "📋 Exemplos de uso e testes"
    echo ""
}

main() {
    show_menu
    
    if ! ask_yes_no "Deseja continuar com a configuração do Git?" "n"; then
        echo "Configuração cancelada pelo usuário."
        exit 0
    fi
    
    # Verificar se Git está instalado
    if ! command -v git &>/dev/null; then
        error "Git não encontrado. Instale o Git primeiro:"
        echo "  sudo apt install git"
        exit 1
    fi
    
    # Executar configurações
    configure_ssh_1password
    configure_git_global
    setup_ssh_hosts
    test_git_configuration
    show_usage_examples
    
    echo ""
    title "📊 Configuração Git Concluída"
    
    echo -e "${GREEN}✅ Git configurado com sucesso!${NC}"
    echo ""
    echo -e "${CYAN}📋 Próximos passos:${NC}"
    echo "  • Configure suas chaves SSH no 1Password"
    echo "  • Teste a conectividade: ssh -T git@github.com"
    echo "  • Clone um repositório para testar"
    echo ""
    
    success "=== CONFIGURAÇÃO CONCLUÍDA ==="
}

# Executar função principal
main "$@"