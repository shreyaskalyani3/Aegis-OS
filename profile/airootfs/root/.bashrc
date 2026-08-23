# /root/.bashrc — Aegis OS root shell (bash; the aegis user defaults to zsh)
[[ $- != *i* ]] && return

export EDITOR=nvim VISUAL=nvim PAGER=less
export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/local/sbin:$PATH"

HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize

alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias ip='ip --color=auto'
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'

# Root prompt: a hard red hash so you never forget you are root.
PS1='\[\e[1;31m\][\[\e[0m\]\[\e[38;5;231m\]root\[\e[38;5;240m\]@\[\e[38;5;31m\]\h\[\e[1;31m\]]\[\e[0m\] \[\e[38;5;247m\]\w\[\e[0m\]\n\[\e[1;31m\]#\[\e[0m\] '

if [[ -z "$AEGIS_MOTD_SHOWN" ]]; then
    export AEGIS_MOTD_SHOWN=1
    command -v aegis-motd >/dev/null && aegis-motd
fi
