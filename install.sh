#!/usr/bin/env bash
# Restore a fresh CachyOS + Hyprland install to match this machine.
# Usage: ./install.sh [--hardware] [--skip-packages] [--skip-am] [--skip-dotfiles] [--skip-system]
#   --hardware  also install kernels, nvidia drivers, bootloader/snapper (machine-specific!)
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
REPO=$PWD
HARDWARE=0 PKGS=1 AM=1 DOTS=1 SYS=1
for a in "$@"; do case $a in
  --hardware) HARDWARE=1;; --skip-packages) PKGS=0;; --skip-am) AM=0;;
  --skip-dotfiles) DOTS=0;; --skip-system) SYS=0;;
  *) echo "unknown flag $a"; exit 1;; esac; done
log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
list() { grep -vE '^\s*(#|$)' "$1"; }

[[ $EUID -eq 0 ]] && { echo "Run as your normal user (sudo is used where needed)."; exit 1; }

if ((PKGS)); then
  log "Enabling lizardbyte repo (sunshine) if missing"
  if ! grep -q '^\[lizardbyte\]' /etc/pacman.conf; then
    printf '\n[lizardbyte]\nSigLevel = Optional\nServer = https://github.com/LizardByte/pacman-repo/releases/latest/download\n' | sudo tee -a /etc/pacman.conf >/dev/null
  fi
  log "Installing pacman packages"
  sudo pacman -Syu --needed --noconfirm base-devel git
  mapfile -t P < <(list packages/core.txt)
  ((HARDWARE)) && mapfile -t -O "${#P[@]}" P < <(list packages/hardware.txt)
  # install one by one fallback so a single missing package doesn't abort everything
  sudo pacman -S --needed --noconfirm "${P[@]}" || {
    echo "Bulk install failed; retrying per package"
    for p in "${P[@]}"; do sudo pacman -S --needed --noconfirm "$p" || echo "FAILED: $p" | tee -a "$REPO/failed-packages.log"; done; }
  log "Installing AUR packages"
  mapfile -t A < <(list packages/aur.txt)
  ((${#A[@]})) && yay -S --needed --noconfirm "${A[@]}"
fi

if ((SYS)); then
  log "Enabling services / groups"
  for s in NetworkManager bluetooth sddm docker cups avahi-daemon sshd ufw cloudflared warp-svc zerotier-one rustdesk power-profiles-daemon; do
    systemctl list-unit-files "$s.service" &>/dev/null && sudo systemctl enable "$s.service" || echo "skip $s"
  done
  ((HARDWARE)) && for s in ananicy-cpp limine-snapper-sync nvidia-hibernate nvidia-resume nvidia-suspend; do sudo systemctl enable "$s.service" || true; done
  sudo systemctl enable fstrim.timer snapper-cleanup.timer 2>/dev/null || true
  sudo usermod -aG docker,wheel,video,input,audio,lp,storage,rfkill "$USER"
fi

if ((DOTS)); then
  log "Deploying dotfiles (existing files are backed up to ~/.dotfiles-backup/<timestamp>)"
  B=$HOME/.dotfiles-backup/$(date +%s); mkdir -p "$B"
  rsync -a --backup --backup-dir="$B" home/ "$HOME/"
  chmod +x ~/.local/bin/{tmux-sessionizer,gah}
  mkdir -p ~/.config/.secrets
  for f in secrets.example/*; do [[ $f == */README ]] && continue
    [[ -e ~/.config/.secrets/$(basename "$f") ]] || cp "$f" ~/.config/.secrets/; done
  chmod 700 ~/.config/.secrets

  log "Neovim config (Fairbrook/lazyvim)"
  if [[ -d ~/.config/nvim/.git ]]; then git -C ~/.config/nvim pull --ff-only || true
  else [[ -e ~/.config/nvim ]] && mv ~/.config/nvim "$B/nvim"; git clone https://github.com/Fairbrook/lazyvim ~/.config/nvim; fi

  log "Shell: oh-my-zsh, powerlevel10k, plugins"
  [[ -d ~/.oh-my-zsh ]] || RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  C=~/.oh-my-zsh/custom
  clone() { [[ -d $2 ]] || git clone --depth=1 "$1" "$2"; }
  clone https://github.com/romkatv/powerlevel10k.git            $C/themes/powerlevel10k
  clone https://github.com/zsh-users/zsh-autosuggestions        $C/plugins/zsh-autosuggestions
  clone https://github.com/zsh-users/zsh-syntax-highlighting    $C/plugins/zsh-syntax-highlighting
  clone https://github.com/zdharma-continuum/fast-syntax-highlighting $C/plugins/fast-syntax-highlighting
  [[ $SHELL == */zsh ]] || chsh -s "$(command -v zsh)"

  log "tmux plugin manager"
  clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  ~/.tmux/plugins/tpm/bin/install_plugins || true
fi

if ((AM)); then
  log "AM (app manager for AppImages)"
  if ! command -v am &>/dev/null; then
    T=$(mktemp -d); curl -fsSL https://raw.githubusercontent.com/ivan-hc/AM/main/AM-INSTALLER -o "$T/AM-INSTALLER"
    chmod +x "$T/AM-INSTALLER"
    # Installer is interactive: option 1 = "AM" (system-wide, /opt/am). Adjust if the menu changes.
    (cd "$T" && printf '1\n' | ./AM-INSTALLER)
  fi
  while read -r app; do
    [[ -z $app || $app == \#* ]] && continue
    am -i "$app" </dev/null || echo "FAILED am: $app" | tee -a "$REPO/failed-packages.log"
  done < packages/am-apps.txt
fi

log "Done. Log out/in (or reboot) for group + shell changes. Fill in ~/.config/.secrets/*."
[[ -f failed-packages.log ]] && { echo "Some installs failed:"; cat failed-packages.log; }
