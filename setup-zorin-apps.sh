#!/usr/bin/env bash
# =============================================================================
#  Zorin OS / Ubuntu — Apps GUI
#  Equivalentes Linux do antigo script Chocolatey + apps do setup-windows.ps1.
#  Idempotente — seguro para re-executar.
#
#  apt repo oficial : VS Code, Google Chrome, Warp, PowerShell 7
#  apt              : Java 8 (openjdk-8-jre), 1Password CLI (op)
#  .deb nativo      : GitKraken, DBeaver, GitHub Desktop
#  flatpak (flathub): Firefox, Discord, Spotify, Postman
#  Nerd Fonts       : delega para ./nerdfonts-install.sh
#  CLIs de dev      : delega para ./setup-wsl.sh (Docker, Node, PHP, Composer,
#                     Lando, gh, Claude Code — idênticos em Zorin/Ubuntu nativo)
#  CLIs cloud/infra : aws, terraform, wrangler, doctl, glab
#
#  Por que GitKraken/DBeaver/GitHub Desktop NÃO usam Flatpak: ferramentas de
#  dev precisam de acesso direto a ~/.ssh, ao SSH agent e às pastas de projeto;
#  o sandbox do Flatpak bloqueia isso por padrão. .deb nativo evita o atrito.
#
#  Uso:
#    bash setup-zorin-apps.sh
#
#  Pula qualquer app via env var (=0):
#    INSTALL_DISCORD=0 INSTALL_SPOTIFY=0 bash setup-zorin-apps.sh
# =============================================================================

set -euo pipefail

# ── Flags (1 = instala, 0 = pula) ────────────────────────────────────────────
INSTALL_VSCODE="${INSTALL_VSCODE:-1}"
INSTALL_CHROME="${INSTALL_CHROME:-1}"
INSTALL_FIREFOX="${INSTALL_FIREFOX:-1}"
INSTALL_WARP="${INSTALL_WARP:-1}"
INSTALL_POWERSHELL="${INSTALL_POWERSHELL:-1}"
INSTALL_GITKRAKEN="${INSTALL_GITKRAKEN:-1}"
INSTALL_GITHUBDESKTOP="${INSTALL_GITHUBDESKTOP:-1}"
INSTALL_DBEAVER="${INSTALL_DBEAVER:-1}"
INSTALL_DISCORD="${INSTALL_DISCORD:-1}"
INSTALL_SPOTIFY="${INSTALL_SPOTIFY:-1}"
INSTALL_POSTMAN="${INSTALL_POSTMAN:-1}"
INSTALL_OP_CLI="${INSTALL_OP_CLI:-1}"
INSTALL_JAVA8="${INSTALL_JAVA8:-1}"
INSTALL_FONTS="${INSTALL_FONTS:-1}"
INSTALL_WSL_CLIS="${INSTALL_WSL_CLIS:-1}"   # CLIs de dev via setup-wsl.sh
INSTALL_AWS="${INSTALL_AWS:-1}"
INSTALL_TERRAFORM="${INSTALL_TERRAFORM:-1}"
INSTALL_CLOUDFLARED="${INSTALL_CLOUDFLARED:-1}"   # SSH proxy + Cloudflare Tunnel
INSTALL_UV="${INSTALL_UV:-1}"                     # Python package manager (astral-sh/uv)
INSTALL_WRANGLER="${INSTALL_WRANGLER:-1}"
INSTALL_DOCTL="${INSTALL_DOCTL:-1}"
INSTALL_GLAB="${INSTALL_GLAB:-1}"
INSTALL_LANMOUSE="${INSTALL_LANMOUSE:-1}"   # lan-mouse (KVM nativo via cargo)

# ── Cores e helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}▶ $*${RESET}"; }
ok()    { echo -e "  ${GREEN}✔${RESET} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET} $*"; }
fail()  { echo -e "  ${RED}✖${RESET} $*" >&2; }
info()  { echo -e "  ${BOLD}→${RESET} $*"; }

has() { command -v "$1" &>/dev/null; }

apt_install() {
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" 2>/dev/null
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}${BOLD}"
cat << 'BANNER'
  ╔══════════════════════════════════════════════════════╗
  ║          Zorin OS — Apps GUI de desenvolvimento       ║
  ╚══════════════════════════════════════════════════════╝
BANNER
echo -e "${RESET}"

# ── 0. Dependências base ─────────────────────────────────────────────────────
step "Verificando dependências base..."
sudo apt-get update -qq
apt_install curl wget gnupg ca-certificates software-properties-common
ok "curl, wget, gnupg prontos"

# Garante a chave GPG da Microsoft (compartilhada por VS Code e PowerShell)
ensure_microsoft_key() {
    if [ ! -f /usr/share/keyrings/microsoft.gpg ]; then
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
            | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft.gpg > /dev/null
    fi
}

# ── 1. VS Code — repo oficial Microsoft ──────────────────────────────────────
if [ "$INSTALL_VSCODE" = "1" ]; then
    step "VS Code..."
    if has code; then
        ok "VS Code já instalado"
    else
        ensure_microsoft_key
        echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
            | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        sudo apt-get update -qq
        apt_install code
        ok "VS Code instalado"
    fi
fi

# ── 2. Google Chrome — repo oficial Google ───────────────────────────────────
if [ "$INSTALL_CHROME" = "1" ]; then
    step "Google Chrome..."
    if has google-chrome || has google-chrome-stable; then
        ok "Chrome já instalado"
    else
        wget -qO- https://dl.google.com/linux/linux_signing_key.pub \
            | sudo gpg --dearmor --yes -o /usr/share/keyrings/google-chrome.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
            | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
        sudo apt-get update -qq
        apt_install google-chrome-stable
        ok "Chrome instalado"
    fi
fi

# ── 3. Warp Terminal — repo oficial ──────────────────────────────────────────
if [ "$INSTALL_WARP" = "1" ]; then
    step "Warp Terminal..."
    if has warp-terminal; then
        ok "Warp já instalado"
    else
        wget -qO- https://releases.warp.dev/linux/keys/warp.asc \
            | sudo gpg --dearmor --yes -o /usr/share/keyrings/warpdotdev.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/warpdotdev.gpg] https://releases.warp.dev/linux/deb stable main" \
            | sudo tee /etc/apt/sources.list.d/warpdotdev.list > /dev/null
        sudo apt-get update -qq
        apt_install warp-terminal
        ok "Warp instalado"
    fi
fi

# ── 4. PowerShell 7 — repo prod oficial Microsoft ────────────────────────────
if [ "$INSTALL_POWERSHELL" = "1" ]; then
    step "PowerShell 7..."
    if has pwsh; then
        ok "PowerShell já instalado"
    else
        ensure_microsoft_key
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" \
            | sudo tee /etc/apt/sources.list.d/microsoft-prod.list > /dev/null
        sudo apt-get update -qq
        apt_install powershell
        ok "PowerShell instalado (comando: pwsh)"
    fi
fi

# ── 5. 1Password CLI (op) — repo oficial 1Password ───────────────────────────
if [ "$INSTALL_OP_CLI" = "1" ]; then
    step "1Password CLI (op)..."
    if has op; then
        ok "1Password CLI já instalado"
    else
        # Não cria o repo se o app 1Password já o configurou (1password.sources,
        # formato deb822). Criar 1password.list além do .sources gera aviso de
        # "configured multiple times" em todo apt update.
        if [ ! -f /etc/apt/sources.list.d/1password.list ] \
           && [ ! -f /etc/apt/sources.list.d/1password.sources ]; then
            curl -sS https://downloads.1password.com/linux/keys/1password.asc \
                | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" \
                | sudo tee /etc/apt/sources.list.d/1password.list > /dev/null
        fi
        sudo apt-get update -qq
        apt_install 1password-cli
        ok "1Password CLI instalado (comando: op)"
    fi
fi

# ── 6. Java 8 (jre8) ─────────────────────────────────────────────────────────
if [ "$INSTALL_JAVA8" = "1" ]; then
    step "Java 8 (openjdk-8-jre)..."
    if dpkg -l openjdk-8-jre 2>/dev/null | grep -q "^ii"; then
        ok "openjdk-8-jre já instalado"
    else
        apt_install openjdk-8-jre
        ok "openjdk-8-jre instalado"
    fi
fi

# ── 7. GitKraken + DBeaver — .deb nativo ─────────────────────────────────────
#  .deb nativo (não Flatpak): acesso direto a ~/.ssh, SSH agent e projetos.
deb_install_url() {
    # baixa um .deb e instala resolvendo dependências via apt
    local url="$1" label="$2"
    local tmp; tmp="$(mktemp --suffix=.deb)"
    if curl -fSL "$url" -o "$tmp"; then
        apt_install "$tmp" && ok "$label instalado" || warn "$label falhou"
    else
        warn "$label: download falhou ($url)"
    fi
    rm -f "$tmp"
}

if [ "$INSTALL_GITKRAKEN" = "1" ]; then
    step "GitKraken (.deb)..."
    if has gitkraken; then
        ok "GitKraken já instalado"
    else
        deb_install_url "https://release.gitkraken.com/linux/gitkraken-amd64.deb" "GitKraken"
    fi
fi

if [ "$INSTALL_DBEAVER" = "1" ]; then
    step "DBeaver Community (.deb)..."
    if has dbeaver; then
        ok "DBeaver já instalado"
    else
        deb_install_url "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb" "DBeaver Community"
    fi
fi

# ── 8. GitHub Desktop — .deb da release (build comunidade shiftkey/desktop) ──
#  O repo apt apt.packages.shiftkey.dev tem certificado SSL quebrado; baixamos
#  o .deb mais recente direto da API de releases do GitHub.
if [ "$INSTALL_GITHUBDESKTOP" = "1" ]; then
    step "GitHub Desktop (.deb — build da comunidade)..."
    if has github-desktop; then
        ok "GitHub Desktop já instalado"
    else
        GHD_URL="$(curl -fsSL https://api.github.com/repos/shiftkey/desktop/releases/latest \
            | grep -oP '"browser_download_url":\s*"\K[^"]*linux-amd64[^"]*\.deb' | head -1 || true)"
        if [ -n "$GHD_URL" ]; then
            deb_install_url "$GHD_URL" "GitHub Desktop"
        else
            warn "GitHub Desktop: não foi possível obter o link do .deb"
        fi
    fi
fi

# ── 9. flatpak — Firefox, Discord, Spotify, Postman ──────────────────────────
#  Flatpak OK aqui: apps "de consumo", sem integração crítica com SSH/sistema.
#  Firefox via Flatpak porque o pacote apt `firefox` da Zorin (1:1zorin1) é um
#  stub que não traz o navegador; o Flatpak entrega o build oficial da Mozilla.
step "Apps via flatpak (flathub)..."
if ! has flatpak; then
    apt_install flatpak
fi
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

flatpak_install() {
    local id="$1" label="$2"
    if flatpak info "$id" &>/dev/null; then
        ok "$label já instalado"
    else
        flatpak install -y --noninteractive flathub "$id" \
            && ok "$label instalado" \
            || warn "$label falhou"
    fi
}

[ "$INSTALL_FIREFOX" = "1" ] && flatpak_install org.mozilla.firefox  "Firefox"
[ "$INSTALL_DISCORD" = "1" ] && flatpak_install com.discordapp.Discord "Discord"
[ "$INSTALL_SPOTIFY" = "1" ] && flatpak_install com.spotify.Client     "Spotify"
[ "$INSTALL_POSTMAN" = "1" ] && flatpak_install com.getpostman.Postman "Postman"

# ── 10. Nerd Fonts ───────────────────────────────────────────────────────────
if [ "$INSTALL_FONTS" = "1" ]; then
    step "Nerd Fonts..."
    if [ -f "$SCRIPT_DIR/nerdfonts-install.sh" ]; then
        bash "$SCRIPT_DIR/nerdfonts-install.sh" || warn "nerdfonts-install.sh retornou erro"
    else
        warn "nerdfonts-install.sh não encontrado em $SCRIPT_DIR"
    fi
fi

# ── 10b. lan-mouse — KVM nativo (teclado/mouse via LAN) ──────────────────────
#  Software KVM da família "compartilha 1 teclado/mouse entre máquinas da mesa".
#  Nativo via cargo (NÃO Flatpak): o Flatpak da Zorin trava modificadores
#  (shift/capslock) como servidor no Wayland. lan-mouse é escrito sobre libei
#  (impl. Rust pura — independe do libei do sistema) e trata isso corretamente.
#  Pré-compilado .deb não existe p/ Ubuntu 24.04 (noble), por isso build local.
if [ "$INSTALL_LANMOUSE" = "1" ]; then
    step "lan-mouse (KVM nativo)..."
    if has lan-mouse || [ -x "$HOME/.cargo/bin/lan-mouse" ]; then
        ok "lan-mouse já instalado"
    else
        # deps de build (GTK4 + libadwaita p/ a GUI; X11 p/ backend de emulação)
        apt_install build-essential pkg-config \
            libadwaita-1-dev libgtk-4-dev libx11-dev libxtst-dev
        # toolchain Rust via rustup (em ~/.cargo, sem mexer no sistema)
        if ! has cargo && [ ! -x "$HOME/.cargo/bin/cargo" ]; then
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
                | sh -s -- -y --no-modify-path --profile minimal \
                && ok "Rust (rustup) instalado" || warn "rustup falhou"
        fi
        # shellcheck disable=SC1091
        [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
        if has cargo; then
            cargo install lan-mouse && ok "lan-mouse instalado (~/.cargo/bin)" \
                || warn "cargo install lan-mouse falhou"
        else
            warn "cargo indisponível — lan-mouse não instalado"
        fi
        # autostart como user service (precisa de sessão gráfica + portal)
        if has lan-mouse || [ -x "$HOME/.cargo/bin/lan-mouse" ]; then
            mkdir -p "$HOME/.config/systemd/user"
            cat > "$HOME/.config/systemd/user/lan-mouse.service" <<'UNIT'
[Unit]
Description=Lan Mouse (software KVM)
After=graphical-session.target
BindsTo=graphical-session.target

[Service]
ExecStart=%h/.cargo/bin/lan-mouse --daemon
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
UNIT
            systemctl --user daemon-reload 2>/dev/null || true
            systemctl --user enable lan-mouse.service 2>/dev/null \
                && ok "autostart (systemd user) habilitado" \
                || warn "não foi possível habilitar o autostart (rode num login gráfico)"
        fi
    fi
fi

# ── Resumo ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}"
cat << 'SUMMARY'
  ╔══════════════════════════════════════════════════════╗
  ║                Apps Zorin — Concluído                ║
  ╚══════════════════════════════════════════════════════╝
SUMMARY
echo -e "${RESET}"
echo -e "  ${YELLOW}⚠${RESET}  GitKraken / DBeaver / GitHub Desktop: instalados como .deb nativo"
echo -e "      (não Flatpak) — acesso direto a ~/.ssh, SSH agent e projetos."
echo -e "  ${YELLOW}⚠${RESET}  1Password (app): instale separadamente — este script só traz o CLI (op)."
echo -e "  ${YELLOW}⚠${RESET}  Windows Terminal: sem porte Linux — Warp cobre o terminal moderno."
echo -e "  ${YELLOW}⚠${RESET}  Google Drive: sem cliente oficial Linux."
echo -e "      Use ${BOLD}Configurações → Contas Online → Google${RESET} (ou rclone / Insync)."
echo -e "  ${YELLOW}⚠${RESET}  lan-mouse (KVM): build nativo via cargo + autostart (systemd user)."
echo -e "      Configure clients/bordas em ${BOLD}~/.config/lan-mouse/config.toml${RESET}; libere a porta 4242."
echo -e "  ${YELLOW}⚠${RESET}  CLIs de dev (Node, Docker, PHP, Composer, Lando, gh, Claude):"
echo -e "      instalados a seguir via setup-wsl.sh."
echo ""

# ── 11. CLIs de desenvolvimento — delega para setup-wsl.sh ───────────────────
#  Docker Engine, nvm/Node, PHP, Composer, Lando, gh, Claude Code e config do
#  Git. São os MESMOS do WSL — setup-wsl.sh é idempotente e roda em Zorin/Ubuntu
#  nativo. SKIP_ZSH=1 porque o Zsh não é desejado neste ambiente.
if [ "$INSTALL_WSL_CLIS" = "1" ]; then
    step "Instalando CLIs de desenvolvimento (setup-wsl.sh)..."
    if [ -f "$SCRIPT_DIR/setup-wsl.sh" ]; then
        SKIP_ZSH=1 \
        GIT_NAME="${GIT_NAME:-}" GIT_EMAIL="${GIT_EMAIL:-}" \
        bash "$SCRIPT_DIR/setup-wsl.sh"
    else
        warn "setup-wsl.sh não encontrado em $SCRIPT_DIR — CLIs não instalados"
    fi
fi

# ── 12. CLIs de cloud/infra ──────────────────────────────────────────────────
#  Pareiam com os shell plugins do 1Password (op plugin init). Rodam depois do
#  setup-wsl.sh porque o wrangler precisa do npm (nvm).

if [ "$INSTALL_AWS" = "1" ]; then
    step "AWS CLI v2..."
    if has aws; then
        ok "AWS CLI já instalado: $(aws --version 2>&1 | cut -d' ' -f1)"
    else
        apt_install unzip
        tmp="$(mktemp -d)"
        if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmp/awscliv2.zip"; then
            unzip -q "$tmp/awscliv2.zip" -d "$tmp"
            sudo "$tmp/aws/install" >/dev/null 2>&1 && ok "AWS CLI instalado" || warn "AWS CLI falhou"
        else
            warn "AWS CLI: download falhou"
        fi
        rm -rf "$tmp"
    fi
fi

if [ "$INSTALL_TERRAFORM" = "1" ]; then
    step "Terraform..."
    if has terraform; then
        ok "Terraform já instalado: $(terraform version | head -1)"
    else
        # Binário oficial (zip) — o repo apt do HashiCorp é instável para
        # publicar o índice Packages; o zip é um único binário, sempre confiável.
        apt_install unzip
        TFVER="$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform 2>/dev/null \
            | grep -oP '"current_version":"\K[^"]+' || true)"
        if [ -n "$TFVER" ]; then
            tmp="$(mktemp -d)"
            if curl -fsSL "https://releases.hashicorp.com/terraform/${TFVER}/terraform_${TFVER}_linux_amd64.zip" -o "$tmp/tf.zip"; then
                unzip -q "$tmp/tf.zip" -d "$tmp"
                sudo install -m 755 "$tmp/terraform" /usr/local/bin/terraform \
                    && ok "Terraform ${TFVER} instalado" || warn "Terraform falhou"
            else
                warn "Terraform: download falhou"
            fi
            rm -rf "$tmp"
        else
            warn "Terraform: não foi possível obter a versão mais recente"
        fi
    fi
fi

if [ "$INSTALL_WRANGLER" = "1" ]; then
    step "Wrangler (Cloudflare)..."
    set +u
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    set -u
    if has wrangler; then
        ok "Wrangler já instalado"
    elif has npm; then
        npm install -g wrangler >/dev/null 2>&1 && ok "Wrangler instalado" || warn "Wrangler falhou"
    else
        warn "npm não encontrado — instale o Wrangler após o setup-wsl.sh"
    fi
fi

if [ "$INSTALL_DOCTL" = "1" ]; then
    step "doctl (DigitalOcean)..."
    if has doctl; then
        ok "doctl já instalado"
    else
        sudo snap install doctl >/dev/null 2>&1 && ok "doctl instalado" || warn "doctl falhou"
    fi
fi

if [ "$INSTALL_GLAB" = "1" ]; then
    step "glab (GitLab CLI)..."
    if has glab; then
        ok "glab já instalado"
    else
        GLAB_URL="$(curl -fsSL 'https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases' 2>/dev/null \
            | grep -oP '"direct_asset_url":"\K[^"]*amd64\.deb' | head -1 || true)"
        if [ -n "$GLAB_URL" ]; then
            deb_install_url "$GLAB_URL" "glab"
        else
            warn "glab: não foi possível obter o link do .deb"
        fi
    fi
fi

if [ "$INSTALL_CLOUDFLARED" = "1" ]; then
    step "cloudflared (Cloudflare Tunnel / Access SSH proxy)..."
    if has cloudflared; then
        ok "cloudflared já instalado: $(cloudflared --version 2>&1 | head -1)"
    else
        # Binário estático do GitHub Releases — sem dependências, idêntico ao
        # usado nas pipelines CI para ProxyCommand SSH via Cloudflare Access.
        CFDVER="$(curl -fsSL 'https://api.github.com/repos/cloudflare/cloudflared/releases/latest' 2>/dev/null \
            | grep -oP '"tag_name":\s*"\K[^"]+' | head -1 || true)"
        if [ -n "$CFDVER" ]; then
            tmp="$(mktemp)"
            if curl -fsSL \
                "https://github.com/cloudflare/cloudflared/releases/download/${CFDVER}/cloudflared-linux-amd64" \
                -o "$tmp"; then
                sudo install -m 755 "$tmp" /usr/local/bin/cloudflared \
                    && ok "cloudflared ${CFDVER} instalado" || warn "cloudflared: install falhou"
            else
                warn "cloudflared: download falhou"
            fi
            rm -f "$tmp"
        else
            warn "cloudflared: não foi possível obter a versão mais recente"
        fi
    fi
fi

if [ "$INSTALL_UV" = "1" ]; then
    step "uv (Python package manager)..."
    if has uv; then
        ok "uv já instalado: $(uv --version 2>&1 | head -1)"
    else
        if curl -fsSL https://astral.sh/uv/install.sh | sh; then
            ok "uv instalado"
        else
            warn "uv: instalação falhou"
        fi
    fi
fi
