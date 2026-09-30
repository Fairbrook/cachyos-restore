#!/usr/bin/env bash
# Re-snapshot this machine into the repo (run before committing).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
HW=$(cat packages/hardware.txt)
pacman -Qqen | sort | grep -vxF "$HW" > packages/core.txt
pacman -Qqem | sort > packages/aur.txt
am -f 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '/◆/ && $2!="am"{print $2}' > packages/am-apps.txt
for d in hypr waybar rofi ghostty kitty btop lazygit tmux-sessionizer nwg-look nwg-displays easyeffects flameshot wallpaper; do
  rsync -a --delete --exclude='.secrets' ~/.config/$d home/.config/
done
cp ~/.zshrc ~/.p10k.zsh ~/.tmux.conf ~/.gitconfig home/
cp ~/.config/mimeapps.list ~/.config/user-dirs.dirs home/.config/
git status --short
