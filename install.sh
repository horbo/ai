#!/usr/bin/env bash
set -euo pipefail

AI_REPO=${AI_REPO:-https://github.com/horbo/ai.git}
AI_BRANCH=${AI_BRANCH:-main}
AI_INSTALL_DIR=${AI_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/ai}
AI_BIN_DIR=${AI_BIN_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}
AI_RC_FILE=${AI_RC_FILE:-}
no_rc=0

log() { printf 'ai: %s\n' "$*" >&2; }
die() { log "$*"; exit 1; }

usage() {
    cat >&2 <<'USAGE'
Usage: install.sh [options]

Clones horbo/ai, links it into your PATH and adds the shell wrapper
to your shell config.

Options:
      --dir <path>       clone location (default: ~/.local/share/ai)
      --bin-dir <path>   symlink location (default: ~/.local/bin)
      --no-rc            do not touch the shell config file
  -h, --help             show this help

Environment: AI_REPO, AI_BRANCH, AI_INSTALL_DIR, AI_BIN_DIR, AI_RC_FILE
USAGE
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --dir) [[ $# -ge 2 ]] || die "--dir requires a value"; AI_INSTALL_DIR=$2; shift 2 ;;
        --bin-dir) [[ $# -ge 2 ]] || die "--bin-dir requires a value"; AI_BIN_DIR=$2; shift 2 ;;
        --no-rc) no_rc=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage; die "unknown option: $1" ;;
    esac
done

command -v git >/dev/null 2>&1 || die "git is required"

for dependency in claude jq; do
    command -v "$dependency" >/dev/null 2>&1 ||
        log "warning: $dependency not found in PATH, ai will not run until it is installed"
done

if [[ -d $AI_INSTALL_DIR ]]; then
    git -C "$AI_INSTALL_DIR" rev-parse --git-dir >/dev/null 2>&1 ||
        die "$AI_INSTALL_DIR exists and is not a git checkout"
    log "updating existing checkout in $AI_INSTALL_DIR"
    git -C "$AI_INSTALL_DIR" pull --ff-only >&2 ||
        die "git pull failed in $AI_INSTALL_DIR"
else
    log "cloning $AI_REPO into $AI_INSTALL_DIR"
    mkdir -p "$(dirname "$AI_INSTALL_DIR")"
    git clone --quiet --branch "$AI_BRANCH" "$AI_REPO" "$AI_INSTALL_DIR" ||
        die "git clone failed"
fi

AI_BIN_DIR="$AI_BIN_DIR" AI_RC_FILE="$AI_RC_FILE" AI_NO_RC="$no_rc" \
    "$AI_INSTALL_DIR/ai" --link

log "done"
if [[ $no_rc -eq 1 ]]; then
    log "add this to your shell config to enable the wrapper:"
    log '  eval "$(ai init zsh)"'
else
    log "open a new shell, or run: exec ${SHELL:-sh}"
fi
