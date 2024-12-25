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
