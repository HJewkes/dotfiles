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

# ——— Shell utilities ———
autoload -U colors && colors
RED=$fg[red]; GREEN=$fg[green]; YELLOW=$fg[yellow]; RESET=$reset_color

spinner() {
  local pid=$1 delay=0.1 spin=('|' '/' '-' '\\')
  tput civis
  while kill -0 $pid 2>/dev/null; do
    for c in "${spin[@]}"; do
      printf "%s" "$c"
      sleep $delay
      printf "\b"
    done
  done
  tput cnorm
}

# Run a step with spinner, timing, and failure handling
# Usage: run_step "Description" "command to run"
run_step() {
  local desc=$1 cmd=$2 start=$(date +%s)
  print "${YELLOW}→ $desc...${RESET}"
  setopt localoptions no_print_jobs
  eval "$cmd" & local pid=$!
  spinner $pid
  wait $pid
  local status=$? elapsed=$(( $(date +%s) - start ))
  if [ $status -eq 0 ]; then
    print "${GREEN}✔ $desc (in ${elapsed}s)${RESET}"
  else
    print "${RED}✖ $desc failed (exit $status after ${elapsed}s)${RESET}"
    return $status
  fi
}
