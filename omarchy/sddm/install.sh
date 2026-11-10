#!/bin/bash
# Install/refresh the omarchy-users SDDM theme with the current Omarchy colours,
# make it the active theme, and turn autologin off. Safe to re-run; re-run after
# changing the Omarchy theme to resync colours. Does not restart SDDM or log anyone out.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run with sudo: sudo $0" >&2; exit 1; }

src="$(cd "$(dirname "$0")" && pwd)/omarchy-users"
stock=/usr/share/sddm/themes/omarchy
dest=/usr/share/sddm/themes/omarchy-users
conf=/etc/sddm.conf.d/autologin.conf
bak=/etc/sddm-autologin.conf.bak # outside sddm.conf.d: SDDM reads every file there, .bak included

# Omarchy bakes its background into Main.qml and its text colour into the images.
bg=$(grep -m1 -oP '^  color: "#\K[0-9a-fA-F]{6}' "$stock/Main.qml")
text=$(magick "$stock/bullet.png" -format '%[hex:p{7,7}]' info: | cut -c1-6)
[[ $bg =~ ^[0-9a-fA-F]{6}$ && $text =~ ^[0-9a-fA-F]{6}$ ]] || { echo "could not read Omarchy colours (bg='$bg' text='$text')" >&2; exit 1; }

mkdir -p "$dest"
cp "$src/metadata.desktop" "$src/theme.conf" "$dest/"
sed -e "s/#1a1b26/#$bg/g" -e "s/#ffffff/#$text/g" "$src/Main.qml" > "$dest/Main.qml"

# An older run left the original inside sddm.conf.d, where it re-enabled autologin.
[[ -f $conf.bak && ! -f $bak ]] && mv "$conf.bak" "$bak"
rm -f "$conf.bak"
[[ -f $bak ]] || cp "$conf" "$bak"
# Drop the [Autologin] section; point [Theme] at our theme.
awk '/^\[/{skip=($0=="[Autologin]")} !skip' "$conf" | sed 's/^Current=.*/Current=omarchy-users/' > "$conf.new"
grep -q '^Current=omarchy-users' "$conf.new" || printf '\n[Theme]\nCurrent=omarchy-users\n' >> "$conf.new"
mv "$conf.new" "$conf"

echo "Installed $dest (bg #$bg, text #$text). Autologin off. Takes effect at next logout/boot."
echo "Undo: sudo cp $bak $conf"
