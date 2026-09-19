# =============================================================================
#  Aegis OS — default zsh configuration (/etc/skel/.zshrc)
# =============================================================================
#  Oh My Zsh with the custom Aegis theme + plugin when present (vendored into
#  the image at /usr/share/oh-my-zsh by build-iso.sh), falling back to the
#  plain Aegis setup otherwise. Both paths share everything below the setup
#  block: history, completion, modern aliases, Aegis shortcuts, and the
#  AI-agent-native finishing touches.

# --- PATH: user-local bins, Go, Cargo, npm-user-global --------------------
typeset -U path
path=("$HOME/.local/bin" "$HOME/bin" "$HOME/go/bin" "$HOME/.cargo/bin" $path)
export PATH
export EDITOR=nvim VISUAL=nvim PAGER=less
export GOPATH="$HOME/go"
export NPM_CONFIG_PREFIX="$HOME/.local"

# --- AI agent credentials (written by aegis-setup, mode 600) ---------------
[[ -f "$HOME/.config/aegis/env" ]] && source "$HOME/.config/aegis/env"

# --- Oh My Zsh (custom Aegis theme + plugin) ---------------------------------
if [[ -d /usr/share/oh-my-zsh ]]; then
    export ZSH=/usr/share/oh-my-zsh
    export ZSH_CUSTOM=/usr/share/oh-my-zsh-custom
    ZSH_THEME="aegis"
    zstyle ':omz:update' mode disabled     # shipped immutable — no update prompts
    plugins=(git extract colored-man-pages aegis)
    source "$ZSH/oh-my-zsh.sh"
else
    # Fallback prompt (git-aware, security red) — used when the vendored
    # oh-my-zsh is absent (e.g. an offline rebuild that skipped the clone).
    autoload -Uz compinit && compinit -d "$HOME/.cache/zcompdump"
    zstyle ':completion:*' menu select
    zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
    autoload -Uz vcs_info
    zstyle ':vcs_info:git:*' formats ' %F{244}(%b)%f'
    precmd() { vcs_info; }
    setopt PROMPT_SUBST
    # 🛡 user@host  path (branch)  ➜
    PROMPT='%F{red}%B🛡%b%f %F{197}%n%f%F{240}@%f%F{31}%m%f %F{247}%~%f${vcs_info_msg_0_}
%F{red}➜%f '
    RPROMPT='%(?..%F{red}✘ %?%f)'
fi

# --- History ----------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt EXTENDED_GLOB INTERACTIVE_COMMENTS NO_BEEP

# --- Autosuggestions (before syntax highlighting) -----------------------------
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null

# --- Aliases: modern replacements when available ----------------------------
# --icons=auto: folder/file glyphs from the Nerd Font (JetBrainsMono Nerd is
# the terminal font), and only when stdout is a terminal — piped ls stays clean.
if command -v eza >/dev/null; then
    alias ls='eza --group-directories-first --icons=auto'
    alias ll='eza -lah --group-directories-first --git --icons=auto'
    alias la='eza -a --icons=auto'
    alias lt='eza --tree --level=2 --icons=auto'
else
    alias ll='ls -lah --color=auto'; alias la='ls -A'; alias ls='ls --color=auto'
fi
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'
command -v fd  >/dev/null && alias fd='fd --hidden'
alias grep='grep --color=auto'
alias ip='ip --color=auto'
alias ports='ss -tulpen'
alias myip='curl -fsS ifconfig.me; echo'
alias ..='cd ..'; alias ...='cd ../..'
alias update='sudo pacman -Syu'
alias please='sudo'

# --- Aegis shortcuts --------------------------------------------------------
alias ai='aegis-ai'
alias tools='aegis-tools'
alias setup='aegis-setup'
alias run='aegis-run'

# --- fzf & zoxide (if present) ----------------------------------------------
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
[[ -r /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -r /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh

# --- Greeting (interactive shells) -------------------------------------------
if [[ -o interactive && -z "$AEGIS_MOTD_SHOWN" ]]; then
    export AEGIS_MOTD_SHOWN=1
    command -v aegis-motd >/dev/null && aegis-motd
fi

# syntax highlighting last (if installed)
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
