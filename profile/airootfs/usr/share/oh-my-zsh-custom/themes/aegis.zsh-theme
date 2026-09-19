# =============================================================================
#  aegis.zsh-theme — the Aegis OS oh-my-zsh prompt.
# =============================================================================
#  Two lines, Aegis red on dark:
#    ╭─ 🛡 user@host  ~/path  git:(main)
#    ╰─➜
#  A violet [AGENT] tag marks shells spawned inside an AI coding agent
#  (Claude Code sets CLAUDECODE=1 for the shells it spawns; export
#  AEGIS_AGENT=<name> to mark any other nested-agent environment), and a red
#  ✘ marker reports a failed last command. Truecolor hex — xfce4-terminal
#  supports it. No text plugin needed: the wordmark lives in the theme itself.
# =============================================================================

AEGIS_RED='%F{#ff3355}'
AEGIS_RIM='%F{#ff5c78}'
AEGIS_DIM='%F{#8b949e}'
AEGIS_BLUE='%F{#58a6ff}'
AEGIS_VIOLET='%F{#bc8cff}'

# git segment colours (the oh-my-zsh git_prompt_info theme hooks)
ZSH_THEME_GIT_PROMPT_PREFIX=" ${AEGIS_DIM}git:(%f${AEGIS_RED}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f${AEGIS_DIM})"
ZSH_THEME_GIT_PROMPT_DIRTY=" %F{red}✘%f"
ZSH_THEME_GIT_PROMPT_CLEAN="%f"

# [AGENT] while inside an AI agent shell
prompt_aegis_agent() {
  if [[ -n "${CLAUDECODE:-}${AEGIS_AGENT:-}" ]]; then
    printf '%s' "${AEGIS_VIOLET}[AGENT]%f "
  fi
}

PROMPT='╭─${AEGIS_RED}%B🛡%b%f $(prompt_aegis_agent)${AEGIS_RED}%n%f${AEGIS_DIM}@%f${AEGIS_BLUE}%m%f ${AEGIS_DIM}%~%f$(git_prompt_info)
╰─${AEGIS_RIM}➜%f '

RPROMPT='%(?..%F{red}✘ %?%f)'

setopt PROMPT_SUBST
