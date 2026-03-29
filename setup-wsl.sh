#!/usr/bin/env bash
# =============================================================================
#  WSL2 Development Environment Setup
#  Ubuntu 24.04 LTS — Idempotent, sempre instala versões mais recentes
#
#  O que instala:
#    - Docker Engine (sem Docker Desktop — mais leve e mais rápido)
#    - nvm + Node.js LTS
#    - PHP 8.3 + Composer
#    - Lando CLI (Linux nativo)
#    - Claude Code CLI
#    - GitHub CLI
#    - Zsh + Oh My Zsh + Powerlevel10k + plugins
#    - Git configurado para WSL
#
#  Uso:
#    bash setup-wsl.sh
#
#    # Com opções via env vars:
#    INSTALL_1PASSWORD=1 GIT_NAME="Leo" GIT_EMAIL="leo@email.com" bash setup-wsl.sh
#
#  Idempotente — seguro para re-executar a qualquer momento.
# =============================================================================

set -euo pipefail

# ── Configurações (sobrescreva via variável de ambiente) ─────────────────────
INSTALL_1PASSWORD="${INSTALL_1PASSWORD:-0}"
GIT_NAME="${GIT_NAME:-}"
GIT_EMAIL="${GIT_EMAIL:-}"
NODE_VERSION="${NODE_VERSION:-lts}"    # "lts", "latest", ou versão específica "22"
PHP_VERSION="${PHP_VERSION:-8.3}"

# ── Cores e helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}▶ $*${RESET}"; }
ok()    { echo -e "  ${GREEN}✔${RESET} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET} $*"; }
fail()  { echo -e "  ${RED}✖${RESET} $*" >&2; }
info()  { echo -e "  ${BOLD}→${RESET} $*"; }

# Verifica se comando existe
has() { command -v "$1" &>/dev/null; }

# Instala pacotes apt silenciosamente
apt_install() {
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" 2>/dev/null
}

echo -e "${CYAN}${BOLD}"
cat << 'BANNER'
  ╔══════════════════════════════════════════════════════╗
  ║      WSL2 Dev Environment Setup                    ║
  ║      Ubuntu 24.04 · Node · PHP · Lando · Claude    ║
  ╚══════════════════════════════════════════════════════╝
BANNER
echo -e "${RESET}"

# ── Verificar distro ─────────────────────────────────────────────────────────
if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    warn "Este script foi feito para Ubuntu. Pode não funcionar em outra distro."
fi

# ── 1. Habilitar systemd (necessário para Docker autostart) ──────────────────
step "Verificando systemd no WSL2..."
WSL_CONF="/etc/wsl.conf"
if ! grep -q "systemd=true" "$WSL_CONF" 2>/dev/null; then
    sudo mkdir -p "$(dirname "$WSL_CONF")"
    if grep -q "\[boot\]" "$WSL_CONF" 2>/dev/null; then
        sudo sed -i '/\[boot\]/a systemd=true' "$WSL_CONF"
    else
        printf '\n[boot]\nsystemd=true\n' | sudo tee -a "$WSL_CONF" > /dev/null
    fi
    warn "systemd habilitado no /etc/wsl.conf."
    warn "Para aplicar agora: saia do WSL e rode 'wsl --shutdown' no PowerShell."
    warn "Continuando — alguns serviços podem precisar ser iniciados manualmente."
else
    ok "systemd já habilitado"
fi

# ── 2. Atualizar sistema e instalar base ──────────────────────────────────────
step "Atualizando sistema..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq 2>/dev/null
apt_install \
    curl wget git unzip zip \
    gnupg ca-certificates \
    build-essential \
    software-properties-common \
    apt-transport-https \
    lsb-release \
    zsh socat jq \
    xdg-utils
ok "Sistema atualizado e dependências base instaladas"

# ── 3. Docker Engine (sem Docker Desktop) ────────────────────────────────────
step "Instalando Docker Engine..."
#
# Comparativo: Docker Desktop vs Docker Engine no WSL2
#   Docker Desktop:  GUI, integração automática, +500MB RAM, mais lento no I/O
#   Docker Engine:   CLI only, leve, rápido, nativo no Linux — ideal para WSL2
#
# Quando projetos estão em ~/projects (filesystem Linux nativo), o Docker Engine
# lê os arquivos sem passar pela camada de interop Windows → ganho dramático.
#
if has docker; then
    ok "Docker já instalado: $(docker --version)"
else
    # Adicionar chave GPG oficial do Docker
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Adicionar repositório
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -qq
    apt_install \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Adicionar usuário ao grupo docker (sem sudo)
    sudo usermod -aG docker "$USER"

    # Habilitar e iniciar
    sudo systemctl enable docker 2>/dev/null || true
    sudo systemctl start docker 2>/dev/null || \
        warn "Não foi possível iniciar o Docker via systemd. Rode 'sudo service docker start' manualmente."

    ok "Docker Engine instalado: $(docker --version)"
fi

# ── 4. nvm + Node.js ─────────────────────────────────────────────────────────
step "Instalando nvm + Node.js..."
export NVM_DIR="$HOME/.nvm"

if [ ! -d "$NVM_DIR" ]; then
    # Sempre busca a versão mais recente do nvm via API
    NVM_LATEST=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest \
        | jq -r '.tag_name' 2>/dev/null || echo "master")
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_LATEST}/install.sh" | bash
    ok "nvm ${NVM_LATEST} instalado"
else
    ok "nvm já instalado — atualizando..."
    # Atualiza nvm para versão mais recente
    NVM_LATEST=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest \
        | jq -r '.tag_name' 2>/dev/null || echo "")
    if [ -n "$NVM_LATEST" ]; then
        curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_LATEST}/install.sh" | bash 2>/dev/null || true
    fi
fi

# Carregar nvm nesta sessão
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Instalar Node.js
if [ "$NODE_VERSION" = "lts" ]; then
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'
elif [ "$NODE_VERSION" = "latest" ]; then
    nvm install node
    nvm use node
    nvm alias default node
else
    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
fi

ok "Node.js: $(node --version) | npm: $(npm --version)"

# ── 5. PHP + Composer ────────────────────────────────────────────────────────
step "Instalando PHP ${PHP_VERSION} + Composer..."

if ! has php || ! php -r "exit(PHP_MAJOR_VERSION >= 8 ? 0 : 1);"; then
    # Repositório ondrej/php — suporte a múltiplas versões PHP no Ubuntu
    sudo add-apt-repository ppa:ondrej/php -y 2>/dev/null
    sudo apt-get update -qq

    apt_install \
        "php${PHP_VERSION}" \
        "php${PHP_VERSION}-cli" \
        "php${PHP_VERSION}-fpm" \
        "php${PHP_VERSION}-common" \
        "php${PHP_VERSION}-mysql" \
        "php${PHP_VERSION}-pgsql" \
        "php${PHP_VERSION}-sqlite3" \
        "php${PHP_VERSION}-zip" \
        "php${PHP_VERSION}-gd" \
        "php${PHP_VERSION}-mbstring" \
        "php${PHP_VERSION}-curl" \
        "php${PHP_VERSION}-xml" \
        "php${PHP_VERSION}-bcmath" \
        "php${PHP_VERSION}-intl" \
        "php${PHP_VERSION}-redis" \
        "php${PHP_VERSION}-imagick" \
        "php${PHP_VERSION}-xdebug"

    ok "PHP instalado: $(php --version | head -1)"
else
    ok "PHP já instalado: $(php --version | head -1)"
fi

if ! has composer; then
    info "Instalando Composer..."
    EXPECTED_SIG="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
    php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
    ACTUAL_SIG="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
    if [ "$EXPECTED_SIG" != "$ACTUAL_SIG" ]; then
        fail "Checksum do Composer inválido — abortando"
        rm /tmp/composer-setup.php
        exit 1
    fi
    php /tmp/composer-setup.php --quiet --install-dir=/tmp
    sudo mv /tmp/composer.phar /usr/local/bin/composer
    rm /tmp/composer-setup.php
    ok "Composer instalado: $(composer --version)"
else
    # Atualizar composer para versão mais recente
    sudo composer self-update 2>/dev/null || true
    ok "Composer já instalado: $(composer --version)"
fi

# ── 6. Lando CLI ─────────────────────────────────────────────────────────────
step "Instalando Lando CLI..."
#
# Lando no Linux usa Docker Engine diretamente — sem Docker Desktop.
# Projetos em ~/projects (filesystem Linux nativo) → I/O direto, sem overhead.
#
if has lando; then
    ok "Lando já instalado: $(lando version 2>/dev/null || echo 'versão desconhecida')"
else
    # Buscar URL do .deb mais recente via GitHub API
    LANDO_DEB_URL=$(curl -fsSL \
        "https://api.github.com/repos/lando/lando/releases/latest" \
        | jq -r '.assets[] | select(.name | test("lando-x64-v.*\\.deb$")) | .browser_download_url' \
        | head -1)

    if [ -z "$LANDO_DEB_URL" ]; then
        fail "Não foi possível encontrar o .deb do Lando via GitHub API"
        warn "Instale manualmente: https://docs.lando.dev/install/linux"
    else
        info "Baixando Lando de: $LANDO_DEB_URL"
        curl -fsSL "$LANDO_DEB_URL" -o /tmp/lando.deb
        sudo dpkg -i /tmp/lando.deb
        rm /tmp/lando.deb
        ok "Lando instalado: $(lando version 2>/dev/null)"
    fi
fi

# ── 7. GitHub CLI ─────────────────────────────────────────────────────────────
step "Instalando GitHub CLI..."
if has gh; then
    ok "GitHub CLI já instalado: $(gh --version | head -1)"
else
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
        https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq
    apt_install gh
    ok "GitHub CLI instalado: $(gh --version | head -1)"
fi

# ── 8. Claude Code CLI ────────────────────────────────────────────────────────
step "Instalando Claude Code CLI..."
if has claude; then
    info "Atualizando Claude Code para versão mais recente..."
    npm update -g @anthropic-ai/claude-code 2>/dev/null || true
    ok "Claude Code: $(claude --version 2>/dev/null || echo 'atualizado')"
else
    npm install -g @anthropic-ai/claude-code
    ok "Claude Code instalado"
fi

# ── 9. Zsh + Oh My Zsh + Powerlevel10k ───────────────────────────────────────
step "Configurando Zsh + Oh My Zsh + Powerlevel10k..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended
    ok "Oh My Zsh instalado"
else
    ok "Oh My Zsh já instalado"
fi

# Powerlevel10k
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "$ZSH_CUSTOM/themes/powerlevel10k"
    ok "Powerlevel10k instalado"
else
    ok "Powerlevel10k já instalado"
    git -C "$ZSH_CUSTOM/themes/powerlevel10k" pull --quiet 2>/dev/null || true
fi

# Plugins
declare -A PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
    ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
)
for plugin in "${!PLUGINS[@]}"; do
    dir="$ZSH_CUSTOM/plugins/$plugin"
    if [ ! -d "$dir" ]; then
        git clone --depth=1 "${PLUGINS[$plugin]}" "$dir"
        ok "Plugin: $plugin"
    else
        git -C "$dir" pull --quiet 2>/dev/null || true
        ok "Plugin atualizado: $plugin"
    fi
done

# ── 10. Configurar .zshrc ─────────────────────────────────────────────────────
step "Configurando .zshrc..."

# Backup do .zshrc existente
[ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%s)"

# Detectar Windows username para 1Password socket path
WIN_USER=""
if [ "$INSTALL_1PASSWORD" = "1" ]; then
    WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || echo "")
fi

cat > "$HOME/.zshrc" << ZSHRCEOF
# ─── Powerlevel10k instant prompt ─────────────────────────────────────────────
if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then
    source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"
fi

# ─── Oh My Zsh ────────────────────────────────────────────────────────────────
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
    git
    docker
    docker-compose
    npm
    composer
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
)

source \$ZSH/oh-my-zsh.sh

# ─── nvm ──────────────────────────────────────────────────────────────────────
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"

# ─── Navegação ────────────────────────────────────────────────────────────────
alias dev="cd ~/projects"
alias la="ls -lah --color=auto"
alias ll="ls -lh --color=auto"

# ─── Git ──────────────────────────────────────────────────────────────────────
alias gs="git status"
alias gco="git checkout"
alias gpl="git pull --recurse-submodules"
alias gps="git push"
alias gcm="git commit -m"

# ─── Docker ───────────────────────────────────────────────────────────────────
alias dcu="docker compose up"
alias dcd="docker compose down"
alias dcl="docker compose logs -f"
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# ─── Lando ────────────────────────────────────────────────────────────────────
alias lup="lando start"
alias ldn="lando stop"
alias ldev="lando dev"
alias lbuild="lando theme-build"
alias lflush="lando flush"
alias lacorn="lando acorn"
alias lssh="lando ssh"

# ─── Claude Code ──────────────────────────────────────────────────────────────
alias cc="claude"

# ─── Utilitários ──────────────────────────────────────────────────────────────
alias reload="source ~/.zshrc"
alias zshrc="code ~/.zshrc"

ZSHRCEOF

# Adicionar 1Password SSH Agent se solicitado
if [ "$INSTALL_1PASSWORD" = "1" ] && [ -n "$WIN_USER" ]; then
    OP_SOCK="/mnt/c/Users/${WIN_USER}/.1password/agent.sock"

    # 1. SSH_AUTH_SOCK no .zshrc — ativa o agent para todos os comandos SSH da sessao
    cat >> "$HOME/.zshrc" << OPEOF

# ─── 1Password SSH Agent ──────────────────────────────────────────────────────
# Requer: 1Password > Settings > Developer > SSH Agent + "Integrate with WSL"
export SSH_AUTH_SOCK="${OP_SOCK}"
OPEOF

    # 2. ~/.ssh/config — garante que o agente seja usado por qualquer cliente SSH,
    #    independente de shell (git, rsync, scp, etc.)
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    SSH_CONFIG="$HOME/.ssh/config"

    if ! grep -q "1password" "$SSH_CONFIG" 2>/dev/null; then
        cat >> "$SSH_CONFIG" << SSHEOF

# ─── 1Password SSH Agent ──────────────────────────────────────────────────────
Host *
    IdentityAgent ${OP_SOCK}
SSHEOF
        chmod 600 "$SSH_CONFIG"
        ok "~/.ssh/config configurado com IdentityAgent"
    else
        ok "~/.ssh/config ja tem entrada do 1Password"
    fi

    ok "1Password SSH agent configurado (SSH_AUTH_SOCK + ~/.ssh/config)"
    warn "Certifique-se de habilitar em: 1Password > Settings > Developer > SSH Agent + Integrate with WSL"
fi

# Adicionar p10k config ao final
cat >> "$HOME/.zshrc" << 'P10KEOF'

# ─── Powerlevel10k ───────────────────────────────────────────────────────────
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
P10KEOF

ok ".zshrc configurado"

# ── 11. Definir Zsh como shell padrão ────────────────────────────────────────
step "Definindo Zsh como shell padrão..."
ZSH_BIN="$(which zsh)"
if [ "$SHELL" != "$ZSH_BIN" ]; then
    if sudo chsh -s "$ZSH_BIN" "$USER" 2>/dev/null; then
        ok "Shell padrão alterado para Zsh"
    else
        warn "Não foi possível alterar o shell automaticamente."
        info "Execute manualmente: chsh -s $ZSH_BIN"
    fi
else
    ok "Zsh já é o shell padrão"
fi

# ── 12. Git global config ────────────────────────────────────────────────────
step "Configurando Git..."
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.autocrlf input    # Normaliza CRLF→LF ao commitar (importante no Windows)
git config --global core.fileMode false    # Ignora mudanças de permissão de arquivo
git config --global push.autoSetupRemote true
git config --global rebase.autoStash true

if [ -n "$GIT_NAME" ]; then
    git config --global user.name "$GIT_NAME"
    ok "git user.name = $GIT_NAME"
else
    warn "GIT_NAME não definido. Configure depois: git config --global user.name 'Seu Nome'"
fi

if [ -n "$GIT_EMAIL" ]; then
    git config --global user.email "$GIT_EMAIL"
    ok "git user.email = $GIT_EMAIL"
else
    warn "GIT_EMAIL não definido. Configure depois: git config --global user.email 'seu@email.com'"
fi

ok "Git configurado"

# ── 13. Criar estrutura de projetos ──────────────────────────────────────────
step "Criando estrutura ~/projects..."
mkdir -p ~/projects
ok "~/projects pronto"

# ── 14. Resumo final ─────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}"
cat << 'SUMMARY'
  ╔══════════════════════════════════════════════════════╗
  ║              WSL2 Setup Concluído!                 ║
  ╚══════════════════════════════════════════════════════╝
SUMMARY
echo -e "${RESET}"

echo -e "  Versões instaladas:"
has node     && echo -e "    ${GREEN}✔${RESET} Node.js:    $(node --version)"
has npm      && echo -e "    ${GREEN}✔${RESET} npm:        $(npm --version)"
has php      && echo -e "    ${GREEN}✔${RESET} PHP:        $(php --version | head -1 | cut -d' ' -f1-2)"
has composer && echo -e "    ${GREEN}✔${RESET} Composer:   $(composer --version 2>/dev/null | cut -d' ' -f1-3)"
has docker   && echo -e "    ${GREEN}✔${RESET} Docker:     $(docker --version 2>/dev/null | cut -d',' -f1)"
has lando    && echo -e "    ${GREEN}✔${RESET} Lando:      $(lando version 2>/dev/null || echo 'instalado')"
has gh       && echo -e "    ${GREEN}✔${RESET} GitHub CLI: $(gh --version 2>/dev/null | head -1 | cut -d' ' -f1-3)"
has claude   && echo -e "    ${GREEN}✔${RESET} Claude Code: instalado"
has zsh      && echo -e "    ${GREEN}✔${RESET} Zsh:        $(zsh --version)"

echo ""
echo -e "  ${BOLD}Próximos passos:${RESET}"
echo -e "    ${CYAN}1.${RESET} Aplique o novo shell:       exec zsh"
echo -e "    ${CYAN}2.${RESET} Configure Powerlevel10k:    p10k configure"
echo -e "    ${CYAN}3.${RESET} Configure Git:              git config --global user.name 'Seu Nome'"
echo -e "    ${CYAN}4.${RESET} Autentique GitHub CLI:      gh auth login"
echo -e "    ${CYAN}5.${RESET} Clone seus projetos:        cd ~/projects && bash migrate-project.sh"
echo -e "    ${CYAN}6.${RESET} Abra no VS Code via WSL:    cd ~/projects/brisausa && code ."
echo ""
echo -e "  ${YELLOW}⚠${RESET}  Se o Docker não iniciar, execute: sudo service docker start"
echo -e "  ${YELLOW}⚠${RESET}  Para aplicar o grupo docker sem relogar: newgrp docker"
echo ""
