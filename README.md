# dev-environment-setup

> Ambiente de desenvolvimento Windows + WSL2, orientado a projetos PHP/WordPress com Lando.
> Idempotente — seguro para re-executar a qualquer momento.

## Arquitetura: o que fica onde

A separação correta entre Windows e WSL2 é a chave da performance e da sanidade mental:

| Windows | WSL2 (Ubuntu 24.04) |
|---|---|
| VS Code + Remote WSL | Node.js (via nvm) |
| Cursor | PHP 8.4 + Composer |
| Chrome, Windows Terminal | **Docker Engine** (sem Docker Desktop) |
| 1Password (opcional) | Lando CLI |
| GitHub Desktop | Claude Code CLI |
| — | Git, Zsh, GitHub CLI |

### Por que Docker Engine e não Docker Desktop?

```
Docker Desktop  →  GUI, +500MB RAM, I/O lento entre Windows↔WSL2
Docker Engine   →  CLI lean, rápido, nativo no Linux  ← usamos este
```

Projetos em `~/projects/` (filesystem Linux nativo EXT4) são lidos pelo Docker diretamente,
sem passar pela camada de interop Windows → **ganho de I/O de ~10-20x** comparado a projetos em `C:\Users\...`.

---

## Instalação em uma linha

Abra o **PowerShell como Administrador** e execute:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/install.ps1 -OutFile "$env:TEMP\install.ps1"; & "$env:TEMP\install.ps1"
```

Com 1Password:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/install.ps1 -OutFile "$env:TEMP\install.ps1"; & "$env:TEMP\install.ps1" -Install1Password
```

> O script clona automaticamente o repositório em `%USERPROFILE%\dev-environment-setup` se necessário.

---

## Setup rápido (clone manual)

```powershell
# Clonar e executar
git clone git@github.com:lgobatto/dev-environment-setup.git
cd dev-environment-setup
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install.ps1

# Com 1Password:
.\install.ps1 -Install1Password

# Só WSL2 + .wslconfig, sem instalar apps:
.\install.ps1 -SkipApps
```

O script detecta o hardware da máquina e calcula automaticamente a alocação ideal de RAM e CPUs para o WSL2:

| RAM da máquina | WSL2 RAM | CPUs |
|---|---|---|
| 8GB  | ~3GB | 4 |
| 16GB | ~6GB | 4 |
| 32GB | ~14GB | 4–8 |
| 64GB | ~26GB | 8 |
| 96GB+ | ~28GB (máx 32GB) | 8–12 |

### 2. Ubuntu 24.04 (dentro do WSL2)

O `setup-windows.ps1` já executa o `setup-wsl.sh` automaticamente. Se precisar rodar manualmente:

```bash
bash setup-wsl.sh

# Com opções:
GIT_NAME="Leonardo Gobatto" GIT_EMAIL="leo@email.com" INSTALL_1PASSWORD=1 bash setup-wsl.sh
```

### 3. Validar o que ficou instalado

```bash
bash validate-env.sh
```

O setup não aborta quando um passo falha — ele avisa e segue. Este script diz
o que realmente ficou de pé e sai com código 1 se algo crítico faltar.

### 4. Migrar projetos para o WSL2

```bash
# Clonar projeto direto no filesystem Linux (~/projects/)
REPO_URL="git@github.com:org/repo.git" bash migrate-project.sh

# Modo interativo (lista projetos disponíveis)
bash migrate-project.sh
```

---

## Scripts

### `setup-windows.ps1` — Windows

Configura o lado Windows do ambiente. Requer PowerShell como Administrador.

**O que faz:**
- Solicita interativamente nome e email para `git config` (aplicados no WSL2)
- Instala e atualiza WSL2
- Instala Ubuntu 24.04 LTS
- Gera `.wslconfig` otimizado com base no hardware detectado
- Instala apps via `winget`: VS Code, Cursor, Chrome, Windows Terminal, GitHub Desktop, Postman, **JetBrains Mono Nerd Font**
- Configura automaticamente a fonte JetBrainsMono Nerd Font no Windows Terminal
- Instala extensões VS Code para WSL (Remote WSL, Remote Explorer)
- Faz bootstrap do WSL executando `setup-wsl.sh`

**Parâmetros:**
```powershell
-Install1Password   # Inclui 1Password e 1Password CLI
-SkipApps           # Pula instalação de apps (só WSL2 + .wslconfig)
-SkipWSL            # Pula WSL2 (só instala apps Windows)
```

---

### `setup-wsl.sh` — WSL2 Ubuntu

Configura o ambiente de desenvolvimento dentro do Ubuntu 24.04. Idempotente.

**O que instala:**
- **Docker Engine** — sem Docker Desktop, direto no Linux
- **nvm** + Node.js LTS (sempre última versão, com fallback se a API cair)
- **PHP 8.4** + Composer (via `ppa:ondrej/php`)
- **Lando CLI** — versão mais recente via GitHub releases
- **Claude Code CLI** — `@anthropic-ai/claude-code`
- **GitHub CLI** — oferece `gh auth login` na hora, em terminal interativo
- **Zsh** + Oh My Zsh + Powerlevel10k + plugins (autosuggestions, syntax-highlighting, completions) — pule com `SKIP_ZSH=1`
- Git configurado para WSL (`core.autocrlf=input`, `init.defaultBranch=main`)

**O que configura no shell** — ver [Configuração de shell](#configuração-de-shell-bash--zsh):
- `~/.shell_local_exports.sh` — PATH, nvm, aliases e hooks; fonte única lida por bash **e** zsh
- `~/.bashrc` — carrega o arquivo acima antes do early-return de shell não-interativo
- `~/.zshrc` — Oh My Zsh + Powerlevel10k, carregando a mesma fonte única

> Roda também em **Linux nativo** (Zorin/Ubuntu): o passo do `/etc/wsl.conf` é
> pulado automaticamente fora do WSL. A release do Ubuntu é detectada em tempo
> de execução — 24.04 e 26.04 LTS funcionam sem editar o script.

**Variáveis de ambiente:**
```bash
GIT_NAME="Seu Nome"           # Nome para git config
GIT_EMAIL="seu@email.com"     # Email para git config
INSTALL_1PASSWORD=1           # Configura 1Password SSH agent
NODE_VERSION="lts"            # "lts", "latest" ou versão específica "22"
NODE_FALLBACK="24"            # Usado se `nvm install --lts` falhar
PHP_VERSION="8.4"             # Versão do PHP
SKIP_ZSH=1                    # Não instala Zsh/Oh My Zsh/Powerlevel10k
INSTALL_PRODTOOLS=0           # Não instala CLIs de produtividade/IaC/segurança
GH_AUTH_PROMPT=0              # Nunca pergunta sobre `gh auth login`
```

**Aliases instalados** (todos em `~/.shell_local_exports.sh`):
```bash
dev      # cd ~/projects
gs       # git status
lup      # lando start
ldn      # lando stop
ldev     # lando dev
lbuild   # lando theme-build
lflush   # lando flush
lacorn   # lando acorn
cc       # claude (Claude Code CLI)
exports  # abre ~/.shell_local_exports.sh no $EDITOR
custom   # abre ~/.shell_local_custom.sh no $EDITOR
```

---

### `validate-env.sh` — Validação pós-instalação

O `setup-wsl.sh` é tolerante a falha por design: um repositório apt fora do ar
gera um aviso e o script continua. Bom para não travar o onboarding, ruim para
descobrir o que ficou faltando — daí este script.

```bash
bash validate-env.sh            # relatório completo
bash validate-env.sh --quiet    # só o resumo e as falhas
```

**O que verifica:**

| Bloco | Verificação |
|---|---|
| 1. Ferramentas CLI | git, docker, node, npm, php, composer, lando, gh, claude, nvm |
| 2. Versões mínimas | PHP ≥ 8.4, Node em linha LTS (major par) |
| 3. Configurações | `~/.gitconfig`, `user.name`/`user.email`, e se bash **e** zsh carregam a fonte única |
| 4. Diretórios | `~/projects`, `~/.ssh` (permissão 700), `~/.local/bin`; alerta se `~/projects` cair em `/mnt/*` |
| 5. Aliases e PATH | aliases definidos, `~/.local/bin` e `~/.lando/bin` no PATH |
| 6. Claude Code | se a cadeia de login (`bash -l` → `~/.profile` → `~/.bashrc`) acha node/php/composer/lando |
| 7. Testes funcionais | `docker ps` de verdade, PHP executa código, extensões PHP presentes, `gh auth status` |
| 8. Produtividade | gitleaks, tflint, trivy, k9s, direnv, zoxide, mise e afins (opcionais) |

Sai com código **0** se nada crítico falhou e **1** caso contrário — dá para usar
em CI. Itens opcionais entram como aviso, não como falha.

---

## Configuração de shell (bash + zsh)

Aliases, PATH e o carregamento do nvm viviam só no `~/.zshrc`. Quem abre o
terminal como usuário nunca percebe o problema, mas ferramentas que disparam
comandos por um bash não-interativo — **Claude Code**, hooks de `pre-commit`,
tarefas de CI local — herdavam um PATH sem `node`, sem `lando` e sem
`~/.local/bin`, e falhavam com um `command not found` confuso em ferramentas
que estavam instaladas.

O setup resolve isso com uma fonte única:

```
~/.shell_local_exports.sh     PATH, nvm, aliases, hooks (direnv/zoxide/mise)
        ↑                     sh portável — sem arrays, sem [[ ]]
        ├── ~/.bashrc         bloco no TOPO, antes do early-return de
        │                     shell não-interativo
        └── ~/.zshrc          depois do oh-my-zsh.sh, para os nossos
                              aliases ganharem dos plugins do OMZ
~/.shell_local_custom.sh      suas customizações — nunca sobrescrito
```

**Por que o bloco fica no topo do `~/.bashrc`:** o `.bashrc` padrão do Ubuntu
começa com `case $- in *i*) ;; *) return;; esac`. Num shell não-interativo ele
retorna ali mesmo, então qualquer coisa apendada no fim do arquivo nunca roda.
A cadeia que importa é a de login: `bash -l` → `~/.profile` → `~/.bashrc`.

**Onde editar o quê:**

| Quero mudar | Arquivo |
|---|---|
| Um alias, uma entrada de PATH, uma variável | `~/.shell_local_exports.sh` (ou `exports`) |
| Algo só meu, que o setup não deve sobrescrever | `~/.shell_local_custom.sh` (ou `custom`) |
| Tema, plugin ou prompt do zsh | `~/.zshrc` |
| Histórico, completion ou prompt do bash | `~/.bashrc`, fora do bloco marcado |

O `setup-wsl.sh` reescreve `~/.shell_local_exports.sh` a cada execução, sempre
com backup em `~/.shell_local_exports.sh.backup.<timestamp>`. No `~/.bashrc`
ele só troca o bloco entre os marcadores `# >>> setup-wsl.sh managed >>>` e
`# <<< setup-wsl.sh managed <<<` — se o arquivo já existia com configuração de
terceiro (o `ssh-git-setup.sh` apenda o `SSH_AUTH_SOCK` do 1Password ali), o
resto é preservado.

---

### `setup-zorin-apps.sh` — Linux nativo (Zorin OS / Ubuntu)

Setup de **Linux nativo** — equivalente do `setup-windows.ps1` para quem roda
Zorin OS / Ubuntu direto, sem WSL. Instala os apps GUI e, ao final, chama o
`setup-wsl.sh` para os CLIs. Idempotente.

**O que instala:**
- **apt (repos oficiais):** VS Code, Google Chrome, Warp, PowerShell 7
- **apt:** Java 8 (`openjdk-8-jre`), 1Password CLI (`op`)
- **.deb nativo:** GitKraken, DBeaver, GitHub Desktop — *não* Flatpak, para
  acesso direto a `~/.ssh`, SSH agent e pastas de projeto
- **flatpak (flathub):** Firefox, Discord, Spotify, Postman
- **Nerd Fonts** via `nerdfonts-install.sh`
- **CLIs de dev** via `setup-wsl.sh` (com `SKIP_ZSH=1`)

```bash
bash setup-zorin-apps.sh

# Pular apps individuais (=0):
INSTALL_DISCORD=0 INSTALL_SPOTIFY=0 bash setup-zorin-apps.sh
```

---

### `setup-macos.sh` — macOS (Apple Silicon / Intel)

Setup de **macOS** — equivalente do `setup-zorin-apps.sh` para quem roda Mac.
Usa o Homebrew como gerenciador único: *formula* para CLI, *cask* para app
GUI. Idempotente, e não aborta o script inteiro quando um pacote falha — ele
registra a falha, segue, e lista tudo no resumo final.

**Pré-requisitos** (pedem senha de administrador, então não rodam desatendidos):

```bash
xcode-select --install     # git, clang, make — diálogo gráfico
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**O que instala:**
- **CLIs base:** git, gh, jq, node, php, composer, wget, coreutils
- **1Password:** app + CLI (`op`)
- **Docker:** Docker Desktop (padrão) ou colima — ver abaixo
- **Lando**, **Claude Code**
- **Cloud/infra:** awscli, terraform (tap da HashiCorp), cloudflared, doctl,
  glab, uv, wrangler (npm)
- **Produtividade/IaC/segurança:** gitleaks, direnv, zoxide, mise, shellcheck,
  shfmt, pre-commit, tflint (cask do tap terraform-linters), trivy, infracost,
  terraform-docs, actionlint, eza, bat, ripgrep, fd, k9s, lazydocker, fzf
- **Apps GUI (cask):** VS Code, Warp, Chrome, DBeaver, GitKraken, Firefox,
  Discord, Spotify
- **Nerd Fonts:** MesloLG, FiraCode

```bash
bash setup-macos.sh

# Só CLIs, sem app gráfico:
INSTALL_GUI=0 bash setup-macos.sh

# Pular apps individuais (=0):
INSTALL_DISCORD=0 INSTALL_SPOTIFY=0 bash setup-macos.sh
```

**Docker: `desktop` ou `colima`.** O padrão é o Docker Desktop, porque é o
runtime que o Lando suporta oficialmente no macOS. Ele exige assinatura paga
para empresas acima de 250 funcionários ou US$ 10M de faturamento. A
alternativa FOSS — equivalente ao que o setup Linux faz, Engine sem Desktop —
é o colima:

```bash
DOCKER_RUNTIME=colima bash setup-macos.sh
```

**Por que alguns pacotes não vêm do core do Homebrew:**

| Ferramenta | Motivo | Comando |
|---|---|---|
| `terraform` | a formula saiu do core quando a HashiCorp trocou a licença para BUSL (2023) | `brew install hashicorp/tap/terraform` |
| `tflint` | distribuído pelo tap do projeto, e como **cask** | `brew install --cask terraform-linters/tap/tflint` |
| `wrangler` | a Cloudflare não mantém formula | `npm install -g wrangler` |

---

### `migrate-project.sh` — Migração de projetos

Move (ou clona) projetos do filesystem Windows para `~/projects/` no WSL2 nativo.

```bash
# Clonar por URL (recomendado — clona com submodules):
REPO_URL="git@github.com:org/projeto.git" bash migrate-project.sh

# Por nome (copia .env do Windows, verifica submodules):
PROJECT_NAME="meu-projeto" bash migrate-project.sh

# Interativo:
bash migrate-project.sh
```

---

### `ssh-git-setup.sh` — SSH multi-identidade

Configura SSH com múltiplas identidades Git (GitHub pessoal, GitHub empresa, GitLab, etc.)
com suporte a 1Password SSH agent.

### `nerdfonts-install.sh` — Nerd Fonts

Instala Nerd Fonts (FiraCode, JetBrainsMono, CascadiaCode, etc.) no Linux/WSL2.

---

## 1Password SSH Agent (opcional, mas recomendado)

O 1Password funciona como SSH agent, eliminando a necessidade de gerenciar chaves manualmente.

**Setup:**
1. Instale o 1Password no Windows (`setup-windows.ps1 -Install1Password`)
2. Abra 1Password → Settings → Developer
3. Ative **"SSH Agent"**
4. Ative **"Integrate with WSL"**
5. O `SSH_AUTH_SOCK` e `~/.ssh/config` são configurados automaticamente no WSL2

---

## Testar sem risco (Multipass)

Para validar o `setup-wsl.sh` em uma VM descartável antes de rodar no sistema real:

```powershell
# Instalar Multipass
winget install Canonical.Multipass

# Criar VM Ubuntu 24.04
multipass launch 24.04 --name dev-test --cpus 4 --memory 8G --disk 30G
multipass shell dev-test
```

```bash
# Dentro da VM: testar o script
bash /mnt/c/Users/SEU_USUARIO/Work/dev-environment-setup/setup-wsl.sh

# Destruir sem rastro quando terminar
# (no PowerShell): multipass delete dev-test && multipass purge
```

---

## Compatibilidade

| Script | Windows (WSL2) | Linux nativo | macOS |
|---|---|---|---|
| `setup-windows.ps1` | ✅ | ❌ | ❌ |
| `setup-zorin-apps.sh` | ❌ | ✅ | ❌ |
| `setup-macos.sh` | ❌ | ❌ | ✅ |
| `setup-wsl.sh` | ✅ | ✅ | ⚠️ parcial |
| `validate-env.sh` | ✅ | ✅ | ⚠️ parcial |
| `migrate-project.sh` | ✅ | ✅ | ✅ |
| `ssh-git-setup.sh` | ✅ | ✅ | ✅ |
| `nerdfonts-install.sh` | ✅ WSL2 | ✅ | ❌ |

---

## Estrutura do repositório

```
dev-environment-setup/
├── setup-windows.ps1       # Setup Windows: WSL2 + apps via winget
├── setup-zorin-apps.sh     # Setup Linux nativo (Zorin/Ubuntu): apps GUI + CLIs
├── setup-macos.sh          # Setup macOS: apps GUI + CLIs via Homebrew
├── setup-wsl.sh            # Setup WSL2: Docker Engine, Node, PHP, Lando, Claude Code
├── validate-env.sh         # Validação pós-instalação (exit 1 se algo crítico falhou)
├── migrate-project.sh      # Migrar projetos para ~/projects/ no WSL2
├── ssh-git-setup.sh        # SSH multi-identidade com 1Password
├── nerdfonts-install.sh    # Instalador de Nerd Fonts
├── ZSH_SETUP.md            # Guia pós-instalação do Powerlevel10k
├── archive/                # Scripts legados (referência histórica)
│   ├── install.sh
│   ├── gui-apps.sh
│   ├── shell-apps.sh
│   └── zsh-setup.sh
└── README.md
```

---

## License

MIT © [Leonardo Gobatto](https://github.com/lgobatto)
