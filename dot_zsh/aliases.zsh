alias g='git'

# ls via GNU coreutils
if command -v gls &>/dev/null; then
    alias ls='gls --color -ah --group-directories-first'
    alias l='gls -lAh --color'
    alias ll='gls -l --color'
    alias la='gls -A --color'
fi

# Directory navigation
alias '..'='cd ..'
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -- -='cd -'

# Safety: no spelling correction
alias cp='nocorrect cp'
alias mkdir='nocorrect mkdir'
alias mv='nocorrect mv'
alias rm='nocorrect rm'

# Shortcuts
alias md='mkdir -p'
alias rd='rmdir'
alias da='du -sch'
alias j='jobs -l'

# Reload zshrc
alias reload!='source ~/.zshrc'
