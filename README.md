# cachyos-restore

Turns a fresh **CachyOS (Hyprland)** install into a copy of my main machine.

## Use
```bash
sudo pacman -S --needed git
git clone https://github.com/<you>/cachyos-restore && cd cachyos-restore
./install.sh                # packages, services, dotfiles, nvim, zsh, AM apps
./install.sh --hardware     # additionally kernels / nvidia 580xx / limine / snapper
```
Flags: `--skip-packages --skip-am --skip-dotfiles --skip-system`. Failures are logged to `failed-packages.log`.

## Layout
| Path | What |
|---|---|
| `packages/core.txt` | explicit pacman packages (`pacman -Qqen`) minus hardware ones |
| `packages/hardware.txt` | kernels, nvidia, firmware, bootloader, snapper — opt-in via `--hardware` |
| `packages/aur.txt` | foreign/AUR packages (`pacman -Qqem`), installed with `yay` |
| `packages/am-apps.txt` | AppImages installed via [AM](https://github.com/ivan-hc/AM) |
| `home/` | mirror of `$HOME`; rsynced over it (old files backed up to `~/.dotfiles-backup/`) |
| `secrets.example/` | placeholders for `~/.config/.secrets` used by waybar scripts |
| `refresh.sh` | re-snapshot this machine into the repo, then commit |

Neovim config is cloned from https://github.com/Fairbrook/lazyvim into `~/.config/nvim` (not vendored).
oh-my-zsh, powerlevel10k, zsh plugins and tpm are cloned by the installer.

## Not included (do by hand)
- Secrets: `~/.config/.secrets/*`, `gh auth login`, Bitwarden / SSH agent, `~/.ssh`, WARP/zerotier/rustdesk logins.
- App data: browser profiles, Claude, Obsidian, etc. (`~/.config/{zen,Claude,...}` is GBs).
- `MATLAB`, Go in `/usr/local/go`, pnpm/node toolchains — `~/.zshrc` PATH entries point at them.
- `~/.config/rofi.kevinm` (duplicate of rofi), lan-mouse/deskflow/sunshine configs (contain keys/credentials).
- `system/pacman.conf.reference` is for reference only; the installer just adds the `[lizardbyte]` repo (sunshine).

## Caveats
- `hyprland.conf` autostarts bitwarden, claude-desktop, superproductivity — install them first or remove the lines.
- `monitors.conf` is empty here; run `nwg-displays` on the new machine.
- The AM bootstrap pipes `1` into its interactive installer — untested; verify on first run.
- Script is untested on a clean install (only syntax-checked).
