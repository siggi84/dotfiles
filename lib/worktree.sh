# Shared validation for bin/wt and bin/wt-rm. Sourced by Bash.

die() { printf '%s\n' "$*" >&2; exit 1; }

require_commands() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
  done
}

worktree_init() {
  [[ $# == 1 ]] || die "Usage: ${0##*/} <name>"
  name=$1
  [[ "$name" =~ ^[[:alnum:]][[:alnum:]_-]*$ ]] || \
    die 'Use a name starting with a letter or number, containing only letters, numbers, _ or -.'
  require_commands git tmux
  repo=$(git rev-parse --show-toplevel) || die 'Run this command inside the develop checkout.'
  [[ "${repo##*/}" == develop ]] || die 'Run this command inside a checkout named develop.'
  repo=$(cd -- "$repo" && pwd -P)
  worktree="${repo%/*}/worktrees/$name"
  branch="feature/$name"
  session=$name
  common_dir=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)
}

validate_worktree() {
  [[ ! -L "$worktree" ]] || die "Refusing a symlink at $worktree"
  [[ -d "$worktree" ]] || die "Not a worktree directory: $worktree"
  local actual_root actual_common actual_branch
  actual_root=$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null) || \
    die "Not a Git worktree: $worktree"
  actual_common=$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir)
  actual_branch=$(git -C "$worktree" symbolic-ref --quiet --short HEAD) || \
    die "Worktree has a detached HEAD: $worktree"
  [[ "$actual_root" == "$worktree" && "$actual_common" == "$common_dir" && "$actual_branch" == "$branch" ]] || \
    die "Existing directory does not match this repository and $branch: $worktree"
}

validate_session() {
  local session_path
  session_path=$(tmux display-message -p -t "=$session:" '#{session_path}')
  [[ "$session_path" == "$worktree" ]] || \
    die "tmux session '$session' belongs to another directory: $session_path"
}
