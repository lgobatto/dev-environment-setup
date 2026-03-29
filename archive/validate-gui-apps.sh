#!/usr/bin/env bash

# =============================================================================
# Script de Validação de Apps GUI
# =============================================================================
# Valida se todos os aplicativos GUI estão instalados corretamente
# Autor: Leonardo Gobatto
# Data: 2025-11-03
# =============================================================================

set -e

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Validação de Apps GUI ===${NC}"
echo ""

# Contadores
TOTAL=0
SUCCESS=0
FAILED=0

validate_app() {
    local app_name="$1"
    local app_cmd="$2"
    local is_flatpak="${3:-false}"
    
    TOTAL=$((TOTAL + 1))
    
    if [ "$is_flatpak" = "true" ]; then
        if flatpak list --app | grep -q "$app_cmd"; then
            echo -e "${GREEN}✓${NC} $app_name (Flatpak)"
            SUCCESS=$((SUCCESS + 1))
            return 0
        fi
    else
        if command -v "$app_cmd" &>/dev/null; then
            echo -e "${GREEN}✓${NC} $app_name"
            SUCCESS=$((SUCCESS + 1))
            return 0
        fi
    fi
    
    echo -e "${RED}✗${NC} $app_name - ${YELLOW}NÃO INSTALADO${NC}"
    FAILED=$((FAILED + 1))
    return 1
}

echo "📝 Editores:"
validate_app "VS Code" "code"
validate_app "Cursor AI" "cursor"

echo ""
echo "🌐 Navegadores:"
validate_app "Google Chrome" "google-chrome"

echo ""
echo "🖥️  Terminais:"
validate_app "Warp Terminal" "warp-terminal"

echo ""
echo "💬 Comunicação:"
validate_app "Discord" "discord"
validate_app "Slack" "com.slack.Slack" "true"
validate_app "WhatsApp Desktop" "io.github.mimbrero.WhatsAppDesktop" "true"

echo ""
echo "🎵 Mídia:"
validate_app "Spotify" "spotify"

echo ""
echo "⚡ Desenvolvimento:"
validate_app "Postman" "postman"
validate_app "DBeaver CE" "dbeaver"
validate_app "GitKraken" "gitkraken"
validate_app "Podman Desktop" "podman-desktop" || {
    # Verifica instalação alternativa
    if [ -f /opt/podman-desktop/podman-desktop ]; then
        echo -e "${GREEN}✓${NC} Podman Desktop"
        SUCCESS=$((SUCCESS + 1))
        FAILED=$((FAILED - 1))
    fi
}

echo ""
echo "🔐 Utilitários:"
validate_app "1Password" "1password"
validate_app "Termius" "termius"

echo ""
echo -e "${BLUE}=== Resumo ===${NC}"
echo -e "Total: ${TOTAL}"
echo -e "${GREEN}Instalados: ${SUCCESS}${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Faltando: ${FAILED}${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Todos os apps estão instalados!${NC}"
    exit 0
fi
