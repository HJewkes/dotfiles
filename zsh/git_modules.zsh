#####################################################
# z
# https://github.com/rupa/z/pulls
. `brew --prefix`/etc/profile.d/z.sh

#####################################################
# Syntax Highlighting
# https://github.com/zsh-users/zsh-syntax-highlighting
source `brew --prefix`/Cellar/zsh-syntax-highlighting/0.6.0/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#####################################################
# History Substring Search
# https://github.com/zsh-users/zsh-history-substring-search
source `brew --prefix`/Cellar/zsh-history-substring-search/1.0.2/share/zsh-history-substring-search/zsh-history-substring-search.zsh
# bind UP and DOWN arrow keys
# zmodload zsh/terminfo
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down