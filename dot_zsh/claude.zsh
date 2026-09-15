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

claude-profile() {
  local name=$1
  case $name in
    "")      print -r -- "${${CLAUDE_CONFIG_DIR:t}:-default}" ;;
    list)    _claude_profile_list ;;
    default) unset CLAUDE_CONFIG_DIR; print -r -- "default" ;;
    -h|--help)
      print -r -- "usage: claude-profile [<name>|default|list]" ;;
    *)
      _claude_profile_link "$CLAUDE_PROFILE_ROOT/$name" || return 1
      export CLAUDE_CONFIG_DIR="$CLAUDE_PROFILE_ROOT/$name"
      print -r -- "$name" ;;
  esac
}

compdef '_values "claude profile" $(_claude_profile_list)' claude-profile 2>/dev/null
