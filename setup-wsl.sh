#!/usr/bin/env bash
# =============================================================================
#  WSL2 Development Environment Setup
#  Ubuntu 24.04 LTS — Idempotent, sempre instala versões mais recentes
#
#  O que instala:
#    - Docker Engine (sem Docker Desktop — mais leve e mais rápido)
#    - nvm + Node.js LTS
#    - PHP 8.4 + Composer
#    - Lando CLI (Linux nativo)
#    - Claude Code CLI
#    - GitHub CLI
#    - Zsh + Oh My Zsh + Powerlevel10k + plugins
#    - Git configurado para WSL
#
#  O que configura:
#    - ~/.shell_local_exports.sh — PATH/aliases/hooks, fonte única lida por
#      bash E zsh (evita divergência entre os dois shells)
#    - ~/.bashrc  — carrega o arquivo acima antes do early-return de shell
#      não-interativo, para que Claude Code, pre-commit e tarefas disparadas
#      por um bash de login achem node/php/lando
#    - ~/.zshrc   — Oh My Zsh + Powerlevel10k, carregando a mesma fonte única
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
NODE_FALLBACK="${NODE_FALLBACK:-24}"   # usado se `nvm install --lts` falhar
# PHP 8.4: security support até 31/12/2028. A 8.3 entrou em security-only e
# expira em 31/12/2027 — não faz sentido nascer com ela num setup novo.
PHP_VERSION="${PHP_VERSION:-8.4}"
SKIP_ZSH="${SKIP_ZSH:-0}"              # 1 = não instala Zsh/Oh My Zsh/Powerlevel10k
INSTALL_PRODTOOLS="${INSTALL_PRODTOOLS:-1}"  # CLIs de produtividade/IaC/segurança
GH_AUTH_PROMPT="${GH_AUTH_PROMPT:-1}"  # 0 = nunca oferece `gh auth login`

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

# Detecta a release em vez de assumir 24.04: o ppa:ondrej/php e o repo do
# Docker publicam por codename, então uma 26.04 recém-instalada funciona sem
# editar o script — mas avisamos se o codename for mais novo que o suportado.
#
# Lê /etc/os-release, não `lsb_release`: o pacote lsb-release só é instalado no
# passo 2, depois desta verificação.
UBUNTU_RELEASE="$( (. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-0}") || echo 0 )"
UBUNTU_MAJOR="${UBUNTU_RELEASE%%.*}"
UBUNTU_CODENAME="$( (. /etc/os-release 2>/dev/null && echo "${VERSION_CODENAME:-desconhecido}") || echo desconhecido )"
if [ "$UBUNTU_MAJOR" -ge 26 ] 2>/dev/null; then
    ok "Ubuntu ${UBUNTU_RELEASE} (${UBUNTU_CODENAME}) detectado"
    warn "Testado em 24.04/26.04. Se um repo apt não tiver ${UBUNTU_CODENAME} ainda, o passo falha e o script segue."
elif [ "$UBUNTU_MAJOR" -ge 24 ] 2>/dev/null; then
    ok "Ubuntu ${UBUNTU_RELEASE} (${UBUNTU_CODENAME}) detectado"
elif [ "$UBUNTU_MAJOR" != "0" ]; then
    warn "Ubuntu ${UBUNTU_RELEASE} é anterior ao 24.04 LTS — recomendado atualizar"
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
    python3 \
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
    # `--lts` resolve o alias remoto lts/*. Se a rede/API do nodejs.org estiver
    # fora, cai numa versão LTS conhecida em vez de abortar o setup inteiro.
    if nvm install --lts; then
        nvm use --lts
        nvm alias default 'lts/*'
    else
        warn "nvm install --lts falhou — tentando Node ${NODE_FALLBACK}"
        nvm install "$NODE_FALLBACK"
        nvm use "$NODE_FALLBACK"
        nvm alias default "$NODE_FALLBACK"
    fi
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

# Checa o binário versionado (php8.4), não só `php`: numa máquina que já tinha
# PHP 8.3 o teste antigo (PHP_MAJOR_VERSION >= 8) passava e a versão nova nunca
# era instalada — exatamente o caso de quem roda o script de novo pra migrar.
if ! has "php${PHP_VERSION}"; then
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

    ok "PHP instalado: $(php${PHP_VERSION} --version | head -1)"
else
    ok "PHP ${PHP_VERSION} já instalado: $(php${PHP_VERSION} --version | head -1)"
fi

# Aponta `php` para a versão pedida. Sem isso, uma máquina que já tinha 8.3
# continua resolvendo `php` → 8.3 mesmo depois de instalar a 8.4.
if has "php${PHP_VERSION}"; then
    sudo update-alternatives --set php "/usr/bin/php${PHP_VERSION}" 2>/dev/null \
        && ok "php → php${PHP_VERSION}" \
        || warn "não foi possível fixar o alternative do php (php ativo: $(php --version | head -1))"
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

# Composer é instalado "sempre a última" — sem pin de versão. Uma release
# quebrada deixaria um binário que não roda, e o erro só apareceria no primeiro
# `composer install` de um projeto. Verificamos aqui.
if composer --version 2>/dev/null | grep -q "Composer version"; then
    ok "Composer funcional"
else
    fail "Composer instalado mas não responde a --version"
    warn "Reinstale: sudo rm -f /usr/local/bin/composer && bash setup-wsl.sh"
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

# Autenticar agora, não no fim: o passo 13b baixa gitleaks/tflint/k9s/... via
# `gh api`, e sem token esses binários eram silenciosamente pulados na primeira
# execução — o usuário só descobria ao tentar usá-los.
# Só pergunta em terminal interativo, para não travar o bootstrap automático
# feito pelo setup-windows.ps1 / setup-zorin-apps.sh.
if has gh; then
    if gh auth status &>/dev/null; then
        ok "GitHub CLI já autenticado"
    elif [ "$GH_AUTH_PROMPT" = "1" ] && [ -t 0 ]; then
        echo ""
        info "O GitHub CLI autenticado permite baixar gitleaks, tflint, k9s e afins."
        # `|| true`: um EOF no stdin faz o read retornar não-zero e, com
        # `set -e`, derrubaria o script inteiro por causa de um prompt opcional
        _gh_answer=""
        read -r -p "  Autenticar agora com 'gh auth login'? [Y/n] " _gh_answer || true
        case "${_gh_answer:-Y}" in
            [Nn]*) warn "Pulado — rode 'gh auth login' depois e re-execute o script" ;;
            *)     gh auth login && ok "GitHub CLI autenticado" \
                       || warn "Autenticação não concluída — rode 'gh auth login' depois" ;;
        esac
    else
        warn "GitHub CLI sem autenticação — rode 'gh auth login' depois"
    fi
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

# ── 8b. Shell base: fonte única para bash e zsh ──────────────────────────────
#
# O problema: o setup deixava PATH, aliases e o carregamento do nvm só no
# ~/.zshrc. Quem abre o terminal como usuário nunca nota, mas qualquer coisa
# que rode por um bash não-interativo — Claude Code, hooks de pre-commit,
# tarefas de CI local — herda um PATH sem node, sem lando e sem ~/.local/bin,
# e falha com "command not found" em ferramentas que estão instaladas.
#
# A solução: um único ~/.shell_local_exports.sh, em sh portável, carregado
# tanto pelo ~/.bashrc quanto pelo ~/.zshrc. Editar num lugar vale nos dois.
step "Configurando shell base (~/.shell_local_exports.sh)..."

# `|| true` obrigatório: sob `set -e`, um `[ -f X ] && cp` que dá falso encerra
# o script — e numa máquina limpa o arquivo justamente não existe.
[ -f "$HOME/.shell_local_exports.sh" ] && \
    cp "$HOME/.shell_local_exports.sh" "$HOME/.shell_local_exports.sh.backup.$(date +%s)" || true

# Escrito via python3 pelo mesmo motivo do .zshrc: garante LF e UTF-8 mesmo
# quando o script foi clonado no Windows com autocrlf=true.
python3 - "$HOME" << 'PYEOF'
import sys, os

home = sys.argv[1]
path = os.path.join(home, ".shell_local_exports.sh")

content = r'''#!/bin/sh
# =============================================================================
#  ~/.shell_local_exports.sh — fonte unica de PATH, aliases e hooks
#
#  Carregado por ~/.bashrc E ~/.zshrc. Escreva sh portavel aqui: sem arrays,
#  sem [[ ]], sem substituicao de string estilo bash. Coisas especificas de um
#  shell (completion, prompt) ficam no rc daquele shell.
#
#  Gerado por setup-wsl.sh — mudancas manuais sobrevivem em
#  ~/.shell_local_exports.sh.backup.<timestamp>, mas sao sobrescritas na
#  proxima execucao. Preferencias pessoais: use ~/.shell_local_custom.sh
#  (carregado no fim deste arquivo e nunca sobrescrito pelo setup).
# =============================================================================

# === PATH =====================================================================
# Binarios de release instalados sem sudo (gitleaks, tflint, k9s, ...)
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac

# Lando instala em ~/.lando/bin pelo setup-lando.sh oficial (WSL/Linux)
case ":$PATH:" in
    *":$HOME/.lando/bin:"*) ;;
    *) PATH="$HOME/.lando/bin:$PATH" ;;
esac

# Composer global (vendor/bin de pacotes instalados com `composer global`)
if [ -d "$HOME/.config/composer/vendor/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.config/composer/vendor/bin:"*) ;;
        *) PATH="$HOME/.config/composer/vendor/bin:$PATH" ;;
    esac
fi

export PATH

# === nvm ======================================================================
# Precisa vir daqui, e nao so do .zshrc: sem isso um `bash -lc "node -v"`
# (padrao de ferramentas que disparam comandos) nao acha o node.
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    # `\.` escapa um eventual alias de `.`. nvm.sh referencia variaveis nao
    # inicializadas: se o chamador ligou `set -u` (script com `set -euo
    # pipefail` que carrega este arquivo), desligamos so durante o carregamento
    # e restauramos o estado original depois.
    case $- in
        *u*) _had_nounset=1; set +u ;;
          *) _had_nounset=0 ;;
    esac
    \. "$NVM_DIR/nvm.sh"
    [ "$_had_nounset" = 1 ] && set -u
    unset _had_nounset
fi

# === Editor ===================================================================
# Respeita um EDITOR ja exportado; senao prefere o VS Code (que no WSL abre no
# Windows via `code`) e cai no nano em maquina sem GUI.
if [ -z "${EDITOR:-}" ]; then
    if command -v code >/dev/null 2>&1; then
        EDITOR="code"
    else
        EDITOR="nano"
    fi
fi
export EDITOR

# === Navegacao ================================================================
alias dev="cd ~/projects"
alias la="ls -lah --color=auto"
alias ll="ls -lh --color=auto"

# === Git ======================================================================
alias gs="git status"
alias gco="git checkout"
alias gpl="git pull --recurse-submodules"
alias gps="git push"
alias gcm="git commit -m"

# === Docker ===================================================================
alias dcu="docker compose up"
alias dcd="docker compose down"
alias dcl="docker compose logs -f"
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# === Lando ====================================================================
alias lup="lando start"
alias ldn="lando stop"
alias ldev="lando dev"
alias lbuild="lando theme-build"
alias lflush="lando flush"
alias lacorn="lando acorn"
alias lssh="lando ssh"

# === Claude Code ==============================================================
alias cc="claude"

# === CLI moderna (instalada por INSTALL_PRODTOOLS=1) ==========================
# No Ubuntu os binarios tem nome com sufixo pra nao colidir com pacotes antigos
command -v batcat >/dev/null 2>&1 && alias bat="batcat"
command -v fdfind >/dev/null 2>&1 && alias fd="fdfind"
# eza como comando extra, nao como shadow do `ls` — sobrescrever `ls` quebra
# flags que scripts e habitos assumem do coreutils
command -v eza >/dev/null 2>&1 && alias lz="eza --group-directories-first --icons"

# === Utilitarios ==============================================================
alias exports='$EDITOR ~/.shell_local_exports.sh'
alias custom='$EDITOR ~/.shell_local_custom.sh'

# === Hooks por shell ==========================================================
# direnv e zoxide geram codigo diferente pra bash e zsh — detectamos qual esta
# rodando. $ZSH_VERSION so existe no zsh; $BASH_VERSION so no bash.
if [ -n "${ZSH_VERSION:-}" ]; then
    _shell_name="zsh"
elif [ -n "${BASH_VERSION:-}" ]; then
    _shell_name="bash"
else
    _shell_name=""
fi

if [ -n "$_shell_name" ]; then
    command -v direnv >/dev/null 2>&1 && eval "$(direnv hook $_shell_name)"
    command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init $_shell_name)"
    command -v mise   >/dev/null 2>&1 && eval "$(mise activate $_shell_name)"
fi
unset _shell_name

# === Customizacoes do usuario =================================================
# Este arquivo nunca e sobrescrito pelo setup-wsl.sh — coloque suas coisas aqui
[ -f "$HOME/.shell_local_custom.sh" ] && \. "$HOME/.shell_local_custom.sh"

# Ultima linha deliberada: sem ela, o `[ -f ... ]` falso acima viraria o status
# de saida deste arquivo, e um chamador com `set -e` abortaria ao carrega-lo.
:
'''

with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(content)

print(f"  escrito: {path} ({content.count(chr(10))} linhas, LF, UTF-8)")
PYEOF
ok "~/.shell_local_exports.sh configurado"

# ── 8c. ~/.bashrc — bash tambem precisa achar as ferramentas ──────────────────
#
# O .bashrc padrão do Ubuntu aborta na primeira linha quando não-interativo
# ("case $- in *i*) ;; *) return;; esac"), então o source do nosso arquivo
# precisa vir ANTES desse early-return — apender no fim não resolveria nada.
#
# Não sobrescrevemos um .bashrc que não foi gerado por nós: o
# `ssh-git-setup.sh`, por exemplo, apenda o SSH_AUTH_SOCK do 1Password ali.
# Nesse caso só injetamos o bloco gerenciado no topo e preservamos o resto.
step "Configurando ~/.bashrc..."

[ -f "$HOME/.bashrc" ] && cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$(date +%s)" || true

python3 - "$HOME" << 'PYEOF'
import sys, os

home = sys.argv[1]
path = os.path.join(home, ".bashrc")

# Dois blocos gerenciados, porque eles precisam de posicoes diferentes:
#
#   TOP  — antes do early-return de shell nao-interativo. A cadeia de login
#          (bash -l -> ~/.profile -> ~/.bashrc) e como Claude Code, pre-commit
#          e afins resolvem node/php/lando; depois do early-return nada disso
#          seria carregado.
#   BOT  — no fim do arquivo. Prompt, historico e completion so fazem sentido
#          em shell interativo, e o early-return do proprio .bashrc do Ubuntu
#          garante que essa parte nem seja lida fora dele.
TOP_START = "# >>> setup-wsl.sh managed (exports) >>>"
TOP_END   = "# <<< setup-wsl.sh managed (exports) <<<"
BOT_START = "# >>> setup-wsl.sh managed (interativo) >>>"
BOT_END   = "# <<< setup-wsl.sh managed (interativo) <<<"

top = f'''{TOP_START}
# Fonte unica de PATH/aliases/hooks, compartilhada com o ~/.zshrc.
# Nao edite este bloco: ele e reescrito a cada execucao do setup-wsl.sh.
# Aliases e PATH vao em ~/.shell_local_exports.sh; coisas suas, em
# ~/.shell_local_custom.sh (que o setup nunca sobrescreve).
[ -f "$HOME/.shell_local_exports.sh" ] && . "$HOME/.shell_local_exports.sh"
{TOP_END}'''

bottom = f'''{BOT_START}
# Nao edite este bloco: ele e reescrito a cada execucao do setup-wsl.sh.
''' + r'''
# === Historico ================================================================
HISTCONTROL=ignoreboth       # nao grava duplicatas nem linhas com espaco na frente
HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT="%F %T "
shopt -s histappend          # varias sessoes nao sobrescrevem o historico
shopt -s checkwinsize        # recalcula LINES/COLUMNS ao redimensionar
shopt -s globstar 2>/dev/null || true   # ** recursivo

# === Completion ===============================================================
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# nvm e gh trazem completion propria
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
command -v gh >/dev/null 2>&1 && eval "$(gh completion -s bash)" 2>/dev/null

# === Prompt com branch do git =================================================
# Usa __git_ps1 quando o bash-completion do git esta disponivel (mais rapido e
# lida com rebase/merge em andamento); cai num `git symbolic-ref` se nao.
if declare -f __git_ps1 >/dev/null 2>&1; then
    _prompt_git() { __git_ps1 " (%s)"; }
else
    _prompt_git() {
        local b
        b=$(git symbolic-ref --short HEAD 2>/dev/null) || return 0
        printf " (%s)" "$b"
    }
fi

if [ -n "${debian_chroot:-}" ]; then
    _chroot_prefix="($debian_chroot)"
else
    _chroot_prefix=""
fi

case "$TERM" in
    xterm-color|*-256color|xterm-kitty|screen*|tmux*)
        PS1='${_chroot_prefix}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\[\033[01;33m\]$(_prompt_git)\[\033[00m\]\$ '
        ;;
    *)
        PS1='${_chroot_prefix}\u@\h:\w$(_prompt_git)\$ '
        ;;
esac

# Titulo da janela com o diretorio atual
case "$TERM" in
    xterm*|rxvt*|screen*|tmux*)
        PS1="\[\e]0;${_chroot_prefix}\u@\h: \w\a\]$PS1"
        ;;
esac

# === Cores ====================================================================
if [ -x /usr/bin/dircolors ]; then
    test -r "$HOME/.dircolors" && eval "$(dircolors -b "$HOME/.dircolors")" \
        || eval "$(dircolors -b)"
    alias grep="grep --color=auto"
fi
''' + f'''{BOT_END}
'''

# Esqueleto usado so quando nao existe .bashrc nenhum: o early-return no meio
# separa o bloco TOP (sempre) do BOT (so interativo).
skeleton = f'''# =============================================================================
#  ~/.bashrc — gerado por setup-wsl.sh
# =============================================================================

{top}

# === Daqui pra baixo, so shell interativo ====================================
case $- in
    *i*) ;;
      *) return ;;
esac

{bottom}'''


def strip_block(text, start, end):
    """Remove um bloco delimitado, se presente. Idempotencia entre execucoes."""
    while start in text and end in text:
        head, _, rest = text.partition(start)
        _, _, tail = rest.partition(end)
        text = head.rstrip("\n") + "\n" + tail.lstrip("\n")
    return text


def write(text, note):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"  {note}: {path} ({text.count(chr(10))} linhas, LF, UTF-8)")


if not os.path.exists(path):
    write(skeleton, "escrito")
else:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        existing = f.read()

    had_blocks = TOP_START in existing

    # Tira as versoes antigas dos nossos blocos e recoloca nas posicoes certas.
    # O que sobra no meio e config de terceiro — o .bashrc default do Ubuntu, ou
    # linhas apendadas pelo ssh-git-setup.sh (SSH_AUTH_SOCK do 1Password) — e
    # atravessa intacta.
    body = strip_block(existing, TOP_START, TOP_END)
    body = strip_block(body, BOT_START, BOT_END)
    body = body.strip("\n")

    write(f"{top}\n\n{body}\n\n{bottom}",
          "blocos atualizados em" if had_blocks else "blocos inseridos em")

    if not had_blocks:
        print("  (config existente preservada — backup em ~/.bashrc.backup.*)")
PYEOF
ok "~/.bashrc configurado"

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

# Backup do .zshrc existente (`|| true`: sob `set -e` o teste falso abortaria)
[ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%s)" || true

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
    "# === Fonte unica (bash + zsh) =================================================\n"
    "# PATH, nvm, aliases e hooks vivem em ~/.shell_local_exports.sh, carregado\n"
    "# tambem pelo ~/.bashrc. Edite lah, nao aqui -- assim bash e zsh nunca\n"
    "# divergem, e ferramentas disparadas por um bash de login (Claude Code,\n"
    "# pre-commit) veem exatamente o mesmo ambiente que o seu terminal.\n"
    "# Vem DEPOIS do oh-my-zsh.sh de proposito: os plugins do OMZ definem aliases\n"
    "# proprios (ex.: `gcm` no plugin git) e os nossos precisam ganhar.\n"
    '[ -f "$HOME/.shell_local_exports.sh" ] && source "$HOME/.shell_local_exports.sh"\n\n'
    "# === Completion especifica do zsh =============================================\n"
    '[ -s "$NVM_DIR/bash_completion" ] && \\. "$NVM_DIR/bash_completion"\n\n'
    "# === Utilitarios ==============================================================\n"
    'alias reload="source ~/.zshrc"\n'
    "alias zshrc='$EDITOR ~/.zshrc'\n"
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

# ── 13b. Ferramentas de produtividade / IaC / segurança ──────────────────────
#  Tudo nativo (apt + binários de release em ~/.local/bin). Sem flatpak/snap.
#   • Segredos/hooks: gitleaks (defesa-em-profundidade p/ "zero segredo no repo")
#   • Shell/dev:      direnv, zoxide, mise, shellcheck, shfmt, pre-commit
#   • IaC/segurança:  tflint, trivy, infracost, terraform-docs, actionlint
#   • CLI moderna:    eza, bat, ripgrep, fd-find, k9s, lazydocker
if [ "$INSTALL_PRODTOOLS" = "1" ]; then
    step "Ferramentas de produtividade (CLI)..."
    # apt: o que o Ubuntu/Zorin 24.04 já empacota
    apt_install direnv shellcheck shfmt pre-commit zoxide bat ripgrep \
        fd-find eza trivy unzip
    ok "apt: direnv shellcheck shfmt pre-commit zoxide bat ripgrep fd-find eza trivy"

    # mise — repo apt oficial (gerenciador de runtimes por projeto)
    if ! has mise; then
        sudo install -dm 755 /etc/apt/keyrings
        wget -qO - https://mise.jdx.dev/gpg-key.pub \
            | gpg --dearmor | sudo tee /etc/apt/keyrings/mise-archive-keyring.gpg >/dev/null
        echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" \
            | sudo tee /etc/apt/sources.list.d/mise.list >/dev/null
        sudo apt-get update -qq && apt_install mise && ok "mise instalado" || warn "mise falhou"
    else
        ok "mise já instalado"
    fi

    # Binários de release → ~/.local/bin (sem sudo). Requer gh autenticado.
    mkdir -p "$HOME/.local/bin"
    _ftbin() { # repo  grep_pattern  binname  [inner]
        local repo="$1" pat="$2" name="$3" inner="${4:-$3}" url tmp f
        if has "$name" || [ -x "$HOME/.local/bin/$name" ]; then ok "$name já instalado"; return; fi
        url=$(gh api "repos/$repo/releases/latest" \
              --jq '.assets[] | "\(.name) \(.browser_download_url)"' 2>/dev/null \
              | grep -E "$pat" | awk '{print $2}' | head -1)
        [ -z "$url" ] && { warn "$name: asset não encontrado (gh autenticado?)"; return; }
        tmp=$(mktemp -d)
        ( cd "$tmp" || exit
          curl -fsSL "$url" -o pkg
          case "$url" in *.zip) unzip -q pkg ;; *) tar xzf pkg ;; esac
          f=$(find . -type f -name "$inner" | head -1)
          [ -z "$f" ] && f=$(find . -type f -name "*${name}*" ! -name pkg | head -1)
          [ -n "$f" ] && install -m755 "$f" "$HOME/.local/bin/$name" && ok "$name" || warn "$name: binário ausente no pacote"
        )
        rm -rf "$tmp"
    }
    if has gh; then
        _ftbin gitleaks/gitleaks             'linux_x64\.tar\.gz'    gitleaks
        _ftbin rhysd/actionlint              'linux_amd64\.tar\.gz'  actionlint
        _ftbin terraform-linters/tflint      'linux_amd64\.zip'      tflint
        _ftbin infracost/infracost           'infracost-linux-amd64\.tar\.gz' infracost infracost-linux-amd64
        _ftbin terraform-docs/terraform-docs 'linux-amd64\.tar\.gz'  terraform-docs
        _ftbin derailed/k9s                  'k9s_Linux_amd64\.tar\.gz' k9s
        _ftbin jesseduffield/lazydocker      'Linux_x86_64\.tar\.gz' lazydocker
    else
        warn "gh ausente — pulei binários de release (gitleaks/tflint/k9s/...). Rode após 'gh auth login'."
    fi
fi

# ── 14. Resumo final ─────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}"
cat << 'SUMMARY'
  ╔══════════════════════════════════════════════════════╗
  ║              WSL2 Setup Concluído!                 ║
  ╚══════════════════════════════════════════════════════╝
SUMMARY
echo -e "${RESET}"

# Cada linha termina em `|| true`: com `set -e`, uma ferramenta ausente fazia a
# lista `has X && echo` retornar não-zero e abortava o resumo pela metade —
# justo no caso em que o resumo é mais útil.
echo -e "  Versões instaladas:"
has node     && echo -e "    ${GREEN}✔${RESET} Node.js:    $(node --version)" || true
has npm      && echo -e "    ${GREEN}✔${RESET} npm:        $(npm --version)" || true
has php      && echo -e "    ${GREEN}✔${RESET} PHP:        $(php --version | head -1 | cut -d' ' -f1-2)" || true
has composer && echo -e "    ${GREEN}✔${RESET} Composer:   $(composer --version 2>/dev/null | cut -d' ' -f1-3)" || true
has docker   && echo -e "    ${GREEN}✔${RESET} Docker:     $(docker --version 2>/dev/null | cut -d',' -f1)" || true
has lando    && echo -e "    ${GREEN}✔${RESET} Lando:      $(lando version 2>/dev/null || echo 'instalado')" || true
has gh       && echo -e "    ${GREEN}✔${RESET} GitHub CLI: $(gh --version 2>/dev/null | head -1 | cut -d' ' -f1-3)" || true
has claude   && echo -e "    ${GREEN}✔${RESET} Claude Code: instalado" || true
has zsh      && echo -e "    ${GREEN}✔${RESET} Zsh:        $(zsh --version)" || true

echo ""
echo -e "  Configuração de shell:"
echo -e "    ${GREEN}✔${RESET} ~/.shell_local_exports.sh  (PATH, aliases, hooks — bash + zsh)"
echo -e "    ${GREEN}✔${RESET} ~/.bashrc                  (carrega o arquivo acima)"
if [ "$SKIP_ZSH" != "1" ]; then
echo -e "    ${GREEN}✔${RESET} ~/.zshrc                   (Oh My Zsh + P10k + o arquivo acima)"
fi
echo -e "    ${BOLD}→${RESET} Suas customizações:        ~/.shell_local_custom.sh (nunca sobrescrito)"

echo ""
echo -e "  ${BOLD}Próximos passos:${RESET}"
echo -e "    ${CYAN}•${RESET} Valide a instalação:        bash validate-env.sh"
if [ "$SKIP_ZSH" != "1" ]; then
echo -e "    ${CYAN}•${RESET} Aplique o novo shell:       exec zsh"
echo -e "    ${CYAN}•${RESET} Configure Powerlevel10k:    p10k configure"
fi
echo -e "    ${CYAN}•${RESET} Configure Git:              git config --global user.name 'Seu Nome'"
if has gh && ! gh auth status &>/dev/null; then
echo -e "    ${CYAN}•${RESET} Autentique GitHub CLI:      gh auth login"
fi
echo -e "    ${CYAN}•${RESET} Clone seus projetos:        cd ~/projects && bash migrate-project.sh"
echo -e "    ${CYAN}•${RESET} Abra no VS Code:            cd ~/projects/SEU_PROJETO && code ."
echo ""
echo -e "  ${YELLOW}⚠${RESET}  Se o Docker não iniciar, execute: sudo service docker start"
echo -e "  ${YELLOW}⚠${RESET}  Para aplicar o grupo docker sem relogar: newgrp docker"
echo -e "  ${YELLOW}⚠${RESET}  Abra um novo terminal para carregar PATH e aliases"
echo ""
