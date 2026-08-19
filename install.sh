#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
FORCE=0
SKIP_TMUX_PLUGINS=0
BACKUP_DIR=""

usage() {
  cat <<'EOF'
Usage: ./install.sh [--force] [--skip-tmux-plugins]

Create symlinks for the Neovim and tmux configurations.

Options:
  --force              Move conflicting configs to a timestamped backup first.
  --skip-tmux-plugins  Do not install TPM or the configured tmux plugins.
  -h, --help           Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --force)
      FORCE=1
      ;;
    --skip-tmux-plugins)
      SKIP_TMUX_PLUGINS=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

declare -a NAMES=(nvim tmux)
declare -a SOURCES=("$DOTFILES_DIR/nvim" "$DOTFILES_DIR/tmux")
declare -a TARGETS=("$CONFIG_HOME/nvim" "$CONFIG_HOME/tmux")

is_installed() {
  local source="$1"
  local target="$2"
  [[ -L "$target" && -e "$target" && "$target" -ef "$source" ]]
}

# Check all destinations before changing any of them.
for index in "${!TARGETS[@]}"; do
  target="${TARGETS[$index]}"
  source="${SOURCES[$index]}"

  if is_installed "$source" "$target"; then
    continue
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    if ((FORCE == 0)); then
      printf 'Refusing to replace existing path: %s\n' "$target" >&2
      printf 'Re-run with --force to move conflicts into a backup directory.\n' >&2
      exit 1
    fi
  fi
done

mkdir -p "$CONFIG_HOME"

for index in "${!TARGETS[@]}"; do
  name="${NAMES[$index]}"
  source="${SOURCES[$index]}"
  target="${TARGETS[$index]}"

  if is_installed "$source" "$target"; then
    printf '%s is already linked: %s\n' "$name" "$target"
    continue
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -z "$BACKUP_DIR" ]]; then
      BACKUP_DIR="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
      mkdir -p "$BACKUP_DIR"
    fi
    mv -- "$target" "$BACKUP_DIR/$name"
    printf 'Backed up %s to %s\n' "$target" "$BACKUP_DIR/$name"
  fi

  ln -s -- "$source" "$target"
  printf 'Linked %s -> %s\n' "$target" "$source"
done

if ((SKIP_TMUX_PLUGINS == 0)); then
  if ! command -v git >/dev/null 2>&1; then
    printf 'Git is required to install tmux plugins.\n' >&2
    exit 1
  fi

  TPM_DIR="$HOME/.tmux/plugins/tpm"
  if [[ ! -e "$TPM_DIR" ]]; then
    mkdir -p "$(dirname -- "$TPM_DIR")"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
  elif [[ ! -x "$TPM_DIR/bin/install_plugins" ]]; then
    printf 'Existing TPM path is not a valid installation: %s\n' "$TPM_DIR" >&2
    exit 1
  fi

  if command -v tmux >/dev/null 2>&1; then
    "$TPM_DIR/bin/install_plugins"
  else
    printf 'tmux is not installed; TPM is ready, but plugin installation was skipped.\n'
  fi
fi

printf '\nDotfiles installation complete.\n'
