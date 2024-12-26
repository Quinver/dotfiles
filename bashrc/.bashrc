#
# ~/.bashrc
#

# If not running interactively, don't do anything

eval "$(starship init bash)"
[[ $- != *i* ]] && return

alias ls='ls -l --color=auto'
alias grep='grep --color=auto'
alias neofetch='fastfetch'
alias icat="kitten icat"
PS1='[\u@\h \W]\$ '
export EDITOR=/usr/bin/nvim

export PATH=$PATH:/home/quinver/.spicetify

export ELECTRON_USE_WAYLAND=1

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# Load Angular CLI autocompletion.
source <(ng completion script)
