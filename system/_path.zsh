export PATH=$PATH:/bin
export PATH=$PATH:/sbin
export PATH=$PATH:/usr/bin
export PATH=$PATH:/usr/sbin
export PATH=$PATH:/usr/local/bin
export PATH=$PATH:/usr/local/opt/coreutils/libexec/gnubin
export PATH=$PATH:/Users/hjewkes/projects/devenv/bin
export PATH=$PATH:$ZSH/bin

export MANPATH=$MANPATH:/usr/local/man
export MANPATH=$MANPATH:/usr/local/git/man
export MANPATH=$MANPATH:$MANPATH

# Ensure path arrays do not contain duplicates.
typeset -gU CDPATH FPATH MAILPATH PATH MANPATH
