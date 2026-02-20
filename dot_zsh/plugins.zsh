# Zinit installer
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Plugins — turbo mode for fast shell startup
zinit wait lucid for \
    atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
        zdharma-continuum/fast-syntax-highlighting \
    blockf \
        zsh-users/zsh-completions \
    atload"!_zsh_autosuggest_start; \
        _tab_accept_or_complete() { \
            if [[ -n \"\$POSTDISPLAY\" ]]; then \
                zle autosuggest-accept; \
            else \
                zle expand-or-complete; \
            fi; \
        }; \
        zle -N _tab_accept_or_complete; \
        bindkey '^I' _tab_accept_or_complete" \
        zsh-users/zsh-autosuggestions
