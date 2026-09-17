# Neovim, tmux, and zsh dotfiles

Personal Neovim, tmux, and zsh configuration for quickly setting up a Linux machine.

## Requirements

- Git
- Neovim 0.12 or newer
- tmux
- A Nerd Font
- zsh, Oh My Zsh, and zoxide for the shell configuration

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
~/.zshrc -> ~/dotfiles/zsh/.zshrc
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

## Zsh secrets

The shell loads credentials from `~/.zsh_secrets` when that file exists.
On a new machine, create it from the placeholder template:

```sh
(umask 077; cp -n "$HOME/dotfiles/zsh/.zsh_secrets.example" "$HOME/.zsh_secrets")
chmod 600 "$HOME/.zsh_secrets"
${EDITOR:-vi} "$HOME/.zsh_secrets"
```

Uncomment and fill in the variables you need. Keep real credentials in this
local file; the repository template contains no values. The installer leaves
the secrets file alone, and `.gitignore` excludes copies of it in the repository.

If `ZDOTDIR` is set, the installer links `.zshrc` there instead of in your home
directory. Secrets still live at `~/.zsh_secrets`. The shell configuration retains
machine-specific tool paths, which may need adjusting on another machine.
