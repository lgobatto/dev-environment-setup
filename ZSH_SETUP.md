# 🐚 Configuração do Zsh + Oh My Zsh + Powerlevel10k

## Status da Instalação

✅ **Zsh** - Instalado e pronto  
✅ **Oh My Zsh** - Instalado em `~/.oh-my-zsh`  
✅ **Powerlevel10k** - Instalado em `~/.oh-my-zsh/custom/themes/powerlevel10k`  
✅ **Plugins** - zsh-autosuggestions, zsh-syntax-highlighting  

## Como Ativar o Zsh

### 1. Tornar Zsh o shell padrão

```bash
chsh -s /usr/bin/zsh
```

Depois faça **logout e login** novamente.

### 2. Testar sem mudar o shell padrão

```bash
zsh
```

## Configuração do Powerlevel10k

Na primeira vez que você abrir o Zsh, o **Powerlevel10k Configuration Wizard** será iniciado automaticamente.

### O Wizard vai perguntar:

1. **Diamond icons** - Você consegue ver os ícones corretamente?
2. **Lock icon** - O cadeado aparece corretamente?
3. **Debian logo** - O logo aparece corretamente?
4. **Style** - Escolha o estilo visual (Rainbow, Pure, etc)
5. **Character set** - Unicode ou ASCII
6. **Show current time** - Mostrar hora no prompt
7. **Prompt separators** - Estilo dos separadores
8. **Prompt heads** - Estilo das pontas
9. **Prompt tails** - Estilo das caudas
10. **Prompt height** - Uma ou duas linhas
11. **Prompt spacing** - Espaçamento compacto ou solto
12. **Icons** - Muitos ou poucos ícones
13. **Prompt flow** - Conciso ou fluente
14. **Transient prompt** - Prompt transiente (recomendado)

### Reconfigurar o Powerlevel10k

Se quiser mudar as configurações depois:

```bash
p10k configure
```

## Verificação

Para verificar se tudo está funcionando:

```bash
# Ver tema atual
echo $ZSH_THEME

# Ver plugins ativos
echo $plugins

# Ver versão do Zsh
zsh --version
```

## Fontes (Importante!)

O Powerlevel10k funciona melhor com **Nerd Fonts**. As fontes já foram instaladas em:
- `~/.local/share/fonts/NerdFonts/`

### Fontes disponíveis:
- FiraCode Nerd Font
- JetBrainsMono Nerd Font
- CascadiaCode Nerd Font
- Hack Nerd Font
- SourceCodePro Nerd Font
- UbuntuMono Nerd Font

**Configure seu terminal para usar uma dessas fontes!**

## Troubleshooting

### Problema: Caracteres estranhos no prompt
**Solução**: Configure uma Nerd Font no seu terminal

### Problema: Zsh não inicia automaticamente
**Solução**: Execute `chsh -s /usr/bin/zsh` e faça logout/login

### Problema: Plugins não funcionam
**Solução**: Verifique se os plugins estão em `~/.oh-my-zsh/custom/plugins/`

### Problema: Quer usar o bash novamente
**Solução**: `chsh -s /bin/bash` e faça logout/login

## Arquivos de Configuração

- `~/.zshrc` - Configuração principal do Zsh
- `~/.p10k.zsh` - Configuração do Powerlevel10k (criado após wizard)
- `~/.oh-my-zsh/` - Diretório do Oh My Zsh

## Plugins Instalados

### git
Plugin oficial do Oh My Zsh com aliases úteis para Git

### zsh-autosuggestions
Sugere comandos baseado no histórico (seta → para aceitar)

### zsh-syntax-highlighting
Destaca comandos válidos em verde e inválidos em vermelho

## Próximos Passos

1. Execute `zsh` para iniciar
2. Complete o wizard do Powerlevel10k
3. Configure uma Nerd Font no seu terminal
4. Aproveite seu novo terminal! 🚀

## Mais Plugins (Opcional)

Para adicionar mais plugins, edite `~/.zshrc`:

```bash
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    docker              # adicione este
    kubectl             # ou este
    terraform           # ou este
)
```

Depois execute: `source ~/.zshrc`
