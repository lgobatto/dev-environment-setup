#!/bin/bash

# =============================================================================
# 🖥️  Instalador de Aplicações GUI
# =============================================================================
# Descrição: Script para instalação de aplicações gráficas em distribuições Ubuntu-based
# Autor: Leonardo Gobatto (@lgobatto)
# Compatibilidade: Ubuntu, Zorin OS, Linux Mint, WSL (com X11/Wayland)
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
readonly LOG_FILE="/tmp/gui-apps-installer-$(date +%Y%m%d_%H%M%S).log"
readonly TEMP_DIR="/tmp/gui-apps-installer-$$"

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
    echo -e "${CYAN}🖥️  $1${NC}"
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
# Funções de Instalação - Apps GUI
# =============================================================================

install_basic_dependencies() {
    section "Instalando Dependências Básicas para GUI"
    
    log "Atualizando repositórios..."
    sudo apt update || { error "Falha ao atualizar repositórios"; return 1; }
    
    local basic_packages=(
        "curl" "wget" "software-properties-common"
        "apt-transport-https" "ca-certificates" "gnupg" "lsb-release"
        "fontconfig" "xdg-utils"
    )
    
    log "Instalando pacotes básicos para GUI..."
    if sudo apt install -y "${basic_packages[@]}"; then
        success "Dependências básicas para GUI instaladas"
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
        success "Visual Studio Code"
    else
        error "Visual Studio Code"
        return 1
    fi
    
    rm -f packages.microsoft.gpg
}

install_cursor_ai() {
    section "Cursor AI Editor"
    
    if command -v cursor &>/dev/null; then
        warn "Cursor AI já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Cursor AI Editor?"; then
        return 0
    fi
    
    log "Baixando Cursor AI..."
    if wget -O cursor.deb https://api2.cursor.sh/updates/download/golden/linux-x64-deb/cursor/1.7; then
        log "Instalando Cursor AI..."
        if sudo dpkg -i cursor.deb; then
            sudo apt-get install -f -y  # Resolver dependências se necessário
            success "Cursor AI"
        else
            error "Falha ao instalar Cursor AI"
            rm -f cursor.deb
            return 1
        fi
        rm -f cursor.deb
    else
        error "Falha ao baixar Cursor AI"
        return 1
    fi
}

install_chrome() {
    section "Google Chrome"
    
    if command -v google-chrome &>/dev/null; then
        warn "Google Chrome já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Google Chrome?"; then
        return 0
    fi
    
    log "Baixando Google Chrome..."
    wget -q -O google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    
    log "Instalando Google Chrome..."
    sudo apt install -y ./google-chrome-stable_current_amd64.deb
    
    rm -f google-chrome-stable_current_amd64.deb
    
    if command -v google-chrome &>/dev/null; then
        success "Google Chrome"
    else
        error "Google Chrome"
        return 1
    fi
}

install_discord() {
    section "Discord"
    
    if command -v discord &>/dev/null; then
        warn "Discord já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Discord?"; then
        return 0
    fi
    
    log "Baixando Discord..."
    wget -O discord.deb "https://discordapp.com/api/download?platform=linux&format=deb"
    
    log "Instalando Discord..."
    sudo apt install -y ./discord.deb
    
    rm -f discord.deb
    
    if command -v discord &>/dev/null; then
        success "Discord"
    else
        error "Discord"
        return 1
    fi
}

install_slack() {
    section "Slack"
    
    if command -v slack &>/dev/null || flatpak list | grep -q slack; then
        warn "Slack já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Slack?"; then
        return 0
    fi
    
    log "Configurando Flatpak se necessário..."
    if ! command -v flatpak &>/dev/null; then
        sudo apt install -y flatpak
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
    
    log "Instalando Slack via Flatpak..."
    if flatpak install -y flathub com.slack.Slack; then
        success "Slack (Flatpak)"
    else
        error "Falha ao instalar Slack via Flatpak"
        return 1
    fi
}

install_whatsie() {
    section "Whatsie + WhatsApp Desktop"
    
    if flatpak list | grep -q whatsie || flatpak list | grep -q WhatsAppDesktop; then
        warn "Whatsie ou WhatsApp Desktop já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Whatsie + WhatsApp Desktop (clientes WhatsApp)?"; then
        return 0
    fi
    
    log "Configurando Flatpak se necessário..."
    if ! command -v flatpak &>/dev/null; then
        sudo apt install -y flatpak
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
    
    log "Instalando Whatsie via Flatpak..."
    if flatpak install -y flathub com.ktechpit.whatsie; then
        success "Whatsie (Flatpak)"
    else
        warn "Falha ao instalar Whatsie"
    fi
    
    log "Instalando WhatsApp Desktop via Flatpak..."
    if flatpak install -y flathub io.github.mimbrero.WhatsAppDesktop; then
        success "WhatsApp Desktop (Flatpak)"
    else
        warn "Falha ao instalar WhatsApp Desktop"
    fi
}

install_gitkraken() {
    section "GitKraken"
    
    if command -v gitkraken &>/dev/null; then
        warn "GitKraken já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar GitKraken (Git GUI)?"; then
        return 0
    fi
    
    log "Baixando GitKraken..."
    if wget -O gitkraken.deb https://api.gitkraken.dev/releases/production/linux/x64/active/gitkraken-amd64.deb; then
        log "Instalando GitKraken..."
        if sudo dpkg -i gitkraken.deb; then
            sudo apt-get install -f -y  # Resolver dependências se necessário
            
            log "Configurando repositório oficial..."
            echo "deb [trusted=yes] https://release.axocdn.com/linux/ ./" | sudo tee /etc/apt/sources.list.d/gitkraken.list > /dev/null
            
            success "GitKraken"
        else
            error "Falha ao instalar GitKraken"
            rm -f gitkraken.deb
            return 1
        fi
        rm -f gitkraken.deb
    else
        error "Falha ao baixar GitKraken"
        return 1
    fi
}

install_spotify() {
    section "Spotify"
    
    if command -v spotify &>/dev/null; then
        warn "Spotify já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Spotify?"; then
        return 0
    fi
    
    log "Adicionando chave GPG do Spotify..."
    curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
    
    log "Adicionando repositório do Spotify..."
    echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
    
    log "Instalando Spotify..."
    sudo apt update && sudo apt install -y spotify-client
    
    if command -v spotify &>/dev/null; then
        success "Spotify"
    else
        error "Spotify"
        return 1
    fi
}

install_postman() {
    section "Postman"
    
    if command -v postman &>/dev/null || [[ -f /opt/Postman/Postman ]]; then
        warn "Postman já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Postman?"; then
        return 0
    fi
    
    log "Baixando Postman..."
    wget https://dl.pstmn.io/download/latest/linux64 -O postman.tar.gz
    
    log "Extraindo Postman..."
    tar -xzf postman.tar.gz
    sudo mv Postman /opt/
    
    log "Criando link simbólico..."
    sudo ln -sf /opt/Postman/Postman /usr/local/bin/postman
    
    log "Criando entrada no menu..."
    cat > postman.desktop << 'EOF'
[Desktop Entry]
Name=Postman
Exec=/opt/Postman/Postman
Icon=/opt/Postman/app/icons/icon_128x128.png
Terminal=false
Type=Application
Categories=Development;
EOF
    
    sudo mv postman.desktop /usr/share/applications/
    sudo chmod 644 /usr/share/applications/postman.desktop
    sudo update-desktop-database
    
    rm -f postman.tar.gz
    
    if [[ -f /opt/Postman/Postman ]]; then
        success "Postman"
    else
        error "Postman"
        return 1
    fi
}

install_dbeaver() {
    section "DBeaver CE"
    
    if command -v dbeaver &>/dev/null; then
        warn "DBeaver já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar DBeaver CE (Database Manager)?"; then
        return 0
    fi
    
    log "Baixando DBeaver CE..."
    wget https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb
    
    log "Instalando DBeaver CE..."
    sudo apt install -y ./dbeaver-ce_latest_amd64.deb
    
    rm -f dbeaver-ce_latest_amd64.deb
    
    if command -v dbeaver &>/dev/null; then
        success "DBeaver CE"
    else
        error "DBeaver CE"
        return 1
    fi
}

install_podman_desktop() {
    section "Podman Desktop"
    
    if [[ "$IS_WSL" == "true" ]]; then
        warn "Pulando Podman Desktop no WSL (interface gráfica limitada)"
        return 0
    fi
    
    if [[ -f /opt/podman-desktop/podman-desktop ]]; then
        warn "Podman Desktop já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Podman Desktop para gerenciar containers?"; then
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
    
    if [[ -f /opt/podman-desktop/podman-desktop ]]; then
        success "Podman Desktop"
    else
        error "Podman Desktop"
        return 1
    fi
}

install_1password_desktop() {
    section "1Password Desktop"
    
    if command -v 1password &>/dev/null || [[ -f /usr/share/applications/1password.desktop ]]; then
        warn "1Password Desktop já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar 1Password Desktop?"; then
        return 0
    fi
    
    log "Adicionando chave GPG do 1Password..."
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
    
    log "Adicionando repositório do 1Password..."
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list
    
    log "Instalando 1Password Desktop..."
    sudo apt update && sudo apt install -y 1password
    
    if command -v 1password &>/dev/null; then
        success "1Password Desktop"
    else
        error "1Password Desktop"
        return 1
    fi
}

install_warp_terminal() {
    section "Warp Terminal"
    
    if command -v warp-terminal &>/dev/null || [[ -f /usr/share/applications/dev.warp.Warp.desktop ]]; then
        warn "Warp Terminal já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Warp Terminal (AI Terminal)?"; then
        return 0
    fi
    
    log "Adicionando chave GPG do Warp..."
    wget -qO- https://releases.warp.dev/linux/keys/warp.asc | sudo gpg --dearmor -o /usr/share/keyrings/warp-archive-keyring.gpg
    
    log "Adicionando repositório do Warp..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/warp-archive-keyring.gpg] https://releases.warp.dev/linux/deb stable main" | sudo tee /etc/apt/sources.list.d/warp-dev.list
    
    log "Instalando Warp Terminal..."
    sudo apt update && sudo apt install -y warp-terminal
    
    if command -v warp-terminal &>/dev/null; then
        success "Warp Terminal"
    else
        error "Warp Terminal"
        return 1
    fi
}

install_termius() {
    section "Termius SSH Client"
    
    if command -v termius-app &>/dev/null || [[ -f /usr/share/applications/termius-app.desktop ]]; then
        warn "Termius já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Termius SSH Client?"; then
        return 0
    fi
    
    log "Baixando Termius..."
    wget -O termius.deb https://www.termius.com/download/linux/Termius.deb
    
    log "Instalando Termius..."
    sudo apt install -y ./termius.deb
    
    rm -f termius.deb
    
    if command -v termius-app &>/dev/null; then
        success "Termius SSH Client"
    else
        error "Termius SSH Client"
        return 1
    fi
}

install_cursor() {
    section "Cursor AI Editor"
    
    if command -v cursor &>/dev/null || [[ -f /usr/share/applications/cursor.desktop ]]; then
        warn "Cursor já está instalado"
        return 0
    fi
    
    if ! ask_yes_no "Instalar Cursor AI Editor?"; then
        return 0
    fi
    
    log "Baixando Cursor..."
    wget -O cursor.deb https://downloader.cursor.sh/linux/appImage/x64
    
    # Cursor usa AppImage, vamos fazer instalação manual
    log "Preparando Cursor..."
    chmod +x cursor.deb
    sudo mv cursor.deb /opt/cursor.appimage
    
    log "Criando launcher..."
    cat > cursor.desktop << 'EOF'
[Desktop Entry]
Name=Cursor
Exec=/opt/cursor.appimage %U
Terminal=false
Type=Application
Icon=cursor
StartupWMClass=Cursor
Comment=The AI-first Code Editor
MimeType=text/plain;inode/directory;
Categories=TextEditor;Development;IDE;
EOF
    
    sudo mv cursor.desktop /usr/share/applications/
    sudo chmod 644 /usr/share/applications/cursor.desktop
    sudo ln -sf /opt/cursor.appimage /usr/local/bin/cursor
    sudo update-desktop-database
    
    if [[ -f /opt/cursor.appimage ]]; then
        success "Cursor AI Editor"
    else
        error "Cursor AI Editor"
        return 1
    fi
}

install_nerd_fonts() {
    section "Nerd Fonts"
    
    if ! ask_yes_no "Instalar Nerd Fonts (FiraCode, JetBrains Mono, etc.)?"; then
        return 0
    fi
    
    log "Instalando Nerd Fonts via script local..."
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/nerdfonts-install.sh" ]]; then
        if bash "$script_dir/nerdfonts-install.sh"; then
            success "Nerd Fonts"
        else
            error "Nerd Fonts"
            return 1
        fi
    else
        log "Script local não encontrado, baixando via GitHub..."
        if curl -fsSL https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/nerdfonts-install.sh | bash; then
            success "Nerd Fonts"
        else
            error "Nerd Fonts"
            return 1
        fi
    fi
}

# =============================================================================
# Menu Principal
# =============================================================================

show_menu() {
    title "🖥️  Instalador de Aplicações GUI"
    
    echo "Este script irá guiá-lo através da instalação de:"
    echo ""
    echo "📝 Editores:"
    echo "  • Visual Studio Code"
    echo "  • Cursor AI Editor"
    echo ""
    echo "🌐 Navegadores:"
    echo "  • Google Chrome"
    echo ""
    echo "🖥️  Terminais:"
    echo "  • Warp Terminal (AI Terminal)"
    echo ""
    echo "💬 Comunicação:"
    echo "  • Discord"
    echo "  • Slack"
    echo ""
    echo "🎵 Mídia:"
    echo "  • Spotify"
    echo ""
    echo "⚡ Desenvolvimento:"
    echo "  • Postman (API Testing)"
    echo "  • DBeaver CE (Database Manager)"
    echo "  • Podman Desktop (Container Manager)"
    echo ""
    echo "🔐 Utilitários:"
    echo "  • 1Password Desktop"
    echo "  • Termius SSH Client"
    echo ""
    echo "🎨 Fontes:"
    echo "  • Nerd Fonts (FiraCode, JetBrains Mono, etc.)"
    echo ""
    echo -e "${YELLOW}Nota:${NC} Apps de terminal estão em script separado (shell-apps.sh)"
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
    
    if ! ask_yes_no "Deseja continuar com a instalação das aplicações GUI?" "n"; then
        echo "Instalação cancelada pelo usuário."
        exit 0
    fi
    
    # Detectar sistema
    detect_system
    
    # Instalar aplicações
    echo "" | tee -a "$LOG_FILE"
    log "=== INICIANDO INSTALAÇÕES GUI ===" | tee -a "$LOG_FILE"
    log "Log completo em: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # Dependências básicas (obrigatório)
    install_basic_dependencies || { error "Falha crítica nas dependências básicas"; exit 1; }
    
    # Aplicações GUI
    install_vscode
    install_cursor_ai
    install_chrome
    install_warp_terminal
    install_discord
    install_slack
    install_whatsie
    install_spotify
    install_postman
    install_dbeaver
    install_gitkraken
    install_podman_desktop
    install_1password_desktop
    install_termius
    install_nerd_fonts
    
    # Resumo final
    echo ""
    title "📊 Resumo da Instalação GUI"
    
    if [[ ${#INSTALLED_TOOLS[@]} -gt 0 ]]; then
        echo -e "${GREEN}✅ Aplicações GUI instaladas com sucesso:${NC}"
        printf '   • %s\n' "${INSTALLED_TOOLS[@]}"
        echo ""
    fi
    
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Falhas na instalação:${NC}"
        printf '   • %s\n' "${FAILED_TOOLS[@]}"
        echo ""
    fi
    
    echo -e "${CYAN}📋 Próximos passos:${NC}"
    echo "   • Reinicie o terminal para aplicar mudanças"
    echo "   • Execute shell-apps.sh para ferramentas de terminal"
    echo "   • Execute ssh-git-setup.sh para configurar Git e SSH"
    echo ""
    echo -e "${BLUE}📄 Log completo salvo em:${NC} $LOG_FILE"
    echo ""
    
    success "=== INSTALAÇÃO GUI CONCLUÍDA ==="
}

# Verificar se está sendo executado como root
if [[ $EUID -eq 0 ]]; then
    error "Este script não deve ser executado como root!"
    echo "Execute: bash $SCRIPT_NAME"
    exit 1
fi

# Executar função principal
main "$@"