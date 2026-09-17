# Neovim, tmux, and zsh dotfiles

Personal Neovim, tmux, and zsh configuration for quickly setting up a Linux machine.

## Requirements

- Git
- Neovim 0.12 or newer
- tmux
- A Nerd Font
- zsh and Oh My Zsh for the shell configuration

The configuration also makes use of `fzf`, `ripgrep`, `lazygit`, and a system
clipboard provider such as `xclip`, `xsel`, or `wl-clipboard`.
Zoxide enables directory jumping; `bat` (or Ubuntu's `batcat`) enables highlighted
file previews. Both are optional. On Ubuntu: `sudo apt install zoxide bat fzf`.
The worktree commands require Git and tmux; `wt` also requires Neovim and Codex.

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
~/bin/wt -> ~/dotfiles/bin/wt
~/bin/wt-rm -> ~/dotfiles/bin/wt-rm
```

It also installs TPM under `~/.tmux/plugins/tpm` and installs the tmux plugins
declared in `tmux/tmux.conf`.
For Zsh it installs [fzf-tab](https://github.com/Aloxaf/fzf-tab),
[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), and
[zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
under `${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins`. Existing plugin installs
are preserved; the installer does not update them. Oh My Zsh itself must already
be installed for the framework features to work.

The installer refuses to replace existing configuration. To move conflicts to
a timestamped directory under `~/.dotfiles-backups` before linking, run:

```sh
"$HOME/dotfiles/install.sh" --force
```

To create only the configuration symlinks:

```sh
"$HOME/dotfiles/install.sh" --skip-tmux-plugins --skip-zsh-plugins
```

The installer is idempotent and can be run again after pulling updates.

## Shell configuration

Open a new terminal after installing, or run `exec zsh` to replace the current
shell. The config uses `$HOME` paths, avoids duplicate PATH entries, and skips
optional tools or plugins that are not installed. It enables Oh My Zsh's bundled
`vi-mode` plugin (with cursor mode indicators) and lazy NVM loading. Node/npm
initialize NVM on first use if it is installed; no Node version is hard-coded.

- Tab: fuzzy completion through fzf-tab.
- Right arrow at the end of a command: accept an autosuggestion.
- Ctrl-R: fuzzy history; Ctrl-T: select files; Alt-C: select a directory.
- Escape, then `vv`: edit the command line in Neovim.
- `inv`: select files to open in Neovim, preserving spaces and newlines in
  selected filenames and doing nothing on cancellation. Previews use bat/batcat
  when available, otherwise head.
- `ytnotes <video-url>`: download one video's English automatic subtitles and
  convert them using `clean_vtt.py`. Both `yt-dlp` and your `clean_vtt.py` must be
  installed separately on PATH. Downloads use an isolated temporary directory;
  outputs in the current directory include the video ID and existing files are
  never overwritten. This helper ignores yt-dlp config to keep its output
  deterministic.

Copy `zsh/.zshrc.local.example` to `~/.zshrc.local` for machine-specific paths or
environment settings, such as a Lua language server installation. It is loaded
before plugins. Keep credentials in `~/.zsh_secrets` instead. GHCup, Bun, and CUDA
integration only runs when the relevant installation paths exist. Cargo's
existing `.zshenv` setup remains independent of this installer.

## Worktrees

Run `wt <name>` from a checkout directory named `develop`, or any subdirectory
inside it. It creates `../worktrees/<name>` on `feature/<name>`, starting from the
local `develop` branch (or reusing an existing feature branch). Names may contain
letters, numbers, `_` and `-`, and must start with a letter or number.

The tmux layout retains Neovim at top left, a shell below it, and Codex on the
right. The Codex command retains the existing
`--sandbox danger-full-access --ask-for-approval never` options. Existing matching
sessions are reused; inside tmux the command switches clients instead of nesting
an attach. A session with the same name but a different working directory is
rejected. Failed tmux setup keeps the branch/worktree and removes any partially
created session so the command can be retried.

`wt-rm <name>` removes the worktree and then its matching tmux session, keeping
the feature branch. Git's normal dirty/locked worktree checks apply: when removal
fails, the session is left running. Neither command accepts an unrelated
repository or branch at the expected worktree path. These scripts replace `wtx`.

The first installation with existing `~/bin/wt` or `~/bin/wt-rm` requires
`--force`; originals are moved into `~/.dotfiles-backups/` before linking.

## Checks

Run `python3 -m unittest discover -s tests -v`. Tests use temporary Git repositories,
fake application commands, and an isolated tmux server on a private socket. They
do not touch your sessions or worktrees. Real tmux/fzf checks skip if unavailable.

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
directory. Secrets still live at `~/.zsh_secrets` and local overrides at
`~/.zshrc.local`. The installer leaves both files alone.
