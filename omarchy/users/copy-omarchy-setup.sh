#!/bin/bash
# Give another local user the same Omarchy desktop as you: the Omarchy install
# (~/.local/share/omarchy), its state, fonts, app launchers, and your desktop
# configs (Hyprland keybindings, waybar, walker, terminals, theme...).
# Personal-data configs (git identity, browser profile, notes apps, your systemd
# user services, autostart) are NOT copied; the target gets Omarchy's defaults
# for those, and only when it has none of its own.
#
# Usage: sudo ./copy-omarchy-setup.sh USER
# Re-run after changing your desktop to push the changes again (overwrites the
# target's copies of the desktop configs). The target must log out and in.
set -euo pipefail

user=${1:?usage: sudo $0 USER}
src=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
dst=${DEST_HOME:-$(getent passwd "$user" | cut -d: -f6)} # DEST_HOME: testing only
[[ -n $dst && -d $dst ]] || { echo "no home folder for $user" >&2; exit 1; }
[[ $src != "$dst" ]] || { echo "source and target are the same user" >&2; exit 1; }
if [[ $EUID -eq 0 ]]; then own=(--chown="$user:$user"); else
  [[ -n ${DEST_HOME:-} ]] || { echo "run with sudo: sudo $0 $user" >&2; exit 1; }
  own=()
fi
sync() { mkdir -p "$(dirname "$2")"; rsync -a --delete --exclude='*.bak*' "${own[@]}" "$1" "$2"; }

# Desktop behaviour: copied from you so it matches.
desktop=(hypr waybar walker elephant mako swayosd uwsm fontconfig fcitx5
  alacritty ghostty kitty foot tmux btop fastfetch imv lazygit wiremix xournalpp
  hyprland-preview-share-picker omarchy starship.toml xdg-terminals.list
  chromium-flags.conf omarchy.ttf)
# Personal data: Omarchy's defaults, only when the target has none.
defaults=(git chromium obsidian Typora opencode systemd autostart environment.d)

sync "$src/.local/share/omarchy/" "$dst/.local/share/omarchy/"
sync "$src/.local/state/omarchy/" "$dst/.local/state/omarchy/" # migrations already applied, toggles
[[ -d $src/.local/share/fonts ]] && sync "$src/.local/share/fonts/" "$dst/.local/share/fonts/"
[[ -d $src/.local/share/applications ]] && sync "$src/.local/share/applications/" "$dst/.local/share/applications/"

for d in "${desktop[@]}"; do
  [[ -e $src/.config/$d ]] || continue
  if [[ -d $src/.config/$d ]]; then sync "$src/.config/$d/" "$dst/.config/$d/"; else sync "$src/.config/$d" "$dst/.config/$d"; fi
done
for d in "${defaults[@]}"; do
  [[ -e $dst/.config/$d || ! -e $src/.local/share/omarchy/config/$d ]] && continue
  sync "$src/.local/share/omarchy/config/$d/" "$dst/.config/$d/"
done

# Links and launchers that point into your home folder must point into theirs.
find "$dst/.config/omarchy" "$dst/.local/share/applications" -type l 2>/dev/null | while read -r l; do
  t=$(readlink "$l"); [[ $t == "$src"/* ]] && ln -sfn "$dst${t#"$src"}" "$l" && { [[ $EUID -ne 0 ]] || chown -h "$user:$user" "$l"; }
done
grep -rlZF "$src/" "$dst/.local/share/applications" 2>/dev/null | xargs -0r sed -i "s#$src/#$dst/#g"

# Omarchy's bash setup (the target's login shell must be bash for this to apply).
if ! grep -q 'omarchy/default/bash' "$dst/.bashrc" 2>/dev/null; then
  [[ -f $dst/.bashrc ]] && cp -p "$dst/.bashrc" "$dst/.bashrc.pre-omarchy"
  cp "$src/.local/share/omarchy/default/bashrc" "$dst/.bashrc"
  [[ $EUID -ne 0 ]] || chown "$user:$user" "$dst/.bashrc"
fi

echo "Copied your Omarchy desktop to $user ($dst). They need to log out and back in."
