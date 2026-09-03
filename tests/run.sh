#!/usr/bin/env bash
set -uo pipefail

root=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stub_dir="$root/tests/stub"
failures=0

pass() { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; failures=$((failures + 1)); }

check() {
    local label=$1 expected=$2 actual=$3
    if [[ $expected == "$actual" ]]; then
        pass "$label"
    else
        fail "$label (expected [$expected], got [$actual])"
    fi
}

run_ai() {
    local case_name=$1; shift
    STUB_CASE=$case_name PATH="$stub_dir:$PATH" AI_CONTEXT=none "$root/ai" "$@"
}

printf 'syntax\n'
for script in "$root/ai" "$root/install.sh" "$root/tests/run.sh" "$stub_dir/claude"; do
    if bash -n "$script"; then pass "bash -n $(basename "$script")"; else fail "bash -n $script"; fi
done

if command -v shellcheck >/dev/null 2>&1; then
    for script in "$root/ai" "$root/install.sh" "$root/tests/run.sh" "$stub_dir/claude"; do
        if shellcheck -S warning "$script"; then pass "shellcheck $(basename "$script")"; else fail "shellcheck $script"; fi
    done
else
    printf '  skip shellcheck (not installed)\n'
fi

printf 'output contract\n'

out=$(run_ai ok list big files 2>/dev/null); status=$?
check "ok: exit status" 0 "$status"
check "ok: command on stdout" "find . -type f -size +100M" "$out"

err=$(run_ai ok list big files 2>&1 >/dev/null)
check "ok: stderr empty" "" "$err"

out=$(run_ai fenced list files 2>/dev/null)
check "fenced: markdown stripped" "ls -la" "$out"

out=$(run_ai danger clean up 2>/dev/null); status=$?
check "danger: exit status" 0 "$status"
check "danger: command on stdout" "rm -rf ./build" "$out"
err=$(run_ai danger clean up 2>&1 >/dev/null)
case $err in
    *"irreversible"*) pass "danger: warning on stderr" ;;
    *) fail "danger: warning on stderr (got [$err])" ;;
esac

out=$(run_ai ok -e list big files 2>/dev/null)
check "explain: stdout still only the command" "find . -type f -size +100M" "$out"
err=$(run_ai ok -e list big files 2>&1 >/dev/null)
check "explain: explanation on stderr" "Lists files over 100MB." "$err"

for case_name in question empty api_error garbage; do
    out=$(run_ai "$case_name" "do something" 2>/dev/null)
    check "$case_name: stdout empty" "" "$out"
done

run_ai question "do something" >/dev/null 2>&1; check "question: exit status" 2 "$?"
err=$(run_ai question "do something" 2>&1 >/dev/null)
check "question: question on stderr" "Which directory should I search?" "$err"

run_ai empty "do something" >/dev/null 2>&1; check "empty: exit status" 3 "$?"
run_ai api_error "do something" >/dev/null 2>&1; check "api_error: exit status" 3 "$?"
run_ai garbage "do something" >/dev/null 2>&1; check "garbage: exit status" 3 "$?"

printf 'usage errors\n'
printf '' | STUB_CASE=ok PATH="$stub_dir:$PATH" "$root/ai" >/dev/null 2>&1
check "empty prompt: exit status" 1 "$?"

PATH="/usr/bin:/bin" AI_CONTEXT=none "$root/ai" anything >/dev/null 2>&1
check "missing claude: exit status" 1 "$?"

err=$(PATH="/usr/bin:/bin" AI_CONTEXT=none "$root/ai" anything 2>&1 >/dev/null)
case $err in
    *"claude not found"*) pass "missing claude: message" ;;
    *) fail "missing claude: message (got [$err])" ;;
esac

"$root/ai" --nope >/dev/null 2>&1
check "unknown option: exit status" 1 "$?"

printf 'wrapper\n'
snippet=$(mktemp)
if command -v zsh >/dev/null 2>&1; then
    "$root/ai" init zsh >"$snippet"
    zsh -n "$snippet"
    check "init zsh: parses" 0 "$?"
else
    printf '  skip init zsh parse (zsh not installed)\n'
fi
"$root/ai" init bash >"$snippet"
bash -n "$snippet"
check "init bash: parses" 0 "$?"
rm -f "$snippet"
"$root/ai" init fish >/dev/null 2>&1
check "init fish: rejected" 1 "$?"

if command -v zsh >/dev/null 2>&1; then
    zsh -f -c "eval \"\$($root/ai init zsh)\"; ai -V" >/dev/null 2>&1
    check "zsh wrapper: clean status without stdout" 0 "$?"
else
    printf '  skip zsh wrapper status (zsh not installed)\n'
fi
bash -c "eval \"\$($root/ai init bash)\"; ai -V" >/dev/null 2>&1
check "bash wrapper: clean status without stdout" 0 "$?"

printf 'completion\n'
if command -v zsh >/dev/null 2>&1; then
    out=$(cd "$root" && zsh -f -c '
        autoload -Uz compinit
        compinit -u -d "${TMPDIR:-/tmp}/ai-test-zcompdump-$$" >/dev/null 2>&1
        eval "$(./ai init zsh)"
        (( $+functions[_ai] )) && print -r -- "${_comps[ai]:-unregistered}"
    ' 2>/dev/null)
    check "zsh: completion registered" "_ai" "$out"

    cd "$root" && zsh -f -c 'eval "$(./ai init zsh)"' >/dev/null 2>&1
    check "zsh: clean status without compinit" 0 "$?"
else
    printf '  skip zsh completion (zsh not installed)\n'
fi

complete_bash() {
    local words=$1 cword=$2
    bash -c '
        eval "$(./ai init bash)"
        IFS=" " read -r -a COMP_WORDS <<<"$1"
        [[ $1 == *" " ]] && COMP_WORDS+=("")
        COMP_CWORD=$2
        _ai
        printf "%s\n" "${COMPREPLY[*]-}"
    ' _ "$words" "$cword"
}

cd "$root" || exit 1
check "bash: models after -m" "haiku sonnet opus fable" "$(complete_bash 'ai -m ' 2)"
check "bash: flags for --no" "--no-context --no-rc" "$(complete_bash 'ai --no' 1)"
check "bash: shells after init" "zsh bash" "$(complete_bash 'ai init ' 2)"
check "bash: init as first word" "init" "$(complete_bash 'ai in' 1)"
check "bash: free text not completed" "" "$(complete_bash 'ai find large ' 3)"

printf 'installer\n'
sandbox=$(cd -P "$(mktemp -d)" && pwd)
source_repo="$sandbox/source"
mkdir -p "$source_repo/tests/stub"
cp "$root/ai" "$root/install.sh" "$source_repo/"
cp "$root/tests/run.sh" "$source_repo/tests/"
cp "$stub_dir/claude" "$source_repo/tests/stub/"
git -C "$source_repo" init -q -b main
git -C "$source_repo" -c user.email=test@test -c user.name=test add -A
git -C "$source_repo" -c user.email=test@test -c user.name=test commit -qm "test fixture"

install_env=(
    AI_REPO="$source_repo"
    AI_BRANCH=main
    AI_INSTALL_DIR="$sandbox/share/ai"
    AI_BIN_DIR="$sandbox/bin"
    AI_RC_FILE="$sandbox/zshrc"
    AI_SHELL=zsh
)

env "${install_env[@]}" bash "$root/install.sh" >/dev/null 2>&1
check "install: exit status" 0 "$?"
check "install: symlink target" "$sandbox/share/ai/ai" "$(readlink "$sandbox/bin/ai" 2>/dev/null)"
check "install: rc block count" 1 "$(grep -c '>>> ai >>>' "$sandbox/zshrc" 2>/dev/null || echo 0)"
check "install: rc eval line" 1 "$(grep -c 'eval "$(ai init zsh)"' "$sandbox/zshrc" 2>/dev/null || echo 0)"

env "${install_env[@]}" bash "$root/install.sh" >/dev/null 2>&1
check "reinstall: exit status" 0 "$?"
check "reinstall: rc block not duplicated" 1 "$(grep -c '>>> ai >>>' "$sandbox/zshrc" 2>/dev/null || echo 0)"

rm -f "$sandbox/bin/ai"
env "${install_env[@]}" "$sandbox/share/ai/ai" --update >/dev/null 2>&1
check "update: exit status" 0 "$?"
check "update: symlink restored" "$sandbox/share/ai/ai" "$(readlink "$sandbox/bin/ai" 2>/dev/null)"

: >"$sandbox/zshrc"
env "${install_env[@]}" "$sandbox/share/ai/ai" --link >/dev/null 2>&1
check "link: rc block restored" 1 "$(grep -c '>>> ai >>>' "$sandbox/zshrc" 2>/dev/null || echo 0)"

env "${install_env[@]}" AI_NO_RC=1 "$sandbox/share/ai/ai" --link >/dev/null 2>&1
check "link --no-rc: rc untouched" 1 "$(grep -c '>>> ai >>>' "$sandbox/zshrc" 2>/dev/null || echo 0)"

printf 'export BEFORE=1\n' >"$sandbox/zshrc"
env "${install_env[@]}" "$sandbox/share/ai/ai" --link >/dev/null 2>&1
printf 'export AFTER=2\n' >>"$sandbox/zshrc"
env "${install_env[@]}" "$sandbox/share/ai/ai" --link >/dev/null 2>&1
check "link: rewrite exit status" 0 "$?"
check "link: line before block kept" 1 "$(grep -c '^export BEFORE=1$' "$sandbox/zshrc" 2>/dev/null || echo 0)"
check "link: line after block kept" 1 "$(grep -c '^export AFTER=2$' "$sandbox/zshrc" 2>/dev/null || echo 0)"
check "link: end marker on its own line" 1 "$(grep -c '^# <<< ai <<<$' "$sandbox/zshrc" 2>/dev/null || echo 0)"

cp "$root/ai" "$sandbox/loose-ai"
env "${install_env[@]}" "$sandbox/loose-ai" --update >/dev/null 2>&1
check "update outside a checkout: exit status" 1 "$?"

rm -rf "$sandbox"

printf '\n'
if [[ $failures -eq 0 ]]; then
    printf 'all checks passed\n'
else
    printf '%d check(s) failed\n' "$failures"
fi
exit $((failures > 0))
