#!/usr/bin/env bash
# =============================================================================
#  Validação do ambiente de desenvolvimento
#
#  Roda depois do setup-wsl.sh e responde uma pergunta: o que ficou instalado
#  de verdade? O setup é tolerante a falha por design — um repo apt fora do ar
#  gera um warning e o script continua — então sem este passo o usuário só
#  descobre o buraco semanas depois, no meio de um projeto.
#
#  Uso:
#    bash validate-env.sh          # relatório completo
#    bash validate-env.sh --quiet  # só o resumo e as falhas
#
#  Saída: 0 se nada crítico falhou, 1 caso contrário — dá pra usar em CI.
# =============================================================================

set -uo pipefail   # sem `-e`: a graça daqui é rodar TODAS as checagens

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

# ── Cores e contadores ───────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

PASS=0; FAIL=0; WARN=0
FAILED_ITEMS=()

section() { [ "$QUIET" = "1" ] && return 0; echo -e "\n${CYAN}${BOLD}▶ $*${RESET}"; }

# pass/warn/fail sempre contam; a impressão do pass é suprimida em --quiet
pass() { PASS=$((PASS + 1)); [ "$QUIET" = "1" ] && return 0
         echo -e "  ${GREEN}✔${RESET} $*"; }
warn() { WARN=$((WARN + 1)); echo -e "  ${YELLOW}⚠${RESET} $*"; }
fail() { FAIL=$((FAIL + 1)); FAILED_ITEMS+=("$1")
         echo -e "  ${RED}✖${RESET} $*"; }

has() { command -v "$1" &>/dev/null; }

# Abrevia $HOME como ~ na saída.
# Não use `${var/#$HOME/~}`: o `~` do lado direito de uma substituição sofre
# expansão de til e volta a ser o caminho completo — o resultado sai igual à
# entrada, sem erro nenhum.
short_path() {
    case "$1" in
        "$HOME") printf '~' ;;
        "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
        *) printf '%s' "$1" ;;
    esac
}

# check_cmd <comando> <descrição> [comando-de-versão]
# Falha (crítico) se o comando não existe.
check_cmd() {
    local cmd="$1" desc="$2" vercmd="${3:-}" version
    if has "$cmd"; then
        if [ -n "$vercmd" ]; then
            version="$(eval "$vercmd" 2>/dev/null | head -1)"
            pass "${desc}: ${version:-instalado}"
        else
            pass "${desc}: instalado"
        fi
    else
        fail "${desc}: NÃO encontrado (\`${cmd}\`)"
    fi
}

# check_optional <comando> <descrição> — ausência é warning, não falha
check_optional() {
    if has "$1"; then pass "$2: instalado"
    else warn "$2: ausente (opcional)"; fi
}

# check_file <caminho> [nota]
# A descrição é derivada do caminho, para a mensagem fazer sentido nos dois
# resultados ("~/.bashrc presente" / "~/.bashrc ausente") em vez de virar um
# "existe — arquivo ausente" contraditório.
check_file() {
    local label note
    label="$(short_path "$1")"
    note="${2:-}"
    [ -n "$note" ] && note=" (${note})"
    if [ -f "$1" ]; then pass "${label} presente${note}"
    else fail "${label} ausente${note}"; fi
}

echo -e "${CYAN}${BOLD}"
cat << 'BANNER'
  ╔══════════════════════════════════════════════════════╗
  ║      Validação do ambiente de desenvolvimento      ║
  ╚══════════════════════════════════════════════════════╝
BANNER
echo -e "${RESET}"

if [ "$QUIET" != "1" ]; then
    OS_PRETTY="$( (. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-desconhecido}") || echo desconhecido )"
    echo -e "  Sistema: ${BOLD}${OS_PRETTY}${RESET}"
    if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
        echo -e "  Ambiente: ${BOLD}WSL2${RESET}"
    else
        echo -e "  Ambiente: ${BOLD}Linux nativo${RESET}"
    fi
    echo -e "  Shell atual: ${BOLD}${SHELL:-?}${RESET}"
fi

# ── 1. Ferramentas CLI ───────────────────────────────────────────────────────
section "1. Ferramentas CLI"

check_cmd git      "Git"         "git --version"
check_cmd docker   "Docker"      "docker --version"
check_cmd node     "Node.js"     "node --version"
check_cmd npm      "npm"         "npm --version"
check_cmd php      "PHP"         "php --version"
check_cmd composer "Composer"    "composer --version"
check_cmd lando    "Lando"       "lando version"
check_cmd gh       "GitHub CLI"  "gh --version"
check_cmd claude   "Claude Code" "claude --version"

check_optional zsh   "Zsh"
check_optional op    "1Password CLI"
check_optional jq    "jq"

# nvm é função de shell, não binário — `command -v` não acha
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    pass "nvm: $(cat "$HOME/.nvm/.nvm_version" 2>/dev/null || echo 'instalado em ~/.nvm')"
else
    fail "nvm: NÃO encontrado em ~/.nvm/nvm.sh"
fi

# ── 2. Versões mínimas ───────────────────────────────────────────────────────
section "2. Versões mínimas"

# PHP: 8.4+ é o alvo do setup. 8.3 ainda roda, mas entra em fim de suporte
# em 31/12/2027 — sinalizamos como warning, não como falha.
if has php; then
    PHP_FULL="$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo '0.0')"
    PHP_MAJOR="$(php -r 'echo PHP_MAJOR_VERSION;' 2>/dev/null || echo 0)"
    PHP_MINOR="$(php -r 'echo PHP_MINOR_VERSION;' 2>/dev/null || echo 0)"
    if [ "$PHP_MAJOR" -gt 8 ] 2>/dev/null; then
        pass "PHP ${PHP_FULL}"
    elif [ "$PHP_MAJOR" -eq 8 ] && [ "$PHP_MINOR" -ge 4 ] 2>/dev/null; then
        pass "PHP ${PHP_FULL} (suporte até 2028+)"
    else
        warn "PHP ${PHP_FULL} — abaixo do 8.4 alvo. Rode: PHP_VERSION=8.4 bash setup-wsl.sh"
    fi
fi

# Node: LTS par (24, 26, ...). Ímpar = release Current, não LTS.
if has node; then
    NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
    if [ "$NODE_MAJOR" -ge 20 ] 2>/dev/null && [ $((NODE_MAJOR % 2)) -eq 0 ]; then
        pass "Node.js $(node --version) (linha LTS)"
    elif [ "$NODE_MAJOR" -ge 20 ] 2>/dev/null; then
        warn "Node.js $(node --version) é linha Current, não LTS. Rode: nvm install --lts"
    else
        fail "Node.js $(node --version) — fora de suporte. Rode: nvm install --lts"
    fi
fi

# ── 3. Configurações ─────────────────────────────────────────────────────────
section "3. Configurações"

check_file "$HOME/.gitconfig"

for key in user.name user.email init.defaultBranch; do
    value="$(git config --global --get "$key" 2>/dev/null || true)"
    if [ -n "$value" ]; then
        pass "git ${key} = ${value}"
    else
        warn "git ${key} não configurado — git config --global ${key} '...'"
    fi
done

check_file "$HOME/.shell_local_exports.sh" "fonte única bash+zsh"
check_file "$HOME/.bashrc"

if [ -f "$HOME/.bashrc" ]; then
    if grep -q "shell_local_exports" "$HOME/.bashrc"; then
        pass "~/.bashrc carrega ~/.shell_local_exports.sh"
    else
        fail "~/.bashrc NÃO carrega ~/.shell_local_exports.sh — re-rode setup-wsl.sh"
    fi
fi

if [ -f "$HOME/.zshrc" ]; then
    if grep -q "shell_local_exports" "$HOME/.zshrc"; then
        pass "~/.zshrc carrega ~/.shell_local_exports.sh"
    else
        warn "~/.zshrc não carrega ~/.shell_local_exports.sh (bash e zsh vão divergir)"
    fi
else
    warn "~/.zshrc ausente (esperado se rodou com SKIP_ZSH=1)"
fi

# ── 4. Diretórios ────────────────────────────────────────────────────────────
section "4. Diretórios"

for dir in "$HOME/projects" "$HOME/.ssh" "$HOME/.local/bin"; do
    if [ -d "$dir" ]; then pass "$(short_path "$dir") presente"
    else warn "$(short_path "$dir") ausente"; fi
done

# Permissão do ~/.ssh: 700. Mais aberto e o OpenSSH recusa as chaves.
if [ -d "$HOME/.ssh" ]; then
    SSH_PERM="$(stat -c '%a' "$HOME/.ssh" 2>/dev/null || echo '?')"
    if [ "$SSH_PERM" = "700" ]; then
        pass "~/.ssh com permissão 700"
    else
        warn "~/.ssh com permissão ${SSH_PERM} (esperado 700) — chmod 700 ~/.ssh"
    fi
fi

# Projetos no filesystem Linux, não em /mnt/c — é o ponto central da arquitetura
if [ -d "$HOME/projects" ]; then
    case "$(readlink -f "$HOME/projects")" in
        /mnt/*) warn "~/projects aponta para /mnt/* — I/O do Docker ~10x mais lento" ;;
        *)      pass "~/projects no filesystem Linux nativo" ;;
    esac
fi

# ── 5. Aliases e PATH ────────────────────────────────────────────────────────
section "5. Aliases e PATH"

# Carrega o arquivo num subshell pra inspecionar o que ele define, sem sujar
# a sessão de quem está rodando a validação.
if [ -f "$HOME/.shell_local_exports.sh" ]; then
    for alias_name in dev gs lup cc; do
        if bash -c "shopt -s expand_aliases; . '$HOME/.shell_local_exports.sh' >/dev/null 2>&1; alias $alias_name" &>/dev/null; then
            pass "alias ${alias_name} definido"
        else
            warn "alias ${alias_name} não definido"
        fi
    done
fi

for p in "$HOME/.local/bin" "$HOME/.lando/bin"; do
    case ":$PATH:" in
        *":$p:"*) pass "$(short_path "$p") no PATH" ;;
        *)        warn "$(short_path "$p") fora do PATH desta sessão — abra um novo terminal" ;;
    esac
done

# ── 6. Compatibilidade com Claude Code e outras ferramentas via bash ─────────
section "6. Compatibilidade Claude Code (bash de login)"
#
# O caso que motivou este bloco: Claude Code, hooks de pre-commit e tarefas de
# CI local disparam comandos por um bash não-interativo. O .bashrc padrão do
# Ubuntu faz `return` na primeira linha justamente nesse caso, então nada do
# PATH do usuário é carregado — node/php/lando somem, e o erro que aparece é um
# "command not found" confuso numa ferramenta que está instalada.
#
# A cadeia que realmente vale é a de login: bash -l → ~/.profile → ~/.bashrc.
# É o que testamos aqui, e o bloco que o setup-wsl.sh injeta no topo do
# ~/.bashrc fica ANTES do early-return para sobreviver a ela.

# O elo mais frágil: se ~/.profile não chamar o ~/.bashrc, todo o resto quebra.
if [ -f "$HOME/.profile" ] && grep -q '\.bashrc' "$HOME/.profile"; then
    pass "~/.profile carrega ~/.bashrc (cadeia de login intacta)"
elif [ -f "$HOME/.bash_profile" ] && grep -q '\.bashrc' "$HOME/.bash_profile"; then
    pass "~/.bash_profile carrega ~/.bashrc (cadeia de login intacta)"
else
    fail "nem ~/.profile nem ~/.bash_profile carregam ~/.bashrc — shell de login ignora o PATH"
fi

for tool in node npm php composer git; do
    if bash -lc "command -v $tool" &>/dev/null; then
        pass "bash não-interativo acha ${tool}"
    else
        fail "bash não-interativo NÃO acha ${tool} — Claude Code vai falhar"
    fi
done

# lando e claude são opcionais nesse teste: quem rodou com o setup parcial
# ainda tem um ambiente utilizável.
for tool in lando claude; do
    if bash -lc "command -v $tool" &>/dev/null; then
        pass "bash não-interativo acha ${tool}"
    else
        warn "bash não-interativo não acha ${tool}"
    fi
done

# ── 7. Testes funcionais ─────────────────────────────────────────────────────
section "7. Testes funcionais"

# Docker: instalado é diferente de utilizável. `docker ps` só funciona com o
# daemon rodando E o usuário no grupo docker.
if has docker; then
    if docker ps &>/dev/null; then
        pass "docker ps funciona (daemon ativo, usuário no grupo docker)"
    elif docker info &>/dev/null; then
        pass "daemon Docker ativo"
    else
        if ! groups 2>/dev/null | grep -qw docker; then
            fail "usuário fora do grupo docker — rode: newgrp docker (ou relogue)"
        else
            fail "daemon Docker não responde — rode: sudo service docker start"
        fi
    fi
fi

if has php; then
    if php -r 'exit(0);' &>/dev/null; then
        pass "PHP executa código"
    else
        fail "PHP instalado mas não executa"
    fi

    # Extensões que projetos WordPress/Laravel assumem existir
    MISSING_EXT=""
    for ext in curl mbstring xml zip gd intl bcmath mysqli; do
        php -m 2>/dev/null | grep -qix "$ext" || MISSING_EXT="${MISSING_EXT} ${ext}"
    done
    if [ -z "$MISSING_EXT" ]; then
        pass "extensões PHP presentes (curl mbstring xml zip gd intl bcmath mysqli)"
    else
        warn "extensões PHP ausentes:${MISSING_EXT}"
    fi
fi

if has composer; then
    if composer --version 2>/dev/null | grep -q "Composer version"; then
        pass "Composer responde a --version"
    else
        fail "Composer instalado mas não responde"
    fi
fi

if has gh; then
    if gh auth status &>/dev/null; then
        pass "GitHub CLI autenticado"
    else
        warn "GitHub CLI sem autenticação — rode: gh auth login"
    fi
fi

# ── 8. Ferramentas de produtividade (opcionais) ──────────────────────────────
section "8. Produtividade / IaC / segurança (opcionais)"

for t in gitleaks actionlint tflint trivy infracost terraform-docs k9s \
         lazydocker direnv zoxide mise shellcheck shfmt pre-commit ripgrep; do
    if has "$t" || [ -x "$HOME/.local/bin/$t" ]; then
        pass "$t"
    else
        warn "$t ausente"
    fi
done

# bat e fd vêm com nome sufixado no Ubuntu pra não colidir com pacotes antigos
if has batcat || has bat; then pass "bat"; else warn "bat ausente"; fi
if has fdfind || has fd;  then pass "fd";  else warn "fd ausente";  fi

# ── Resumo ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}"
cat << 'SUMMARY'
  ╔══════════════════════════════════════════════════════╗
  ║                      Resumo                        ║
  ╚══════════════════════════════════════════════════════╝
SUMMARY
echo -e "${RESET}"

echo -e "  ${GREEN}✔ ${PASS} ok${RESET}   ${YELLOW}⚠ ${WARN} avisos${RESET}   ${RED}✖ ${FAIL} falhas${RESET}"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}Falhas críticas:${RESET}"
    for item in "${FAILED_ITEMS[@]}"; do
        echo -e "    ${RED}•${RESET} ${item}"
    done
    echo ""
    echo -e "  ${BOLD}Próximo passo:${RESET} re-execute o setup — ele é idempotente:"
    echo -e "    bash setup-wsl.sh"
    echo ""
    exit 1
fi

if [ "$WARN" -gt 0 ]; then
    echo -e "  ${YELLOW}Ambiente funcional, com ${WARN} aviso(s) acima.${RESET}"
    echo -e "  Avisos são itens opcionais ou ajustes recomendados — nada bloqueante."
else
    echo -e "  ${GREEN}${BOLD}Ambiente 100% validado.${RESET}"
fi
echo ""
exit 0
