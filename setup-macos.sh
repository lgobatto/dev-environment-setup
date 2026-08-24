#!/usr/bin/env bash
# =============================================================================
#  macOS — Apps GUI + CLIs de dev
#  Par do setup-zorin-apps.sh (Linux) e do setup-windows.ps1 (Windows).
#  Idempotente — seguro para re-executar.
#
#  Homebrew e o unico gerenciador usado: formula para CLI, cask para app GUI.
#  Nao ha equivalente de Flatpak aqui — o cask instala o .app oficial, sem
#  sandbox, entao o criterio "ferramenta de dev nao pode ser sandboxed" (ver
#  docs/instalacao-nativa.md do workstation) e atendido por construcao.
#
#  Uso:
#    bash setup-macos.sh                    # tudo
#    INSTALL_GUI=0 bash setup-macos.sh      # so CLIs
#    INSTALL_DISCORD=0 INSTALL_SPOTIFY=0 bash setup-macos.sh
#
#  Docker: DOCKER_RUNTIME=desktop (padrao) ou colima.
#    desktop → Docker Desktop. E o runtime que o Lando suporta oficialmente no
#              macOS; como o stack roda WordPress via Lando, e o padrao.
#              Atencao: Docker Desktop exige assinatura paga para empresas
#              acima de 250 funcionarios OU US$ 10M de faturamento.
#    colima  → Docker Engine em VM leve, FOSS, sem licenca. Equivale ao que o
#              setup Linux faz (Engine sem Desktop). Lando funciona, porem com
#              suporte nao-oficial.
# =============================================================================
set -uo pipefail

# ── Flags (1 = instala, 0 = pula) ────────────────────────────────────────────
INSTALL_GUI="${INSTALL_GUI:-1}"
INSTALL_VSCODE="${INSTALL_VSCODE:-1}"
INSTALL_CHROME="${INSTALL_CHROME:-1}"
INSTALL_FIREFOX="${INSTALL_FIREFOX:-1}"
INSTALL_WARP="${INSTALL_WARP:-1}"
INSTALL_GITKRAKEN="${INSTALL_GITKRAKEN:-1}"
INSTALL_DBEAVER="${INSTALL_DBEAVER:-1}"
INSTALL_DISCORD="${INSTALL_DISCORD:-1}"
INSTALL_SPOTIFY="${INSTALL_SPOTIFY:-1}"
INSTALL_1PASSWORD="${INSTALL_1PASSWORD:-1}"   # app + CLI
INSTALL_FONTS="${INSTALL_FONTS:-1}"           # Nerd Fonts

INSTALL_CLIS="${INSTALL_CLIS:-1}"             # base de dev (git, gh, node, php...)
INSTALL_DOCKER="${INSTALL_DOCKER:-1}"
DOCKER_RUNTIME="${DOCKER_RUNTIME:-desktop}"   # desktop | colima
INSTALL_LANDO="${INSTALL_LANDO:-1}"
INSTALL_CLAUDE_CODE="${INSTALL_CLAUDE_CODE:-1}"
INSTALL_PRODTOOLS="${INSTALL_PRODTOOLS:-1}"   # produtividade / IaC / seguranca
INSTALL_CLOUD="${INSTALL_CLOUD:-1}"           # aws, terraform, cloudflared, doctl, glab, uv

# ── Cores e helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
step() { echo -e "\n${CYAN}${BOLD}▶ $*${RESET}"; }
ok()   { echo -e "  ${GREEN}✔${RESET} $*"; }
warn() { echo -e "  ${YELLOW}⚠${RESET} $*"; }
err()  { echo -e "  ${RED}✖${RESET} $*"; }

FALHAS=()

has() { command -v "$1" >/dev/null 2>&1; }

# brew_formula <nome> [binario-esperado] [--brew-only]
#  Nao aborta o script inteiro se um pacote falhar: registra e segue. Numa
#  maquina nova, uma formula renomeada nao pode derrubar o resto do setup.
#
#  --brew-only ignora um binario homonimo que ja exista fora do brew. Serve
#  para o caso em que o macOS ja traz uma versao propria mas queremos a do
#  brew mesmo assim (ex.: o git do Command Line Tools fica preso ao ciclo de
#  release do Xcode). Sem a flag, qualquer binario no PATH conta como
#  "ja presente" — que e o certo para a maioria (jq, por exemplo, vem no
#  macOS 26 e nao precisa de duplicata).
brew_formula() {
    local pkg="$1" bin="${2:-$1}" modo="${3:-}"
    # Aceita nome com tap (ex.: hashicorp/tap/terraform): o `brew list` quer o
    # nome curto, mas o `brew install` precisa do caminho completo (auto-tapa).
    local curto="${pkg##*/}"
    [ "$bin" = "$pkg" ] && bin="$curto"
    if brew list --formula "$curto" >/dev/null 2>&1; then
        ok "$pkg (já presente)"; return 0
    fi
    if [ "$modo" != "--brew-only" ] && has "$bin"; then
        ok "$pkg (já presente)"; return 0
    fi
    if brew install "$pkg" >/dev/null 2>&1; then ok "$pkg"
    else err "$pkg falhou"; FALHAS+=("formula:$pkg"); fi
}

# brew_cask <nome> ["/Applications/Nome.app"]
brew_cask() {
    local pkg="$1" app="${2:-}"
    local curto="${pkg##*/}"
    if [ -n "$app" ] && [ -d "$app" ]; then ok "$pkg (já instalado)"; return 0; fi
    if brew list --cask "$curto" >/dev/null 2>&1; then ok "$pkg (já instalado)"; return 0; fi
    if brew install --cask "$pkg" >/dev/null 2>&1; then ok "$pkg"
    else err "$pkg falhou"; FALHAS+=("cask:$pkg"); fi
}

echo -e "${CYAN}${BOLD}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   macOS — ambiente de desenvolvimento (Homebrew)      ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ── 0. Pre-requisitos: Command Line Tools + Homebrew ─────────────────────────
step "Pré-requisitos"
if [ "$(uname -s)" != "Darwin" ]; then
    err "Este script é só para macOS. No Linux use setup-zorin-apps.sh."; exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
    warn "Xcode Command Line Tools ausentes — abrindo o instalador gráfico."
    warn "Conclua a instalação e rode este script de novo."
    xcode-select --install 2>/dev/null || true
    exit 1
fi
ok "Xcode Command Line Tools"

# Numa instalacao recem-feita o brew AINDA NAO esta no PATH: o `brew shellenv`
# so entra no rc do shell depois (quem faz isso e o workstation/install.sh).
# Por isso procurar o binario nos prefixos conhecidos antes de desistir —
# checar so o PATH daria "Homebrew nao instalado" com ele instalado.
BREW_BIN=""
if has brew; then
    BREW_BIN="$(command -v brew)"
else
    for cand in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$cand" ] && { BREW_BIN="$cand"; break; }
    done
fi

if [ -z "$BREW_BIN" ]; then
    # O instalador do Homebrew pede senha de administrador (cria /opt/homebrew).
    # Nao da para rodar desatendido; por isso instrui em vez de tentar.
    err "Homebrew não instalado. Rode e execute este script de novo:"
    echo '     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo "     (precisa de um terminal de verdade — o sudo não pede senha sem TTY)"
    exit 1
fi
# Apple Silicon instala em /opt/homebrew, que nao esta no PATH por padrao.
eval "$("$BREW_BIN" shellenv)"
ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"

brew update >/dev/null 2>&1 && ok "índice do brew atualizado" || warn "brew update falhou (seguindo)"

# ── 1. CLIs base de dev ──────────────────────────────────────────────────────
if [ "$INSTALL_CLIS" = "1" ]; then
    step "CLIs base de desenvolvimento"
    # git do brew mesmo com o do CLT presente: o do Xcode so atualiza junto com
    # o Command Line Tools. O `brew shellenv` poe /opt/homebrew/bin antes do
    # /usr/bin, entao o do brew e o que passa a responder por `git`.
    brew_formula git git --brew-only
    brew_formula gh
    brew_formula jq            # op-creds.sh depende
    brew_formula node
    brew_formula php
    brew_formula composer
    brew_formula wget
    brew_formula coreutils     # gdate/gsed p/ scripts que assumem GNU
fi

# ── 2. 1Password (app + CLI) ─────────────────────────────────────────────────
if [ "$INSTALL_1PASSWORD" = "1" ]; then
    step "1Password"
    brew_cask 1password "/Applications/1Password.app"
    brew_cask 1password-cli
    warn "App → Settings → Developer: ligar 'CLI integration' e 'SSH agent'"
fi

# ── 3. Docker ────────────────────────────────────────────────────────────────
if [ "$INSTALL_DOCKER" = "1" ]; then
    step "Docker (runtime: $DOCKER_RUNTIME)"
    case "$DOCKER_RUNTIME" in
        desktop)
            # O cask do Docker Desktop faz `sudo ln -s` do docker-credential-osxkeychain
            # em /usr/local/bin. Sem TTY o sudo falha e o brew reverte a instalacao
            # inteira. Nao da para contornar de dentro do script: avisa e sai.
            if [ -d "/Applications/Docker.app" ]; then
                ok "docker-desktop (já instalado)"
            elif sudo -n true 2>/dev/null; then
                brew_cask docker-desktop "/Applications/Docker.app"
            else
                err "docker-desktop exige sudo com terminal interativo."
                echo "     Rode num Terminal de verdade (não por script/agente):"
                echo "       brew install --cask docker-desktop"
                echo "     Ou use o runtime FOSS, que dispensa sudo:"
                echo "       DOCKER_RUNTIME=colima bash setup-macos.sh"
                FALHAS+=("cask:docker-desktop (precisa de TTY)")
            fi
            warn "Abra o Docker Desktop uma vez para concluir a instalação do daemon."
            ;;
        colima)
            brew_formula colima
            brew_formula docker            # CLI
            brew_formula docker-compose
            warn "Suba o runtime com: colima start --cpu 4 --memory 8"
            ;;
        *) err "DOCKER_RUNTIME inválido: $DOCKER_RUNTIME (use desktop ou colima)"
           FALHAS+=("docker:runtime-invalido") ;;
    esac
fi

# ── 4. Lando ─────────────────────────────────────────────────────────────────
#  NAO usar o cask `lando`: foi descontinuado e desabilitado em 2025-09-07
#  ("no longer distributes an install package"), e ainda arrastava o
#  docker-desktop como dependencia. O metodo oficial e o setup-lando.sh, que
#  instala em ~/.lando/bin sem pedir sudo — o mesmo que o setup-wsl.sh ja faz
#  no Linux, entao os dois SOs ficam com a instalacao identica.
if [ "$INSTALL_LANDO" = "1" ]; then
    step "Lando"
    LANDO_BIN="$HOME/.lando/bin/lando"
    if [ -x "$LANDO_BIN" ] || has lando; then
        ok "lando (já presente)"
    else
        if curl -fsSL https://get.lando.dev/setup-lando.sh -o /tmp/setup-lando.sh \
           && bash /tmp/setup-lando.sh --yes --dest "$HOME/.lando/bin" >/dev/null 2>&1 \
           && [ -x "$LANDO_BIN" ]; then
            export PATH="$HOME/.lando/bin:$PATH"
            ok "lando ($("$LANDO_BIN" version 2>/dev/null || echo 'v3.x'))"
        else
            err "lando falhou"; FALHAS+=("lando")
        fi
        rm -f /tmp/setup-lando.sh
    fi
fi

# ── 5. Claude Code ───────────────────────────────────────────────────────────
if [ "$INSTALL_CLAUDE_CODE" = "1" ]; then
    step "Claude Code"
    if has claude; then ok "claude (já presente)"
    else
        curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1 \
            && ok "claude" || { err "claude falhou"; FALHAS+=("claude-code"); }
    fi
fi

# ── 6. Cloud / infra ─────────────────────────────────────────────────────────
if [ "$INSTALL_CLOUD" = "1" ]; then
    step "CLIs de cloud e infraestrutura"
    brew_formula awscli aws
    # A HashiCorp trocou a licenca do Terraform para BUSL em 2023 e a formula
    # saiu do core do Homebrew; o binario oficial vive no tap deles.
    brew_formula hashicorp/tap/terraform terraform
    brew_formula cloudflared
    brew_formula doctl
    brew_formula glab
    brew_formula uv
    # wrangler via npm: o brew nao mantem formula oficial da Cloudflare.
    if has npm; then
        has wrangler && ok "wrangler (já presente)" \
            || { npm install -g wrangler >/dev/null 2>&1 && ok "wrangler" \
                 || { err "wrangler falhou"; FALHAS+=("npm:wrangler"); }; }
    else
        warn "npm ausente — wrangler pulado"
    fi
fi

# ── 7. Produtividade / IaC / seguranca ───────────────────────────────────────
#  Mesmo conjunto do INSTALL_PRODTOOLS do setup-wsl.sh. No Linux parte vem do
#  apt e parte de binario do GitHub Releases; aqui tudo e formula do brew, e os
#  nomes ficam corretos (bat/fd, e nao batcat/fdfind).
if [ "$INSTALL_PRODTOOLS" = "1" ]; then
    step "Ferramentas de produtividade, IaC e segurança"
    brew_formula gitleaks
    brew_formula direnv
    brew_formula zoxide
    brew_formula mise
    brew_formula shellcheck
    brew_formula shfmt
    brew_formula pre-commit
    # tflint nao esta no core do Homebrew e e distribuido como CASK no tap
    # oficial do projeto (terraform-linters/homebrew-tap/Casks/tflint.rb).
    brew_cask terraform-linters/tap/tflint
    brew_formula trivy
    brew_formula infracost
    brew_formula terraform-docs
    brew_formula actionlint
    brew_formula eza
    brew_formula bat
    brew_formula ripgrep rg
    brew_formula fd
    brew_formula k9s
    brew_formula lazydocker
    brew_formula fzf
fi

# ── 8. Apps GUI ──────────────────────────────────────────────────────────────
if [ "$INSTALL_GUI" = "1" ]; then
    step "Apps GUI"
    [ "$INSTALL_VSCODE"    = "1" ] && brew_cask visual-studio-code "/Applications/Visual Studio Code.app"
    [ "$INSTALL_WARP"      = "1" ] && brew_cask warp "/Applications/Warp.app"
    [ "$INSTALL_CHROME"    = "1" ] && brew_cask google-chrome "/Applications/Google Chrome.app"
    [ "$INSTALL_DBEAVER"   = "1" ] && brew_cask dbeaver-community "/Applications/DBeaver.app"
    [ "$INSTALL_GITKRAKEN" = "1" ] && brew_cask gitkraken "/Applications/GitKraken.app"
    [ "$INSTALL_FIREFOX"   = "1" ] && brew_cask firefox "/Applications/Firefox.app"
    [ "$INSTALL_DISCORD"   = "1" ] && brew_cask discord "/Applications/Discord.app"
    [ "$INSTALL_SPOTIFY"   = "1" ] && brew_cask spotify "/Applications/Spotify.app"
fi

# ── 9. Nerd Fonts ────────────────────────────────────────────────────────────
#  Warp e o Powerlevel10k dependem de glifos Nerd Font. Desde 2024 as fontes
#  vivem no cask principal — o tap homebrew/cask-fonts foi descontinuado.
if [ "$INSTALL_FONTS" = "1" ]; then
    step "Nerd Fonts"
    brew_cask font-meslo-lg-nerd-font
    brew_cask font-fira-code-nerd-font
fi

# ── Resumo ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║   setup-macos.sh concluído                            ║${RESET}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════╝${RESET}"
if [ ${#FALHAS[@]} -gt 0 ]; then
    echo ""
    warn "Itens que falharam (${#FALHAS[@]}):"
    for f in "${FALHAS[@]}"; do echo "      • $f"; done
    echo "      Reexecute o script — ele é idempotente e só tenta o que falta."
fi
echo ""
echo "  Próximo passo: a config pessoal (repo privado workstation)"
echo "     cd ~/workstation && ./install.sh"
