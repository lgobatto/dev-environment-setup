#!/usr/bin/env bash
# =============================================================================
#  Migrar projeto do filesystem Windows para WSL2 nativo
#
#  Por que migrar?
#    Projetos em /mnt/c/Users/... são lidos via camada de interop Windows↔WSL2.
#    Essa camada tem latência de I/O ~10-20x maior que o filesystem Linux nativo.
#    Com Bedrock + Acorn + Sage (centenas de arquivos PHP por request), a diferença
#    é enorme. Migrando para ~/projects, o Docker lê arquivos direto do EXT4.
#
#  Uso:
#    bash migrate-project.sh
#
#    # Ou com parâmetros:
#    REPO_URL="git@github.com:BrisaBR/brisausa.git" \
#    PROJECT_NAME="brisausa" \
#    bash migrate-project.sh
#
#  O que faz:
#    1. Clona o repositório no ~/projects/ (com submodules)
#    2. Copia o .env do projeto Windows (se existir)
#    3. Instrui sobre próximos passos
# =============================================================================

set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'

step() { echo -e "\n${CYAN}${BOLD}▶ $*${RESET}"; }
ok()   { echo -e "  ${GREEN}✔${RESET} $*"; }
warn() { echo -e "  ${YELLOW}⚠${RESET} $*"; }
fail() { echo -e "  ${RED}✖${RESET} $*" >&2; }
info() { echo -e "  ${BOLD}→${RESET} $*"; }

echo -e "${CYAN}${BOLD}"
cat << 'BANNER'
  ╔══════════════════════════════════════════════════════╗
  ║         Migração de Projeto para WSL2              ║
  ║         Windows filesystem → ~/projects            ║
  ╚══════════════════════════════════════════════════════╝
BANNER
echo -e "${RESET}"

# ── Configuração ──────────────────────────────────────────────────────────────
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
REPO_URL="${REPO_URL:-}"
PROJECT_NAME="${PROJECT_NAME:-}"

# ── Detectar Windows username para localizar o projeto atual ──────────────────
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || echo "")
WIN_PROJECTS_BASE="/mnt/c/Users/${WIN_USER}/Work"

mkdir -p "$PROJECTS_DIR"

# ── Modo interativo: listar projetos disponíveis ───────────────────────────────
if [ -z "$REPO_URL" ] && [ -z "$PROJECT_NAME" ]; then
    echo -e "  Projetos encontrados em ${WIN_PROJECTS_BASE}:"
    echo ""

    # Listar repositórios Git no diretório de trabalho Windows
    find "$WIN_PROJECTS_BASE" -maxdepth 3 -name ".git" -type d 2>/dev/null | while read -r gitdir; do
        proj_path=$(dirname "$gitdir")
        proj_name=$(basename "$proj_path")
        remote_url=$(git -C "$proj_path" remote get-url origin 2>/dev/null || echo "sem remote")
        echo -e "    ${CYAN}•${RESET} ${BOLD}${proj_name}${RESET} — $remote_url"
        echo -e "      Windows: $proj_path"
        echo -e "      WSL2:    $PROJECTS_DIR/$proj_name"
        echo ""
    done

    echo -e "  ${BOLD}Como usar este script:${RESET}"
    echo ""
    echo -e "  ${CYAN}# Clonar por URL (recomendado):${RESET}"
    echo -e "  REPO_URL='git@github.com:org/repo.git' bash migrate-project.sh"
    echo ""
    echo -e "  ${CYAN}# Migrar do Windows copiando .env (sem re-clonar):${RESET}"
    echo -e "  PROJECT_NAME='brisausa' bash migrate-project.sh"
    echo ""
    echo -e "  ${CYAN}# Modo interativo — digitar URL agora:${RESET}"
    echo -ne "  URL do repositório Git (ou ENTER para pular): "
    read -r REPO_URL
fi

# ── Se URL fornecida: clonar ────────────────────────────────────────────────
if [ -n "$REPO_URL" ]; then
    # Extrair nome do projeto da URL
    if [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME=$(basename "$REPO_URL" .git)
    fi

    DEST_DIR="$PROJECTS_DIR/$PROJECT_NAME"

    step "Clonando $PROJECT_NAME..."
    info "URL: $REPO_URL"
    info "Destino: $DEST_DIR"

    if [ -d "$DEST_DIR/.git" ]; then
        warn "$PROJECT_NAME já existe em $DEST_DIR — atualizando..."
        git -C "$DEST_DIR" pull --recurse-submodules
        git -C "$DEST_DIR" submodule update --init --recursive
        ok "Repositório atualizado"
    else
        git clone --recurse-submodules "$REPO_URL" "$DEST_DIR"
        ok "Repositório clonado com submodules"
    fi

    # Procurar .env no Windows para copiar
    WIN_ENV="${WIN_PROJECTS_BASE}/${PROJECT_NAME}/.env"
    if [ -f "$WIN_ENV" ] && [ ! -f "$DEST_DIR/.env" ]; then
        cp "$WIN_ENV" "$DEST_DIR/.env"
        ok ".env copiado do projeto Windows"
    elif [ -f "$WIN_ENV" ]; then
        warn ".env já existe em $DEST_DIR — não sobrescrevendo"
        info "Compare manualmente: diff $WIN_ENV $DEST_DIR/.env"
    else
        warn ".env não encontrado em $WIN_ENV"
        info "Copie seu .env manualmente para $DEST_DIR/.env"
    fi

# ── Se apenas nome do projeto: copiar .env e verificar ──────────────────────
elif [ -n "$PROJECT_NAME" ]; then
    DEST_DIR="$PROJECTS_DIR/$PROJECT_NAME"

    if [ ! -d "$DEST_DIR" ]; then
        fail "Projeto não encontrado em $DEST_DIR"
        info "Use REPO_URL para clonar primeiro"
        exit 1
    fi

    WIN_ENV="${WIN_PROJECTS_BASE}/${PROJECT_NAME}/.env"
    if [ -f "$WIN_ENV" ]; then
        cp "$WIN_ENV" "$DEST_DIR/.env"
        ok ".env copiado de $WIN_ENV"
    else
        warn ".env não encontrado em $WIN_ENV"
    fi
fi

# ── Verificar resultado ────────────────────────────────────────────────────────
if [ -n "$PROJECT_NAME" ] && [ -d "$PROJECTS_DIR/$PROJECT_NAME" ]; then
    DEST_DIR="$PROJECTS_DIR/$PROJECT_NAME"

    step "Verificando projeto..."

    # Checar .env
    if [ -f "$DEST_DIR/.env" ]; then
        ok ".env presente"
    else
        warn ".env ausente — necessário para o Lando funcionar"
    fi

    # Checar submodules
    if [ -f "$DEST_DIR/.gitmodules" ]; then
        MODULE_COUNT=$(grep -c "\[submodule" "$DEST_DIR/.gitmodules" 2>/dev/null || echo 0)
        ok "$MODULE_COUNT submodule(s) detectado(s)"
        git -C "$DEST_DIR" submodule status 2>/dev/null | while read -r line; do
            info "$line"
        done
    fi

    # Checar .lando.yml
    if [ -f "$DEST_DIR/.lando.yml" ]; then
        ok ".lando.yml presente"
    else
        warn ".lando.yml não encontrado"
    fi

    echo ""
    echo -e "  ${BOLD}Próximos passos para ${PROJECT_NAME}:${RESET}"
    echo ""
    echo -e "    ${CYAN}# Entrar no projeto${RESET}"
    echo -e "    cd $DEST_DIR"
    echo ""
    echo -e "    ${CYAN}# Iniciar o ambiente${RESET}"
    echo -e "    lando start"
    echo ""
    echo -e "    ${CYAN}# Abrir no VS Code via Remote WSL${RESET}"
    echo -e "    code ."
    echo ""
    echo -e "    ${CYAN}# Iniciar dev server (HMR)${RESET}"
    echo -e "    lando dev"
    echo ""
    echo -e "  ${YELLOW}⚠${RESET}  Dica: projetos em ~/projects são lidos pelo Docker nativamente."
    echo -e "        Sem overhead do filesystem Windows — performance total."
fi
