#
# ~/.bashrc
#

# If not running interactively, don't do anything

eval "$(starship init bash)"
[[ $- != *i* ]] && return

alias ls='ls -l --color=auto'
alias grep='grep --color=auto'
alias neofetch='fastfetch'
PS1='[\u@\h \W]\$ '
export EDITOR=/usr/bin/nvim

export PATH=$PATH:/home/quinver/.spicetify
