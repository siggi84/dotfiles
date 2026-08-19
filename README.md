# Neovim and tmux dotfiles

Personal Neovim and tmux configuration for quickly setting up a Linux machine.

## Requirements

- Git
- Neovim 0.12 or newer
- tmux
- A Nerd Font

The configuration also makes use of `fzf`, `ripgrep`, `lazygit`, and a system
clipboard provider such as `xclip`, `xsel`, or `wl-clipboard`.

## Install

Clone the repository and run the installer:

```sh
git clone <repository-url> "$HOME/dotfiles"
"$HOME/dotfiles/install.sh"
```

The installer creates these symlinks:

```text
~/.config/nvim -> ~/dotfiles/nvim
~/.config/tmux -> ~/dotfiles/tmux
```

It also installs TPM under `~/.tmux/plugins/tpm` and installs the tmux plugins
declared in `tmux/tmux.conf`.

The installer refuses to replace existing configuration. To move conflicts to
a timestamped directory under `~/.dotfiles-backups` before linking, run:

```sh
"$HOME/dotfiles/install.sh" --force
```

To create only the configuration symlinks:

```sh
"$HOME/dotfiles/install.sh" --skip-tmux-plugins
```

The installer is idempotent and can be run again after pulling updates.
