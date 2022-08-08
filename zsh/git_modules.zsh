#####################################################
# z
# https://github.com/rupa/z/pulls
. `brew --prefix`/etc/profile.d/z.sh

# Syntax Highlighting
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# bind UP and DOWN arrow keys
source $(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh
zmodload zsh/terminfo
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down