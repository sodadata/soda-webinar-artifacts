# Minimal demo-magic-style helpers for a key-advance, auto-typing terminal demo.
# No external dependencies. Source this from a demo script.
#
#   say  "narration"          -> dim "# ..." comment line, advance on key
#   cmd  "shell command"      -> auto-types it, waits for a key, then runs it
#   editfile PATH < heredoc   -> auto-types file content (looks like editing)
#   pause                     -> just wait for a key
#
# Knobs (env): TYPE_SPEED (chars/sec, 0 = instant), DEMO_PROMPT.

TYPE_SPEED="${TYPE_SPEED:-45}"
DEMO_PROMPT="${DEMO_PROMPT:-$'\033[38;5;208m➜\033[0m \033[36msoda-demo\033[0m $ '}"

_C_CMD=$'\033[1;37m'      # bold white  - commands
_C_COMMENT=$'\033[38;5;245m'  # grey   - narration
_C_DONE=$'\033[38;5;71m'  # muted green - done indicator
_C_RST=$'\033[0m'

# Wait for a single keypress from the controlling terminal.
# DEMO_AUTO=1 auto-advances (rehearsal/CI) after DEMO_AUTO_DELAY seconds.
_key() {
  if [ "${DEMO_AUTO:-0}" = "1" ]; then sleep "${DEMO_AUTO_DELAY:-0.6}"; return; fi
  read -rs -n1 _k </dev/tty 2>/dev/null || read -rs -n1 _k </dev/tty 2>/dev/null || true
}

# Type a string with a typewriter effect (instant if TYPE_SPEED=0).
_type() {
  local s="$1" i
  if [ "$TYPE_SPEED" -eq 0 ] 2>/dev/null; then printf '%s' "$s"; return; fi
  local delay; delay="$(awk "BEGIN{printf \"%.4f\", 1/$TYPE_SPEED}")"
  for (( i=0; i<${#s}; i++ )); do
    printf '%s' "${s:i:1}"
    sleep "$delay"
  done
}

prompt() { printf '%b' "$DEMO_PROMPT"; }

pause() { _key; }

say() {
  prompt
  printf '%s' "$_C_COMMENT"
  _type "# $1"
  printf '%s' "$_C_RST"
  _key
  printf '\n'
}

cmd() {
  local c="$*"
  prompt
  printf '%s' "$_C_CMD"
  _type "$c"
  printf '%s' "$_C_RST"
  _key                 # presenter reads the command, presses a key to run it
  printf '\n'
  eval "$c"
  local rc=$?
  printf '\n'
  # done indicator: command finished — safe to advance
  printf '%s✓%s' "$_C_DONE" "$_C_RST"
  _key                 # break: wait before the next step starts typing
  printf '\n'
  return $rc
}

# editfile PATH  (new content on stdin): shows an "editor" prompt, then types
# the content to screen while writing it to PATH. Reads like a live edit.
editfile() {
  local path="$1" content line
  content="$(cat)"
  prompt
  printf '%s' "$_C_CMD"
  _type "\$EDITOR $path"
  printf '%s' "$_C_RST"
  _key
  printf '\n\n'
  : > "$path"
  local saved="$TYPE_SPEED"; TYPE_SPEED="${EDIT_TYPE_SPEED:-160}"
  while IFS= read -r line || [ -n "$line" ]; do
    _type "$line"; printf '\n'
    printf '%s\n' "$line" >> "$path"
  done <<< "$content"
  TYPE_SPEED="$saved"
  printf '\n'
  _key
}
