#####################################################
# z
# https://github.com/rupa/z/pulls
. `brew --prefix`/etc/profile.d/z.sh

#####################################################
# Syntax Highlighting
# https://github.com/zsh-users/zsh-syntax-highlighting
source ~/gitsrc/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#####################################################
# History Substring Search
# https://github.com/zsh-users/zsh-history-substring-search
source ~/gitsrc/zsh-history-substring-search/zsh-history-substring-search.zsh
# bind UP and DOWN arrow keys
zmodload zsh/terminfo
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
