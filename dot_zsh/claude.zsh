# Claude Code profiles: isolated session state, shared tooling.
# Rationale and the CLAUDE_CONFIG_DIR test results live in
# docs/claude-account-separation.md in the chezmoi source.

CLAUDE_HOME="$HOME/.claude"
CLAUDE_PROFILE_ROOT="${CLAUDE_PROFILE_ROOT:-$HOME/.claude-profiles}"

# Linked back to ~/.claude so tooling and permission grants stay machine-wide.
# Everything else (projects, history, todos, credentials) stays per-profile.
CLAUDE_PROFILE_SHARED=(
  agents commands hooks output-styles plugins scripts skills
  .mcp.json settings.json settings.local.json
)

_claude_profile_link() {
  local dir=$1 item
  mkdir -p "$dir"
  for item in $CLAUDE_PROFILE_SHARED; do
    [[ -e "$CLAUDE_HOME/$item" ]] || continue
    [[ -e "$dir/$item" || -L "$dir/$item" ]] && continue
    ln -s "$CLAUDE_HOME/$item" "$dir/$item"
  done
}

_claude_profile_list() {
  print -r -- "default"
  [[ -d $CLAUDE_PROFILE_ROOT ]] || return 0
  local dir
  for dir in $CLAUDE_PROFILE_ROOT/*(N/); do print -r -- "${dir:t}"; done
}

# The machine-wide baseline lives in a file rather than an exported variable, so
# changing it reaches already-open shells too. The `claude` shim on PATH reads it
# at launch; see ~/.local/libexec/claude-shim/claude.
CLAUDE_BASELINE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/claude/default-profile"

_claude_profile_baseline() {
  if [[ -n ${CLAUDE_DEFAULT_PROFILE+x} ]]; then
    print -r -- "${CLAUDE_DEFAULT_PROFILE:-default}"
  elif [[ -r $CLAUDE_BASELINE_FILE ]]; then
    local name; name=$(head -n1 "$CLAUDE_BASELINE_FILE"); name=${name//[[:space:]]/}
    print -r -- "${name:-default}"
  else
    print -r -- default
  fi
}

claude-profile() {
  local name=$1
  case $name in
    "")
      if [[ -n ${CLAUDE_CONFIG_DIR:-} ]]; then
        print -r -- "${CLAUDE_CONFIG_DIR:t}"
      elif [[ -n ${CLAUDE_DEFAULT_PROFILE+x} ]]; then
        print -r -- "$(_claude_profile_baseline) (this shell)"
      else
        print -r -- "$(_claude_profile_baseline) (baseline)"
      fi ;;
    list) _claude_profile_list ;;
    baseline)
      if [[ -z ${2:-} ]]; then
        _claude_profile_baseline
      elif [[ $2 != default && ! -d $CLAUDE_PROFILE_ROOT/$2 ]]; then
        print -u2 -r -- "claude-profile: no profile named '$2' under $CLAUDE_PROFILE_ROOT"
        return 1
      else
        mkdir -p "${CLAUDE_BASELINE_FILE:h}"
        print -r -- "$2" > "$CLAUDE_BASELINE_FILE"
        print -r -- "baseline: $2"
      fi ;;
    default)
      # Unsetting alone would hand launches back to the baseline, so pin this
      # shell to ~/.claude explicitly.
      unset CLAUDE_CONFIG_DIR
      export CLAUDE_DEFAULT_PROFILE=default
      print -r -- "default" ;;
    -h|--help)
      print -r -- "usage: claude-profile [<name>|default|list|baseline [<name>|default]]" ;;
    *)
      _claude_profile_link "$CLAUDE_PROFILE_ROOT/$name" || return 1
      export CLAUDE_CONFIG_DIR="$CLAUDE_PROFILE_ROOT/$name"
      unset CLAUDE_DEFAULT_PROFILE
      print -r -- "$name" ;;
  esac
}

compdef '_values "claude profile" $(_claude_profile_list)' claude-profile 2>/dev/null
