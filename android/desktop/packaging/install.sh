#!/bin/sh
# Adds luksMusic to the application menu (KDE on the Steam Deck's desktop mode), pointing at this folder, wherever
# the archive was extracted. Run once: ./install.sh
set -e
here="$(cd "$(dirname "$0")" && pwd)"
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$apps"
sed -e "s|^Exec=.*|Exec=\"$here/bin/luksMusic\"|" -e "s|^Icon=.*|Icon=$here/luksMusic.png|" \
    "$here/luksMusic.desktop" > "$apps/luksMusic.desktop"
chmod +x "$here/bin/luksMusic" "$apps/luksMusic.desktop"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$apps" >/dev/null 2>&1 || true
echo "luksMusic added to the application menu ($apps/luksMusic.desktop)"
echo "Start it from the menu, or add it to Steam: Steam > Games > Add a Non-Steam Game > luksMusic"
