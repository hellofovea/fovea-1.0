#!/bin/zsh
# The Window Bench's rules as greps over its code (after MacApp/scripts/spec-grep.sh). Exit 1 on any hit.
# Scope: the Fovea window's code. The control panel (Panel/) and the harness (App/) are tools,
# not the product, but they bind no keys either.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/FoveaWindowBench"
WINDOW=(Shell Pages Components Settings Notch)
rc=0
fail() { echo "✗ $1"; shift; printf '    %s\n' "$@"; rc=1 }
pass() { echo "✓ $1" }
code() { grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true }

# 1. GUI only: no shortcuts, key handlers or key monitors anywhere in the bench.
hits=$(grep -rnE 'keyboardShortcut|onKeyPress|addLocalMonitorForEvents|addGlobalMonitorForEvents|onExitCommand|onMoveCommand|keyDown\(with' . | code)
[[ -z "$hits" ]] && pass "no keyboard shortcuts or key handlers" || fail "key handling" "${(f)hits}"

# 2. Color and duration literals live in Tokens only.
hits=$(grep -rnE 'Color\(red:|Color\(\.sRGB|Color\(hex:|#[0-9A-Fa-f]{6}|0x[0-9A-Fa-f]{6}' "${WINDOW[@]}" | code)
[[ -z "$hits" ]] && pass "no color literals outside Tokens" || fail "color literal" "${(f)hits}"
hits=$(grep -rnE '(interpolatingSpring|\.smooth|\.snappy|\.spring|\.bouncy)\(' "${WINDOW[@]}" | code)
[[ -z "$hits" ]] && pass "springs come from Motion only" || fail "spring outside Motion" "${(f)hits}"
hits=$(grep -rnE 'withAnimation\(\.|\.animation\(\.(easeIn|easeOut|linear|default)' "${WINDOW[@]}" | code | grep -vE 'motion\.seconds|reduced' || true)
[[ -z "$hits" ]] && pass "animations go through the Motion layer" || fail "animation outside Motion" "${(f)hits}"

# 3. No catch-all bucket, no efficiency metrics.
hits=$(grep -rnE '"[^"]*\b(Uncategorized|Other projects|Quick tasks|Misc)\b[^"]*"|time saved|streak|words per minute' "${WINDOW[@]}" | code)
[[ -z "$hits" ]] && pass "no catch-all bucket or efficiency metric copy" || fail "forbidden copy" "${(f)hits}"

# 4. Running is never a spinner.
hits=$(grep -rnE 'ProgressView\(\)|\.progressViewStyle\(\.circular\)' "${WINDOW[@]}" | code)
[[ -z "$hits" ]] && pass "no indeterminate spinners" || fail "spinner" "${(f)hits}"

# 5. No sidebar in the window.
hits=$(grep -rnE 'NavigationSplitView|\.listStyle\(\.sidebar\)' "${WINDOW[@]}" | code)
[[ -z "$hits" ]] && pass "no sidebar" || fail "sidebar" "${(f)hits}"

# 6. Saved state goes through PersistentStore, not AppStorage or SceneStorage.
hits=$(grep -rnE '@AppStorage|@SceneStorage' . | code)
[[ -z "$hits" ]] && pass "state through PersistentStore only" || fail "AppStorage/SceneStorage" "${(f)hits}"

exit $rc
