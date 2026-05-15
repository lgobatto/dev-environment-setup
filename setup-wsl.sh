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
SKIP_ZSH="${SKIP_ZSH:-0}"              # 1 = não instala Zsh/Oh My Zsh/Powerlevel10k

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

# ── 1. Habilitar systemd no WSL2 (necessário para Docker autostart) ──────────
#  Em Linux nativo (Zorin/Ubuntu) o systemd já é PID 1 e /etc/wsl.conf é
#  ignorado pelo kernel — esse passo só faz sentido dentro do WSL2.
step "Verificando ambiente..."
if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
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
else
    ok "Linux nativo (não-WSL) — /etc/wsl.conf não é necessário"
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
    socat jq \
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

# nvm usa variáveis internas não inicializadas — desabilitar nounset temporariamente
# para evitar "unbound variable" com set -u ativo
set +u

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

set -u

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
# A partir da v3.21, Lando não distribui mais via .deb no GitHub releases.
# Método oficial para WSL2: https://docs.lando.dev/install/wsl.html
#   - Instala em ~/.lando/bin/lando (sem sudo)
#   - Requer `eval "$(lando shellenv)"` para configurar PATH + shell integration
#
LANDO_BIN="$HOME/.lando/bin/lando"

if [ -f "$LANDO_BIN" ] || has lando; then
    ok "Lando já instalado: $(lando version 2>/dev/null || $LANDO_BIN version 2>/dev/null || echo 'versão desconhecida')"
else
    info "Baixando setup-lando.sh..."
    curl -fsSL https://get.lando.dev/setup-lando.sh -o /tmp/setup-lando.sh
    chmod +x /tmp/setup-lando.sh

    # --yes pula a confirmação interativa; --dest instala em ~/.lando/bin
    bash /tmp/setup-lando.sh --yes --dest "$HOME/.lando/bin" 2>&1
    rm -f /tmp/setup-lando.sh

    if [ -f "$LANDO_BIN" ]; then
        # Adicionar ao PATH desta sessão para usar lando imediatamente
        export PATH="$HOME/.lando/bin:$PATH"
        ok "Lando instalado: $($LANDO_BIN version 2>/dev/null || echo 'v3.x')"
    else
        fail "Lando não foi instalado corretamente"
        warn "Instale manualmente: /bin/bash -c \"\$(curl -fsSL https://get.lando.dev/setup-lando.sh)\""
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
if [ "$SKIP_ZSH" = "1" ]; then
    step "Zsh — pulado (SKIP_ZSH=1)"
    ok "Zsh não será instalado"
else
step "Configurando Zsh + Oh My Zsh + Powerlevel10k..."
apt_install zsh
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
fi

# ── 10. Configurar .zshrc ─────────────────────────────────────────────────────
if [ "$SKIP_ZSH" != "1" ]; then
step "Configurando .zshrc..."

# Backup do .zshrc existente
[ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%s)"

# Usar Python para escrever o .zshrc — evita problemas de CRLF (script pode ter
# vindo do Windows) e de escaping em heredocs com caracteres Unicode.

python3 - "$HOME" << 'PYEOF'
import sys, os

home  = sys.argv[1]
zshrc = os.path.join(home, ".zshrc")

content = (
    "# Powerlevel10k instant prompt -- deve ficar no topo do .zshrc\n"
    'if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then\n'
    '    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"\n'
    "fi\n\n"
    "# === Oh My Zsh ================================================================\n"
    'export ZSH="$HOME/.oh-my-zsh"\n'
    'ZSH_THEME="powerlevel10k/powerlevel10k"\n\n'
    "plugins=(\n"
    "    git\n    docker\n    docker-compose\n    npm\n    composer\n"
    "    zsh-autosuggestions\n    zsh-syntax-highlighting\n    zsh-completions\n"
    ")\n\n"
    "source $ZSH/oh-my-zsh.sh\n\n"
    "# === nvm ======================================================================\n"
    'export NVM_DIR="$HOME/.nvm"\n'
    '[ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"\n'
    '[ -s "$NVM_DIR/bash_completion" ] && \\. "$NVM_DIR/bash_completion"\n\n'
    "# === Lando ====================================================================\n"
    '# Instalado em ~/.lando/bin pelo setup-lando.sh oficial (WSL/Linux)\n'
    'export PATH="$HOME/.lando/bin:$PATH"\n\n'
    "# === Navegacao ================================================================\n"
    'alias dev="cd ~/projects"\n'
    'alias la="ls -lah --color=auto"\n'
    'alias ll="ls -lh --color=auto"\n\n'
    "# === Git ======================================================================\n"
    'alias gs="git status"\n'
    'alias gco="git checkout"\n'
    'alias gpl="git pull --recurse-submodules"\n'
    'alias gps="git push"\n'
    'alias gcm="git commit -m"\n\n'
    "# === Docker ===================================================================\n"
    'alias dcu="docker compose up"\n'
    'alias dcd="docker compose down"\n'
    'alias dcl="docker compose logs -f"\n'
    "alias dps=\"docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'\"\n\n"
    "# === Lando aliases ============================================================\n"
    'alias lup="lando start"\n'
    'alias ldn="lando stop"\n'
    'alias ldev="lando dev"\n'
    'alias lbuild="lando theme-build"\n'
    'alias lflush="lando flush"\n'
    'alias lacorn="lando acorn"\n'
    'alias lssh="lando ssh"\n\n'
    "# === Claude Code ==============================================================\n"
    'alias cc="claude"\n\n'
    "# === Utilitarios ==============================================================\n"
    'alias reload="source ~/.zshrc"\n'
    'alias zshrc="code ~/.zshrc"\n'
    "\n# === Powerlevel10k ============================================================\n"
    "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh\n"
)

with open(zshrc, "w", encoding="utf-8", newline="\n") as f:
    f.write(content)

print(f"  .zshrc escrito: {zshrc} ({content.count(chr(10))} linhas, LF, UTF-8)")
PYEOF
ok ".zshrc configurado"
fi

# 1Password SSH Agent — abordagem oficial para WSL2
# Ref: https://developer.1password.com/docs/ssh/integrations/wsl
#
# Nao usa socket nem npiperelay. O Git no WSL delega o SSH diretamente
# ao ssh.exe do Windows, que ja tem acesso ao 1Password SSH Agent via
# Windows OpenSSH Agent service (pipe \\.\pipe\openssh-ssh-agent).
#
if [ "$INSTALL_1PASSWORD" = "1" ]; then
    # Configurar Git para usar ssh.exe do Windows (acessa 1Password diretamente)
    git config --global core.sshCommand "ssh.exe"
    ok "git core.sshCommand = ssh.exe (1Password SSH Agent via Windows OpenSSH)"
    warn "Certifique-se que o servico 'OpenSSH Authentication Agent' esta ativo no Windows"
    warn "Habilite em: 1Password > Settings > Developer > Use the SSH Agent"
fi

# ── 11. Definir Zsh como shell padrão ────────────────────────────────────────
if [ "$SKIP_ZSH" = "1" ]; then
    step "Shell padrão — mantido (SKIP_ZSH=1)"
else
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
if [ "$SKIP_ZSH" != "1" ]; then
echo -e "    ${CYAN}•${RESET} Aplique o novo shell:       exec zsh"
echo -e "    ${CYAN}•${RESET} Configure Powerlevel10k:    p10k configure"
fi
echo -e "    ${CYAN}•${RESET} Configure Git:              git config --global user.name 'Seu Nome'"
echo -e "    ${CYAN}•${RESET} Autentique GitHub CLI:      gh auth login"
echo -e "    ${CYAN}•${RESET} Clone seus projetos:        cd ~/projects && bash migrate-project.sh"
echo -e "    ${CYAN}•${RESET} Abra no VS Code:            cd ~/projects/SEU_PROJETO && code ."
echo ""
echo -e "  ${YELLOW}⚠${RESET}  Se o Docker não iniciar, execute: sudo service docker start"
echo -e "  ${YELLOW}⚠${RESET}  Para aplicar o grupo docker sem relogar: newgrp docker"
echo ""
