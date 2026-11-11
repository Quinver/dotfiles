# --- Oh My Zsh ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git fzf zsh-autosuggestions zsh-syntax-highlighting)  # syntax-highlighting last
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
source $ZSH/oh-my-zsh.sh

# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"
export PATH=$PATH:/home/quinver/.spicetify

# --- History ---
HISTSIZE=50000
SAVEHIST=50000
setopt hist_ignore_all_dups hist_reduce_blanks

# --- Environment ---
export EDITOR=nvim VISUAL=nvim
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# --- Tools ---
eval "$(zoxide init zsh)"

# --- Aliases ---
alias ls='eza --icons --group-directories-first'
alias ll='eza -la --git --icons --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never --style=plain'
dot() {
  if [[ $1 == sync ]]; then shift; ~/.local/bin/dot-sync "$@"
  else git --git-dir=$HOME/.dotfiles --work-tree=$HOME "$@"; fi
}
