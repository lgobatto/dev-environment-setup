# dev-environment-setup

> Ambiente de desenvolvimento Windows + WSL2, orientado a projetos PHP/WordPress com Lando.
> Idempotente — seguro para re-executar a qualquer momento.

## Arquitetura: o que fica onde

A separação correta entre Windows e WSL2 é a chave da performance e da sanidade mental:

| Windows | WSL2 (Ubuntu 24.04) |
|---|---|
| VS Code + Remote WSL | Node.js (via nvm) |
| Cursor | PHP 8.3 + Composer |
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

## Setup rápido

### 1. Windows (PowerShell como Administrador)

```powershell
# Clonar este repo
git clone git@github.com:lgobatto/dev-environment-setup.git
cd dev-environment-setup

# Executar (instala WSL2, Ubuntu 24.04, apps Windows, bootstrap WSL)
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows.ps1

# Com 1Password:
.\setup-windows.ps1 -Install1Password

# Só WSL2 + .wslconfig, sem instalar apps:
.\setup-windows.ps1 -SkipApps
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

### 3. Migrar projetos para o WSL2

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
- **nvm** + Node.js LTS (sempre última versão)
- **PHP 8.3** + Composer (via `ppa:ondrej/php`)
- **Lando CLI** — versão mais recente via GitHub releases
- **Claude Code CLI** — `@anthropic-ai/claude-code`
- **GitHub CLI**
- **Zsh** + Oh My Zsh + Powerlevel10k + plugins (autosuggestions, syntax-highlighting, completions)
- Git configurado para WSL (`core.autocrlf=input`, `init.defaultBranch=main`)

**Variáveis de ambiente:**
```bash
GIT_NAME="Seu Nome"           # Nome para git config
GIT_EMAIL="seu@email.com"     # Email para git config
INSTALL_1PASSWORD=1           # Configura 1Password SSH agent
NODE_VERSION="lts"            # "lts", "latest" ou versão específica "22"
PHP_VERSION="8.3"             # Versão do PHP
```

**Aliases instalados:**
```bash
dev      # cd ~/projects
lup      # lando start
ldn      # lando stop
ldev     # lando dev
lbuild   # lando theme-build
lflush   # lando flush
lacorn   # lando acorn
cc       # claude (Claude Code CLI)
```

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
| `setup-wsl.sh` | ✅ | ✅ | ⚠️ parcial |
| `migrate-project.sh` | ✅ | ✅ | ✅ |
| `ssh-git-setup.sh` | ✅ | ✅ | ✅ |
| `nerdfonts-install.sh` | ✅ WSL2 | ✅ | ❌ |

---

## Estrutura do repositório

```
dev-environment-setup/
├── setup-windows.ps1       # Setup Windows: WSL2 + apps via winget
├── setup-wsl.sh            # Setup WSL2: Docker Engine, Node, PHP, Lando, Claude Code
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
