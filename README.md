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

Este projeto fornece **dois scripts complementares** para configurar um ambiente de desenvolvimento completo:

1. **`install.sh`** - Instalador principal de ferramentas
2. **`git-setup.sh`** - Configurador Git com múltiplas identidades

### ✨ Características

- 🎯 **100% Interativo** - você escolhe o que instalar
- 🐧 **Multi-distro** - Ubuntu, Zorin OS, Linux Mint, WSL
- 📊 **Logs detalhados** de instalação
- 🔄 **Detecção automática** de ferramentas já instaladas
- 🛡️ **Tratamento robusto de erros**
- 🎨 **Interface colorida e intuitiva**
- 🧹 **Limpeza automática** de arquivos temporários

## 🛠️ Ferramentas Suportadas

### 📝 **Editores**
- Visual Studio Code

### ⚡ **Runtime & Ferramentas**
- Volta + Node.js LTS + Yarn
- PHP 8.3 CLI + Composer  
- Python3 + pip3

### 🐳 **Containers & Deploy**
- Docker Engine + Docker Compose
- Lando (desenvolvimento local)
- Podman Desktop (interface gráfica para Docker)

### ☸️ **Kubernetes**
- kubectl + kubectx/kubens

### ☁️ **Cloud**
- AWS CLI v2

### 🔐 **Segurança**
- 1Password CLI + SSH Agent

### 🎨 **Fontes**
- Nerd Fonts (FiraCode, JetBrains Mono, etc.)

### 🔧 **Git**
- Configuração global
- Hosts SSH customizados
- Múltiplas identidades por projeto
- Integração com 1Password SSH Agent

## 🚀 Instalação Rápida

### Método 1: One-liner (Recomendado)

```bash
# Instalar ferramentas
curl -fsSL https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/install.sh | bash

# Configurar Git (após instalação)
curl -fsSL https://raw.githubusercontent.com/lgobatto/dev-environment-setup/main/git-setup.sh | bash
```

### Método 2: Clone + Execute

```bash
# Clonar repositório
git clone https://github.com/lgobatto/dev-environment-setup.git
cd dev-environment-setup

# Executar scripts
./install.sh
./git-setup.sh
```

## 📚 Uso Detalhado

### 1. Instalador Principal (`install.sh`)

O script principal detecta seu sistema e oferece instalação interativa de todas as ferramentas:

```bash
./install.sh
```

**Fluxo de instalação:**
1. 🔍 Detecção do sistema operacional
2. ⚙️ Instalação de dependências básicas
3. 🎯 Menu interativo para cada ferramenta
4. 📊 Relatório final com resumo

**Recursos avançados:**
- ✅ Pula ferramentas já instaladas
- ✅ Tratamento de erros com retry
- ✅ Logs detalhados em `/tmp/dev-installer-*.log`
- ✅ Compatibilidade com WSL (pula apps gráficos)

### 2. Configurador Git (`git-setup.sh`)

Configura Git com suporte a múltiplas identidades e integração com 1Password:

```bash
./git-setup.sh
```

**Fluxo de configuração:**
1. 🔧 Configuração Git global (nome, email, etc.)
2. 🔐 Setup de hosts SSH customizados
3. 📁 Configuração condicional por diretório
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