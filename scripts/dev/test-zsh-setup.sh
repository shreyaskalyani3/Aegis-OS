#!/usr/bin/env bash
# =============================================================================
#  test-zsh-setup.sh — end-to-end test of the Aegis OS zsh/oh-my-zsh setup.
#
#  Vendors oh-my-zsh into a disposable WSL/archlinux test distro, wires the
#  custom aegis theme + plugin from the repo, and boots real interactive zsh
#  shells against the shipped /etc/skel/.zshrc — both the oh-my-zsh path and
#  the plain fallback. Run inside WSL as root.
# =============================================================================
set -e

OMZ=/usr/share/oh-my-zsh
CUSTOM_SRC=/mnt/f/AegisOS/profile/airootfs/usr/share/oh-my-zsh-custom
ZSHRC_SRC=/mnt/f/AegisOS/profile/airootfs/etc/skel/.zshrc

command -v zsh >/dev/null 2>&1 || pacman -S --needed --noconfirm zsh >/dev/null
[[ -d /mnt/f/AegisOS ]] || { echo "SKIP: repo not mounted"; exit 0; }

# vendored framework (clone if absent) + custom theme/plugin, perms normalized
if [[ ! -d "${OMZ}" ]]; then
    git clone --depth=1 -q https://github.com/ohmyzsh/ohmyzsh.git "${OMZ}"
fi
rm -rf /usr/share/oh-my-zsh-custom
cp -a "${CUSTOM_SRC}" /usr/share/oh-my-zsh-custom
chmod -R go-w /usr/share/oh-my-zsh-custom

rm -rf /tmp/zhome && mkdir -p /tmp/zhome && cp "${ZSHRC_SRC}" /tmp/zhome/.zshrc

echo "=== oh-my-zsh path ==="
OUT=$(env HOME=/tmp/zhome zsh -i -c 'echo "ZSH_THEME=$ZSH_THEME"; alias gco >/dev/null 2>&1 && echo git-plugin-OK; functions claude >/dev/null 2>&1 && echo aegis-plugin-OK; alias tools >/dev/null 2>&1 && echo aegis-aliases-OK; alias agents >/dev/null 2>&1 && echo agents-alias-OK; [[ -n "$ZSH_THEME_GIT_PROMPT_PREFIX" ]] && echo prompt-git-OK; zstyle -L ":omz:update" mode 2>/dev/null | grep -q disabled && echo update-disabled-OK; print -rn -- "$PROMPT"' 2>&1) \
    || { echo "FAIL: interactive zsh errored"; echo "$OUT"; exit 1; }
echo "$OUT"
grep -q 'ZSH_THEME=aegis'      <<<"$OUT" || { echo "FAIL: theme not set"; exit 1; }
grep -q 'git-plugin-OK'        <<<"$OUT" || { echo "FAIL: git plugin missing"; exit 1; }
grep -q 'aegis-plugin-OK'      <<<"$OUT" || { echo "FAIL: aegis plugin missing"; exit 1; }
grep -q 'aegis-aliases-OK'     <<<"$OUT" || { echo "FAIL: aegis aliases missing"; exit 1; }
grep -q 'agents-alias-OK'      <<<"$OUT" || { echo "FAIL: agents alias missing"; exit 1; }
grep -q 'prompt-git-OK'        <<<"$OUT" || { echo "FAIL: prompt not git-aware"; exit 1; }
grep -q 'update-disabled-OK'   <<<"$OUT" || { echo "FAIL: omz update prompts not disabled"; exit 1; }
grep -q '╭─'                   <<<"$OUT" || { echo "FAIL: aegis prompt template missing"; exit 1; }
if grep -q 'Insecure completion' <<<"$OUT"; then
    echo "FAIL: insecure-completion warning — perms not normalized"; exit 1
fi

echo "=== fallback path (oh-my-zsh removed) ==="
mv "${OMZ}" "${OMZ}.hidden"
OUT2=$(env HOME=/tmp/zhome zsh -i -c 'alias tools >/dev/null 2>&1 && echo aegis-aliases-OK; print -rn -- "$PROMPT"' 2>&1) \
    || { echo "FAIL: fallback zsh errored"; echo "$OUT2"; exit 1; }
echo "$OUT2"
grep -q 'aegis-aliases-OK'     <<<"$OUT2" || { echo "FAIL: fallback aliases missing"; exit 1; }
grep -q '🛡'                    <<<"$OUT2" || { echo "FAIL: fallback prompt template missing"; exit 1; }
mv "${OMZ}.hidden" "${OMZ}"

echo "ZSH-SETUP-TEST-PASS"
