# 🚀 Instalador de Ambiente de Desenvolvimento

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Zorin%20%7C%20Mint%20%7C%20WSL-blue.svg)](https://ubuntu.com/)

Scripts interativos para configuração completa de ambiente de desenvolvimento em distribuições baseadas em Ubuntu.

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Ferramentas Suportadas](#-ferramentas-suportadas)
- [Instalação Rápida](#-instalação-rápida)
- [Uso Detalhado](#-uso-detalhado)
- [Compatibilidade](#-compatibilidade)
- [Documentação](#-documentação)
- [Contribuição](#-contribuição)
- [Licença](#-licença)

## 🎯 Visão Geral

Este projeto fornece **quatro scripts complementares** para configurar um ambiente de desenvolvimento completo:

1. **`install.sh`** - Script master com menu interativo
2. **`gui-apps.sh`** - Instalador de aplicações gráficas
3. **`shell-apps.sh`** - Instalador de ferramentas de terminal
4. **`ssh-git-setup.sh`** - Configurador SSH + Git com múltiplas identidades
5. **`nerdfonts-install.sh`** - Instalador dedicado de Nerd Fonts

### ✨ Características

- 🎯 **100% Interativo** - você escolhe o que instalar
- 🐧 **Multi-distro** - Ubuntu, Zorin OS, Linux Mint, WSL
- 📊 **Logs detalhados** de instalação
- 🔄 **Detecção automática** de ferramentas já instaladas
- 🛡️ **Tratamento robusto de erros**
- 🎨 **Interface colorida e intuitiva**
- 🧹 **Limpeza automática** de arquivos temporários

## 🔠️ Ferramentas Suportadas

### 🗺️ **Aplicações GUI** (`gui-apps.sh`)

**Editores:**
- Visual Studio Code
- Cursor AI Editor

**Navegadores:**
- Google Chrome

**Terminais:**
- Warp Terminal (AI Terminal)

**Comunicação:**
- Discord
- Slack

**Mídia:**
- Spotify

**Desenvolvimento:**
- Postman (API Testing)
- DBeaver CE (Database Manager)
- Podman Desktop (Container Manager)

**Utilitários:**
- 1Password Desktop
- Termius SSH Client

**Fontes:**
- Nerd Fonts (FiraCode, JetBrains Mono, etc.)

### ⚡ **Ferramentas Shell** (`shell-apps.sh`)

**Runtime & Gerenciadores:**
- Volta + Node.js LTS + Yarn
- PHP 8.3 CLI + Composer  
- Python3 + pip3 + ferramentas

**Containers & Deploy:**
- Docker Engine + Docker Compose
- Lando (desenvolvimento local)

**Kubernetes & Infrastructure:**
- kubectl + kubectx/kubens
- Terraform

**Cloud & APIs:**
- AWS CLI v2
- GitHub CLI

**Segurança:**
- 1Password CLI

**Shell:**
- Zsh + Oh My Zsh

### 🔧 **SSH + Git** (`ssh-git-setup.sh`)

**SSH + 1Password:**
- Configuração SSH básica com 1Password Agent
- Integração automática com chaves SSH

**Git Global:**
- Configuração global (nome, email, etc.)
- Configurações básicas (branch, push, editor)

**Múltiplas Identidades:**
- Hosts SSH customizados (github-empresa, gitlab-empresa)
- Configuração Git condicional por diretório
- Suporte a múltiplas chaves SSH

## 🚀 Instalação Rápida

### Método 1: One-liner (Recomendado)

```bash
# Baixar e executar script master
curl -fsSL https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/install.sh | bash
```

### Método 2: Clone + Execute

```bash
# Clonar repositório
git clone https://github.com/lgobatto/dev-environment-setup.git
cd dev-environment-setup

# Executar script master (menu interativo)
./install.sh

# OU executar scripts individuais
./gui-apps.sh        # Aplicações gráficas
./shell-apps.sh      # Ferramentas de terminal
./ssh-git-setup.sh   # SSH + Git config
```

### Método 3: Scripts Individuais

```bash
# Apps GUI
curl -fsSL https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/gui-apps.sh | bash

# Apps Shell
curl -fsSL https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/shell-apps.sh | bash

# SSH + Git
curl -fsSL https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/ssh-git-setup.sh | bash
```

## 📚 Uso Detalhado

### 1. Script Master (`install.sh`)

O script master oferece um **menu interativo** para executar os instaladores especializados:

```bash
./install.sh
```

**Opções do menu:**
1. 🗺️ **Apps GUI** - Aplicações gráficas
2. ⚡ **Apps Shell** - Ferramentas de terminal  
3. 🔧 **SSH + Git** - Configuração e identidades
4. 🚀 **Instalar Tudo** - Executar todos os scripts
5. ❌ **Sair**

**Recursos:**
- ✅ Detecção automática do sistema
- ✅ Status dos scripts disponíveis
- ✅ Execução inteligente (pula GUI no WSL)
- ✅ Interface limpa com clear entre operações

### 2. Apps GUI (`gui-apps.sh`)

Instala aplicações gráficas essenciais:

```bash
./gui-apps.sh
```

**Fluxo de instalação:**
1. 🔍 Detecção do sistema
2. 📦 Instalação de dependências GUI
3. 🎯 Menu interativo para cada app
4. 📊 Resumo final

**Recursos avançados:**
- ✅ Pula no WSL automaticamente
- ✅ Verifica apps já instalados
- ✅ Logs em `/tmp/gui-apps-installer-*.log`

### 3. Apps Shell (`shell-apps.sh`)

Instala ferramentas de linha de comando e desenvolvimento:

```bash
./shell-apps.sh
```

**Fluxo de instalação:**
1. 🔍 Detecção do sistema
2. 📦 Dependências básicas (curl, wget, git, etc.)
3. ⚡ Runtimes (Node.js, PHP, Python)
4. 🐳 Containers (Docker, Lando)
5. ☁️ Cloud tools (AWS CLI, Terraform)
6. 🐚 Shell (Zsh + Oh My Zsh)

**Recursos:**
- ✅ Logs em `/tmp/shell-apps-installer-*.log`
- ✅ Configuração automática de ambientes
- ✅ Integração entre ferramentas (Volta + Node)

### 4. SSH + Git (`ssh-git-setup.sh`)

Configura SSH, Git e múltiplas identidades:

```bash
./ssh-git-setup.sh
```

**Fluxo de configuração:**
1. 🔐 SSH + 1Password integration
2. 🔧 Configuração Git global
3. 🏢 Setup de múltiplas identidades
4. ✅ Testes de conectividade

**Exemplo de uso após configuração:**
```bash
# Projeto pessoal (credenciais padrão)
git clone git@github.com:username/repo.git

# Projeto empresarial (credenciais específicas)
cd ~/work/empresa/
git clone git@github-empresa:org/repo.git
```

## 🐧 Compatibilidade

### Distribuições Suportadas
- ✅ **Ubuntu** (20.04, 22.04, 24.04)
- ✅ **Zorin OS** (16, 17)
- ✅ **Linux Mint** (20, 21)
- ✅ **Pop!_OS** (20.04, 22.04)
- ✅ **Elementary OS** (6.x, 7.x)
- ✅ **WSL** (Windows Subsystem for Linux)

### Requisitos
- 🐧 Sistema baseado em Ubuntu/Debian
- 👤 Usuário com privilégios sudo
- 🌐 Conexão com internet
- 📦 `curl` ou `wget` (instalado automaticamente)

### Limitações do WSL
- ❌ Podman Desktop (interface gráfica)
- ❌ Aplicações GUI em geral
- ✅ Todos os outros tools funcionam perfeitamente

## 🔧 Configurações Avançadas

### SSH + 1Password

O script configura automaticamente:

```bash
# ~/.ssh/config
Host *
    IdentityAgent ~/.1password/agent.sock
    AddKeysToAgent yes

# Hosts customizados
Host github-empresa
    HostName github.com
    User git
    IdentitiesOnly yes
```

### Git Condicional

Configuração automática baseada em diretório:

```bash
# ~/.gitconfig
[includeIf "gitdir:~/work/empresa/"]
    path = ~/.config/git/config-empresa
```

### Estrutura de Diretórios Recomendada

```
~/work/
├── personal/           # Projetos pessoais
│   └── my-project/
└── empresa/           # Projetos da empresa
    └── company-project/
```

## 📖 Documentação

### Logs e Troubleshooting

Os scripts geram logs detalhados:

```bash
# Log do instalador principal
tail -f /tmp/dev-installer-*.log

# Verificar instalações
which code volta docker aws kubectl
```

### Personalização

Você pode modificar os scripts para:
- ✏️ Adicionar novas ferramentas
- ⚙️ Alterar configurações padrão
- 🎨 Customizar interface
- 📁 Mudar estrutura de diretórios

### Exemplos de Comandos Úteis

```bash
# Verificar versões instaladas
./install.sh --version  # (futuro)

# Testar configuração Git
git config --list --show-origin

# Testar SSH
ssh -T git@github.com
ssh -T git@github-empresa
```

## 🤝 Contribuição

Contribuições são bem-vindas! Por favor:

1. 🍴 Faça um fork do projeto
2. 🌿 Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. 📝 Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. 📤 Push para a branch (`git push origin feature/AmazingFeature`)
5. 🔄 Abra um Pull Request

### Diretrizes

- ✅ Mantenha compatibilidade com distribuições suportadas
- ✅ Adicione tratamento de erros
- ✅ Documente novas features
- ✅ Teste em ambiente limpo

## 🐛 Problemas Conhecidos

- 🔄 **Docker**: Necessário logout/login após instalação para usar sem sudo
- 🔐 **1Password**: SSH Agent precisa ser configurado manualmente no app
- 🎨 **Nerd Fonts**: Aplicações podem precisar ser reiniciadas

## 📈 Roadmap

- [ ] Suporte para Arch Linux
- [ ] Configuração de IDEs adicionais
- [ ] Template de dotfiles
- [ ] Scripts de backup/restore
- [ ] GUI opcional com dialog/whiptail

## 🏆 Créditos

Desenvolvido por **Leonardo Gobatto** ([@lgobatto](https://github.com/lgobatto))

Baseado em sessão de configuração de ambiente de desenvolvimento com assistente IA.

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

---

<div align="center">

**🌟 Se este projeto te ajudou, considere dar uma estrela! 🌟**

[![GitHub stars](https://img.shields.io/github/stars/lgobatto/dev-environment-setup?style=social)](https://github.com/lgobatto/dev-environment-setup/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/lgobatto/dev-environment-setup?style=social)](https://github.com/lgobatto/dev-environment-setup/network/members)

</div>