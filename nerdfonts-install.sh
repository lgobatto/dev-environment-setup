#!/bin/bash

# Script para instalação de Nerd Fonts - Versão Final
# Uso: curl -fsSL <gist_url> | bash -s -- font1 font2 font3
# Ou: curl -fsSL <gist_url> | bash (para instalar fontes padrão)

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Variável global para arquivos temporários
TEMP_FILES=()

# Função de limpeza
cleanup() {
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        for file in "${TEMP_FILES[@]}"; do
            [[ -f "$file" ]] && rm -f "$file" 2>/dev/null
        done
    fi
}

trap cleanup EXIT INT TERM

# Fontes padrão (com ligaduras e populares)
declare -a default_fonts=(
    "FiraCode"
    "JetBrainsMono"
    "CascadiaCode"
    "Hack"
    "SourceCodePro"
    "UbuntuMono"
)

# Fontes com ligaduras
declare -a ligature_fonts=(
    "FiraCode"
    "JetBrainsMono"
    "CascadiaCode"
    "VictorMono"
    "Iosevka"
    "Hasklig"
    "GeistMono"
)

# Todas as fontes disponíveis
declare -a all_fonts=(
    "3270" "Agave" "AnonymousPro" "Arimo" "AurulentSansMono"
    "BigBlueTerminal" "BitstreamVeraSansMono" "CascadiaCode" "CodeNewRoman"
    "ComicShannsMono" "Cousine" "DaddyTimeMono" "DejaVuSansMono"
    "DroidSansMono" "EnvyCodeR" "FantasqueSansMono" "FiraCode"
    "FiraMono" "GeistMono" "Go-Mono" "Gohu" "Hack" "Hasklig"
    "HeavyData" "Hermit" "iA-Writer" "IBMPlexMono" "Inconsolata"
    "InconsolataGo" "InconsolataLGC" "IntelOneMono" "Iosevka"
    "IosevkaTerm" "JetBrainsMono" "Lekton" "LiberationMono" "Lilex"
    "Meslo" "Monofur" "Monoid" "Mononoki" "MPlus" "Noto"
    "OpenDyslexic" "Overpass" "ProFont" "ProggyClean" "RobotoMono"
    "ShareTechMono" "SourceCodePro" "SpaceMono" "Terminus" "Tinos"
    "Ubuntu" "UbuntuMono" "VictorMono"
)

# Funções auxiliares
font_exists() {
    local font="$1"
    for available_font in "${all_fonts[@]}"; do
        [[ "$available_font" == "$font" ]] && return 0
    done
    return 1
}

show_available_fonts() {
    printf '%s\n' "${all_fonts[@]}" | sort | column -c 80
}

show_ligature_fonts() {
    printf '%s\n' "${ligature_fonts[@]}" | sort | column -c 80
}

detect_downloader() {
    if command -v curl &>/dev/null; then
        echo "curl"
    elif command -v wget &>/dev/null; then
        echo "wget"
    else
        echo ""
    fi
}

test_connectivity() {
    local downloader
    downloader=$(detect_downloader)
    
    case "$downloader" in
        "curl")
            timeout 10 curl -s -I "https://github.com" &>/dev/null
            ;;
        "wget")
            timeout 10 wget -q --spider "https://github.com" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

get_latest_version() {
    local version=""
    local downloader
    downloader=$(detect_downloader)
    
    case "$downloader" in
        "curl")
            version=$(timeout 10 curl -s 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4 2>/dev/null || echo "")
            ;;
        "wget")
            version=$(timeout 10 wget -qO- 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4 2>/dev/null || echo "")
            ;;
    esac
    
    if [[ -z "$version" ]] || [[ "$version" == "null" ]]; then
        echo "v3.4.0"
    else
        echo "$version"
    fi
}

download_file() {
    local url="$1"
    local output="$2"
    local downloader
    downloader=$(detect_downloader)
    
    case "$downloader" in
        "curl")
            timeout 180 curl -L --progress-bar --fail --retry 2 --retry-delay 3 "$url" -o "$output" 2>/dev/null
            ;;
        "wget")
            timeout 180 wget --tries=3 --waitretry=3 --show-progress --progress=bar:force:noscroll "$url" -O "$output" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

install_font() {
    local font="$1"
    local version="$2"
    local fonts_dir="$3"
    
    local zip_file="${font}.zip"
    local download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/${zip_file}"
    
    TEMP_FILES+=("$zip_file")
    
    log "Baixando $font..."
    
    if download_file "$download_url" "$zip_file"; then
        if [[ -f "$zip_file" ]] && [[ -s "$zip_file" ]]; then
            log "Extraindo $font..."
            if unzip -qq -o "$zip_file" -d "$fonts_dir" 2>/dev/null; then
                success "$font instalada com sucesso"
                rm -f "$zip_file"
                return 0
            else
                error "Falha ao extrair $font"
                rm -f "$zip_file"
                return 1
            fi
        else
            error "Arquivo baixado de $font está vazio ou corrompido"
            rm -f "$zip_file"
            return 1
        fi
    else
        error "Falha ao baixar $font"
        rm -f "$zip_file" 2>/dev/null
        return 1
    fi
}

main() {
    log "=== Instalador de Nerd Fonts ==="
    
    # Verificar dependências
    local missing_deps=()
    local downloader
    downloader=$(detect_downloader)
    
    [[ -z "$downloader" ]] && missing_deps+=("curl ou wget")
    
    for cmd in unzip fc-cache timeout; do
        command -v "$cmd" &>/dev/null || missing_deps+=("$cmd")
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Dependências ausentes: ${missing_deps[*]}"
        error "Ubuntu/Debian: sudo apt install curl wget unzip fontconfig coreutils"
        error "Fedora/RHEL: sudo dnf install curl wget unzip fontconfig coreutils"
        error "Arch: sudo pacman -S curl wget unzip fontconfig coreutils"
        exit 1
    fi
    
    log "Usando $downloader para download"
    
    # Testar conectividade
    if ! test_connectivity; then
        error "Não foi possível conectar ao GitHub. Verifique sua conexão."
        exit 1
    fi
    
    # Diretório de fontes
    local fonts_dir="${HOME}/.local/share/fonts/NerdFonts"
    [[ ! -d "$fonts_dir" ]] && mkdir -p "$fonts_dir"
    
    # Processar argumentos
    local fonts_to_install=()
    
    if [[ $# -eq 0 ]]; then
        fonts_to_install=("${default_fonts[@]}")
    else
        for arg in "$@"; do
            case "$arg" in
                "--help"|"-h")
                    echo "Uso: $0 [fonte1] [fonte2] ... [fonteN]"
                    echo ""
                    echo "Opções:"
                    echo "  --help, -h         Mostrar esta ajuda"
                    echo "  --list, -l         Listar todas as fontes disponíveis"
                    echo "  --ligatures        Listar fontes com ligaduras"
                    echo "  --default, -d      Instalar fontes padrão"
                    echo "  --all-ligatures    Instalar todas as fontes com ligaduras"
                    echo ""
                    echo "Se nenhuma fonte for especificada, as fontes padrão serão instaladas."
                    exit 0
                    ;;
                "--list"|"-l")
                    log "Fontes disponíveis:"
                    show_available_fonts
                    exit 0
                    ;;
                "--ligatures")
                    log "Fontes com ligaduras:"
                    show_ligature_fonts
                    exit 0
                    ;;
                "--default"|"-d")
                    fonts_to_install=("${default_fonts[@]}")
                    ;;
                "--all-ligatures")
                    fonts_to_install=("${ligature_fonts[@]}")
                    ;;
                *)
                    if font_exists "$arg"; then
                        fonts_to_install+=("$arg")
                    else
                        warn "Fonte '$arg' não existe. Use --list para ver fontes disponíveis."
                    fi
                    ;;
            esac
        done
    fi
    
    if [[ ${#fonts_to_install[@]} -eq 0 ]]; then
        error "Nenhuma fonte válida para instalar."
        exit 1
    fi
    
    log "Fontes a serem instaladas: ${fonts_to_install[*]}"
    
    # Obter versão
    local version
    version=$(get_latest_version)
    log "Usando versão: $version"
    
    # Instalar fontes
    local installed_count=0
    local failed_count=0
    
    for font in "${fonts_to_install[@]}"; do
        if install_font "$font" "$version" "$fonts_dir"; then
            ((installed_count++))
        else
            ((failed_count++))
        fi
    done
    
    # Limpeza
    log "Limpando arquivos desnecessários..."
    find "$fonts_dir" -name '*.txt' -delete 2>/dev/null || true
    find "$fonts_dir" -name '*.md' -delete 2>/dev/null || true
    find "$fonts_dir" -name 'LICENSE*' -delete 2>/dev/null || true
    find "$fonts_dir" -name 'README*' -delete 2>/dev/null || true
    find "$fonts_dir" -name 'OFL.txt' -delete 2>/dev/null || true
    find "$fonts_dir" -name 'Windows Compatible' -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Atualizar cache
    log "Atualizando cache de fontes..."
    fc-cache -fv "$fonts_dir" &>/dev/null && success "Cache atualizado" || warn "Erro ao atualizar cache"
    
    # Resumo
    echo ""
    success "=== Instalação Concluída ==="
    success "Fontes instaladas: $installed_count"
    [[ $failed_count -gt 0 ]] && warn "Falhas: $failed_count"
    
    local total_fonts
    total_fonts=$(find "$fonts_dir" -name "*.ttf" -o -name "*.otf" 2>/dev/null | wc -l)
    success "Total de arquivos de fonte: $total_fonts"
    success "Diretório: $fonts_dir"
    log "Reinicie aplicações para usar as novas fontes."
}

# Executar
main "$@"