# AI Agents in Aegis OS

Aegis treats AI coding agents as first-class tools. Four are supported out of
the box:

| Agent | Vendor | Command | Install method on Aegis |
|---|---|---|---|
| **Claude Code** | Anthropic | `claude` | native installer → npm fallback |
| **OpenCode** | opencode.ai | `opencode` | **baked into the ISO** (official Arch `opencode` package) |
| **Aider** | aider.chat | `aider` | official installer → `uv`/`pipx` fallback |
| **Codex CLI** | OpenAI | `codex` | `npm i -g @openai/codex` → installer fallback |

OpenCode ships in the image. The other three install **per-user, on demand**
into `~/.local` (no root, no silent first-boot downloads) — so credentials and
binaries live in your home directory and update cleanly.

---

## Quick start

```bash
setup        # guided first-run wizard: agreement, install agents, store API keys, log in
ai           # unified launcher: pick / run an agent (offers to install if missing)
```

Or drive it directly:

```bash
ai list                 # show agents and install status
ai install all          # install every supported agent
ai install claude       # install just one
ai claude               # run Claude Code (installs first if needed)
ai opencode             # run OpenCode
```

`ai` is a shortcut for `aegis-ai`; installation is handled by `aegis-ai-install`.

---

## Authentication

Most agents accept either an interactive login or an API key from the
environment. Aegis keeps keys in `~/.config/aegis/env` (mode `600`), which the
shell sources automatically. `env_keep` in `/etc/sudoers.d/10-aegis` preserves
the common keys across `sudo`.

Recognized environment variables:

- `ANTHROPIC_API_KEY` — Claude Code
- `OPENAI_API_KEY` — Codex, Aider (OpenAI models), OpenCode (OpenAI models)
- Aider and OpenCode also read provider-specific keys (e.g. `OPENROUTER_API_KEY`,
  `GEMINI_API_KEY`) — see their docs.

Set them the easy way:

```bash
setup        # choose "store API keys" — writes ~/.config/aegis/env
```

Or by hand:

```bash
mkdir -p ~/.config/aegis
cat >> ~/.config/aegis/env <<'EOF'
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
EOF
chmod 600 ~/.config/aegis/env
```

Claude Code can also be logged in interactively (Pro/Max or Console account):

```bash
claude          # follow the browser/device login prompt
```

---

## Where things install

- Binaries: `~/.local/bin` (already on `PATH` via the Aegis zsh/bash config)
- npm global prefix is pinned to `~/.local` (`NPM_CONFIG_PREFIX`)
- Aider (uv/pipx) lands in `~/.local` as well

Because everything is under `$HOME`, an agent set up in the **live** session
persists only for that session; on an **installed** system it persists normally.

---

## Using agents for security work

The agents are ordinary CLI coding assistants — useful for writing exploit PoCs,
parsing scan output, scripting `nmap`/`ffuf` runs, reversing with `radare2`,
explaining code, and automating reporting. They operate on the files and
commands you give them.

> Keep engagement data in scope. Don't paste client secrets or out-of-scope
> target data into a hosted model without authorization. See [ETHICS.md](ETHICS.md).
