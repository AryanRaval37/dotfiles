# --- PATH ---
# System directories first, then Homebrew, then user tools.
# NOTE: do not write `export PATH="..."` without `:$PATH` - that wipes the
# whole path. Python versions are managed by uv, not by a PATH override.
typeset -U path PATH   # keep PATH free of duplicates
path=(/usr/local/bin /opt/homebrew/bin /usr/bin /bin /usr/sbin /sbin $path)

# uv-managed Python interpreters and uv-installed tools
export PATH="$HOME/.local/bin:$PATH"

export PATH="$HOME/.cargo/bin:$PATH"

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

plugins=(
    git
    fzf-tab
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --icons=always $realpath'

# --- eza ---
# Plain white output like normal ls (change to "reset:di=34" for blue folders)
export EZA_COLORS="reset"

alias ll="eza -l --icons=auto --git --group-directories-first"
alias la="eza -la --icons=auto --git --group-directories-first"
alias lt="eza --tree --level=2 --icons=auto --group-directories-first"
alias clear="clear && fastfetch"
alias top="btop"
alias lg="lazygit"

# Smart ls: tree for small folders, horizontal grid for big ones
unalias ls 2>/dev/null
ls() {
  # With flags, a file, or several paths, just run normal eza
  if (( $# > 1 )) || [[ $1 == -* ]] || [[ -n $1 && ! -d $1 ]]; then
    eza --icons=auto --group-directories-first "$@"
    return
  fi

  local dir=${1:-.}
  local tree
  tree=$(eza --tree --level=2 --icons=always --color=always --group-directories-first "$dir")

  # Show the tree only if it fits in half the window height
  if (( $(wc -l <<< "$tree") <= 2 * LINES / 3 )); then
    print -r -- "$tree"
  else
    eza --icons=auto --group-directories-first "$dir"
  fi
}

# juliaup
path=("$HOME/.juliaup/bin" $path)
export PATH
# Tab completion for juliaup and julia channel selection
[ -f "$HOME/.julia/juliaup/completions/zsh.zsh" ] && source "$HOME/.julia/juliaup/completions/zsh.zsh"

# Use bat to preview files, and tree to preview directories
export FZF_DEFAULT_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || tree -C {} 2>/dev/null | head -200'"

# Apply previews when searching files via Ctrl+T
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {} 2>/dev/null'"

# Apply previews when switching directories via Alt+C (Esc+C on Mac)
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

_uv_auto_venv() {
  local dir=$PWD venv=""

  # Walk up from the current dir looking for .venv
  while true; do
    if [[ -f $dir/.venv/bin/activate ]]; then
      venv=$dir/.venv
      break
    fi
    [[ $dir == / ]] && break
    dir=${dir:h}
  done

  if [[ -n $venv ]]; then
    [[ $VIRTUAL_ENV == $venv ]] && return      # already active
    # Switch away from a venv we auto-activated earlier
    if [[ -n $_UV_AUTO_VENV ]] && (( $+functions[deactivate] )); then
      deactivate
    fi
    source "$venv/bin/activate"
    _UV_AUTO_VENV=$venv
  elif [[ -n $_UV_AUTO_VENV && $VIRTUAL_ENV == $_UV_AUTO_VENV ]]; then
    # Left the project: deactivate only what we activated
    (( $+functions[deactivate] )) && deactivate
    unset _UV_AUTO_VENV
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _uv_auto_venv
_uv_auto_venv

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

fastfetch
