# =============================================================================
#  aegis.plugin.zsh — Aegis OS terminal integration for the AI coding agents.
#  Part of the custom oh-my-zsh setup (ZSH_CUSTOM=/usr/share/oh-my-zsh-custom).
# =============================================================================
#  The agents themselves are launched through aegis-ai, which offers to
#  install a missing agent and then execs it — so typing `claude` with no
#  Claude Code installed offers the install instead of "command not found",
#  and with it installed behaves exactly like the bare binary.
# =============================================================================

# --- agents: bare names route through the aegis launcher ---------------------
claude()   { aegis-ai claude "$@"; }
opencode() { aegis-ai opencode "$@"; }
aider()    { aegis-ai aider "$@"; }
codex()    { aegis-ai codex "$@"; }

# --- status & helpers ---------------------------------------------------------
alias agents='aegis-ai list'          # install/auth status at a glance
alias aegis='aegis-tools'             # the security tool manager
alias ainstall='aegis-ai-install'     # install agent(s) directly

# --- agent mode marker for spawned shells -------------------------------------
# Claude Code sets CLAUDECODE=1 in the shells it spawns (its internal bash
# tools); export AEGIS_AGENT to mark any other nested-agent environment. The
# aegis.zsh-theme prompt shows a violet [AGENT] tag when either is set.
