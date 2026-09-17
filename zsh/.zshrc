# Keep PATH ordered and unique, including when this file is sourced again.
typeset -U path PATH
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
export EDITOR=nvim VISUAL=nvim
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"

for tool_bin in "$HOME/.cargo/bin" "$BUN_INSTALL/bin" /snap/bin; do
  [[ -d "$tool_bin" ]] && path+=("$tool_bin")
done
# Personal commands take precedence over system commands.
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
[[ -d "$HOME/bin" ]] && path=("$HOME/bin" $path)
unset tool_bin

[[ -r "$HOME/.ghcup/env" ]] && source "$HOME/.ghcup/env"
[[ -d /usr/local/cuda/bin ]] && path=(/usr/local/cuda/bin $path)
if [[ -d /usr/local/cuda/lib64 ]]; then
  typeset -aU cuda_library_path
  cuda_library_path=(/usr/local/cuda/lib64 ${(s.:.)LD_LIBRARY_PATH})
  export LD_LIBRARY_PATH="${(j.:.)cuda_library_path}"
  unset cuda_library_path
fi

# Local overrides run before plugins (e.g. extra PATH entries or NVM_DIR).
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
[[ -r "$HOME/.zsh_secrets" ]] && source "$HOME/.zsh_secrets"

ZSH_THEME="robbyrussell"
zstyle ':omz:update' mode reminder
zstyle ':omz:plugins:nvm' lazy yes
VI_MODE_SET_CURSOR=true
plugins=(git node npm extract aws nvm vi-mode)
if (( $+commands[fzf] )); then
  plugins+=(fzf)
  [[ -r "$ZSH_CUSTOM/plugins/fzf-tab/fzf-tab.plugin.zsh" ]] && plugins+=(fzf-tab)
fi
[[ -r "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" ]] && \
  plugins+=(zsh-autosuggestions)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  bindkey -v
fi

alias prettyjson='python3 -m json.tool'
# Remove aliases/functions from the previous config when reloading it.
unalias inv ytnotes 2>/dev/null
unfunction wtx _ytnotes 2>/dev/null

inv() {
  emulate -L zsh
  if (( ! $+commands[fzf] || ! $+commands[nvim] )); then
    print -u2 'inv requires fzf and nvim.'
    return 1
  fi
  local preview='head -n 200 -- {}' selected
  local -a files
  if (( $+commands[bat] )); then
    preview='bat --paging=never --color=always -- {}'
  elif (( $+commands[batcat] )); then
    preview='batcat --paging=never --color=always -- {}'
  fi
  selected=$(
    if (( $+commands[rg] )); then
      rg --files --null
    else
      find . -name .git -prune -o -type f -print0
    fi | fzf --read0 --multi --print0 --preview="$preview"
  ) || return
  [[ -n "$selected" ]] || return 0
  files=("${(@0)selected}")
  # fzf terminates its output with NUL; discard the final empty element.
  [[ -z "${files[-1]}" ]] && files[-1]=()
  (( $#files )) && nvim -- "${files[@]}"
}

ytnotes() {
  emulate -L zsh
  if (( $# != 1 )); then
    print -u2 'Usage: ytnotes <video-url>'
    return 2
  fi
  if (( ! $+commands[yt-dlp] || ! $+commands[clean_vtt.py] )); then
    print -u2 'ytnotes requires yt-dlp and clean_vtt.py on PATH.'
    return 1
  fi
  local temp_dir vtt_file text_file
  local -a subtitles
  temp_dir=$(mktemp -d) || return
  {
    # Isolate this download so an older subtitle can never be selected.
    yt-dlp --ignore-config --no-playlist --write-auto-subs --sub-langs en \
      --sub-format vtt --skip-download -P "$temp_dir" \
      -o '%(title)s [%(id)s].%(ext)s' -- "$1" || return
    subtitles=("$temp_dir"/*.en.vtt(N))
    if (( $#subtitles != 1 )); then
      print -u2 'Expected one English subtitle file; no notes were written.'
      return 1
    fi
    vtt_file=${subtitles[1]:t}
    text_file=${vtt_file%.en.vtt}.txt
    if [[ -e "$vtt_file" || -L "$vtt_file" || -e "$text_file" || -L "$text_file" ]]; then
      print -u2 'Subtitle or notes file already exists; refusing to overwrite it.'
      return 1
    fi
    clean_vtt.py "$subtitles[1]" > "$temp_dir/$text_file" || return
    mv -- "$subtitles[1]" "$temp_dir/$text_file" . || return
    print -r -- "Wrote $text_file"
  } always {
    rm -rf -- "$temp_dir"
  }
}

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi
[[ -r "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"

# Keep highlighting after all plugins and widget definitions.
if [[ -r "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
