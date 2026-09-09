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

if command -v eza >/dev/null; then
    alias ls='eza --group-directories-first --icons=auto'
    alias ll='eza -lah --group-directories-first --git --icons=auto'
    alias la='eza -a --icons=auto'
    alias lt='eza --tree --level=2 --icons=auto'
else
    alias ls='ls --color=auto'
    alias ll='ls -lah --color=auto'
fi
alias grep='grep --color=auto'
alias update='sudo pacman -Syu'
alias ai='aegis-ai'
alias tools='aegis-tools'
alias run='aegis-run'
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'

# --- Framed prompt (mirrors .zshrc): green arrow on success, red ✘ on failure
_aegis_arrow() {
    local _rc=$?
    if [[ $_rc -eq 0 ]]; then
        AEGIS_ARROW='\[\e[38;5;40m\]➜\[\e[0m\]'
    else
        AEGIS_ARROW='\[\e[1;31m\]✘\[\e[0m\]'
    fi
    return $_rc
}
PROMPT_COMMAND='_aegis_arrow'
PS1='\[\e[1;31m\]╭─\[\e[0m\] \[\e[38;5;197m\]\u\[\e[38;5;240m\]@\[\e[38;5;39m\]\h\[\e[0m\] \[\e[38;5;250m\]\w\[\e[0m\]\n\[\e[1;31m\]╰─\[\e[0m\]${AEGIS_ARROW} '

if [[ -z "$AEGIS_MOTD_SHOWN" ]]; then
    export AEGIS_MOTD_SHOWN=1
    command -v aegis-motd >/dev/null && aegis-motd
fi
