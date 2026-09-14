# /etc/skel/.bashrc — fallback for bash logins (Aegis default shell is zsh)
[[ $- != *i* ]] && return

export EDITOR=nvim VISUAL=nvim PAGER=less
export PATH="$HOME/.local/bin:$HOME/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"
export NPM_CONFIG_PREFIX="$HOME/.local"
[[ -f "$HOME/.config/aegis/env" ]] && source "$HOME/.config/aegis/env"

HISTCONTROL=ignoreboth
HISTSIZE=50000
HISTFILESIZE=50000
shopt -s histappend checkwinsize

alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias update='sudo pacman -Syu'
alias ai='aegis-ai'
alias tools='aegis-tools'
alias run='aegis-run'
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'

# 🛡 red-accent prompt
PS1='\[\e[1;31m\]🛡\[\e[0m\] \[\e[38;5;197m\]\u\[\e[38;5;240m\]@\[\e[38;5;31m\]\h\[\e[0m\] \[\e[38;5;247m\]\w\[\e[0m\]\n\[\e[1;31m\]➜\[\e[0m\] '

if [[ -z "$AEGIS_MOTD_SHOWN" ]]; then
    export AEGIS_MOTD_SHOWN=1
    command -v aegis-motd >/dev/null && aegis-motd
fi
