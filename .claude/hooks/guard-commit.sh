#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash)
# Blocks `git commit` while `npm run typecheck` is failing.
#
# Exit 2 = block the tool call and feed stderr back to Claude, so it fixes the
# type errors and retries instead of landing a broken commit.
# Any other command, or a clean typecheck, exits 0 and gets out of the way.

set -uo pipefail

payload=$(cat)

cmd=$(printf '%s' "$payload" | node -e '
let s = "";
process.stdin.on("data", d => (s += d)).on("end", () => {
  try {
    const j = JSON.parse(s);
    process.stdout.write(String((j.tool_input && j.tool_input.command) || ""));
  } catch { /* malformed payload -> empty -> no-op */ }
});
' 2>/dev/null)

# Match `git commit` as an actual command, not as a substring of e.g.
# `git log --grep "git commit"`. Covers chained forms: `a && git commit`.
printf '%s' "$cmd" | grep -Eq '(^|[;&|]|&&|\|\|)[[:space:]]*git[[:space:]]+(-[^[:space:]]+[[:space:]]+)*commit\b' || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

if ! out=$(npm run --silent typecheck 2>&1); then
  {
    echo "BLOCKED: commit refused — \`npm run typecheck\` is failing."
    echo
    echo "$out"
    echo
    echo "Fix the type errors above, re-run 'npm run typecheck' until it is clean,"
    echo "then commit again. Do not use --no-verify to get around this."
  } >&2
  exit 2
fi

exit 0
