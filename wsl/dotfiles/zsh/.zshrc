
#ls color theme
vivid_theme="catppuccin-mocha"

#Set ANTIDOTE
if [[ $EUID -eq 0 ]]; then
  export ANTIDOTE_DIR="${ZDOTDIR:-$HOME}/.antidote"
  export ANTIDOTE_CACHE="${XDG_CACHE_HOME:-/root/.cache}/antidote"
else
  export ANTIDOTE_DIR="${ZDOTDIR:-$HOME}/.antidote"
  export ANTIDOTE_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/antidote"
fi

# clone antidote if it doesn't exist
if [ ! -d "$ANTIDOTE_DIR" ]; then
  echo "Cloning antidote..."
  git clone --depth=1 https://github.com/mattmc3/antidote.git "$ANTIDOTE_DIR"
fi

# Lazy-load antidote and generate the static load file only when needed
zsh_plugins=${ZDOTDIR:-$HOME}/.zsh_plugins
if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  source "${ZDOTDIR:-$HOME}/.antidote/antidote.zsh"
  antidote bundle <${zsh_plugins}.txt >${zsh_plugins}.zsh
fi
source ${zsh_plugins}.zsh
# Lazy-load antidote from its functions directory.
fpath=(${ZDOTDIR:-$HOME}/.antidote/functions $fpath)
autoload -Uz antidote

export VISUAL="nvim"
export EDITOR="nvim"
export TERM=xterm-256color

#history
HISTFILE="${ZDOTDIR}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
HISTDUP=erase

# General Aliases
alias grep="grep --color=auto"
alias diff="diff --color=auto"
alias rm="rm -ri"
alias mv="mv -i"
alias cp="cp -i"
alias mkdir="mkdir -p"
alias cat="bat --style header --style snip --style changes --style header"
alias vim="nvim"
alias	ls="eza -a --icons=always --color=always --group-directories-first"
alias ll="eza -al --icons=always --color=always --group-directories-first"
alias df='df -h'
alias free='free -m'
alias h='history'
alias up="sudo pacman -Syu"

# Cleanup orphaned packages
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'


#keybindings
bindkey -e
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down


# Completion.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'       # Case insensitive tab completion
zstyle ':completion:*' rehash true                              # automatically find new executables in path
# Colorize completions using default `ls` colors.
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS:-}"
zstyle ':completion:*' completer _expand _complete _ignored _approximate
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''

# Speed up completions
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':plugin:ez-compinit' 'compstyle' 'ohmy'
zstyle ':plugin:ez-compinit' 'use-cache' 'yes'
zstyle :plugin:fast-syntax-highlighting theme "catppuccin-mocha"
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompcache"


#load optionrc if it exists
if [ -f "${ZDOTDIR}/optionrc" ]; then
  source "${ZDOTDIR}/optionrc"
fi


if command -v fzf &>/dev/null; then
 eval "$(fzf --zsh)"
export FZF_DEFAULT_OPTS=" \
--height 40%  --layout reverse --border rounded --info right \
--preview 'bat --style=numbers --color=always {} || highlight --syntax=sh {} || cat {}' \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--color=border:#313244,label:#cdd6f4"


fi

if command -v oh-my-posh &>/dev/null; then
  eval "$(oh-my-posh init zsh --config "${ZDOTDIR}/ohmyposh/ohmyposh.toml")"
fi

if command -v zoxide &>/dev/null; then
  eval "$(zoxide init --cmd cd zsh)"
fi
