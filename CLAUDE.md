# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

`ai`, a bash script that turns a natural-language request into a shell command,
plus `install.sh` (the `curl | bash` installer) and `tests/`. No build system and
no dependencies beyond `claude`, `jq` and `git`.

Published as `horbo/ai`, main branch `main`.

## Running and verifying changes

```bash
tests/run.sh                            # FIRST choice - makes no API calls
./ai list files larger than 100MB       # a real request, costs money
bash -n ai && shellcheck ai
```

`tests/run.sh` puts a stubbed `claude` on the PATH (`tests/stub/claude`, driven by
`STUB_CASE`), asserts the stdout/stderr contract and the exit codes, and runs the
installer end to end in a `mktemp -d` against a throwaway repository built from the
working tree. When you touch output parsing or installation, add a case there
instead of testing through real calls.

## Architecture

The script deliberately **only prints the command to stdout and never runs it**.
Running is the job of the shell wrapper emitted by `ai init zsh|bash`, which in zsh
pushes the result into the editing buffer via `print -z`. This split is the point
of the tool: never add execution (`eval`, `bash -c`) of the generated command to
the script.

`init_snippet` emits the wrapper **and** the completion function (zsh `_ai` +
`compdef`, bash `_ai` + `complete`). When you add a flag to the argument parser,
add it to both variants; the tests cover a few representative cases, not the whole
list. In zsh `compdef` only exists after `compinit`, hence the
`if (( $+functions[compdef] ))` guard; it has to be an `if` rather than `&&`, so
that the eval does not leave `$?` at 1.

The invariant the tests protect: **nothing but the command reaches stdout**. Help,
version, explanations, warnings, questions and errors all go to stderr. The one
exception is `ai init`, whose output is consumed by `eval`.

Exit codes: `0` command, `1` usage error or missing dependency, `2` the model wants
a clarification (question on stderr), `3` the `claude` CLI failed.

Flow: flag parsing (stops at the first non-flag argument, `--` forces the end) →
input from arguments, stdin or `read` → `build_context()` → `claude` with
`--json-schema` and `--output-format json` → `jq` on `.is_error`,
`.structured_output.question`, `.structured_output.command` → stdout.

Two places control the response format: `SCHEMA` (structured output enforced by the
CLI) and `SYSTEM_PROMPT` (when to use `command` versus `question`, and the response
language). Change one, check the other. `strip_fences` is now only a safety net in
case the model puts markdown inside the `command` field.

The `claude` invocation is hardened: `--tools ""`, `--permission-mode dontAsk`,
`--permission-prompts none`, `--setting-sources ""`, `--strict-mcp-config`,
`--no-session-persistence`. That cuts off tools, the `CLAUDE.md` of the working
directory, hooks and MCP servers, and is noticeably faster. Do not use `--bare`: it
requires `ANTHROPIC_API_KEY` and never reads OAuth credentials.

The `claude` call cannot sit directly under `set -e`
(`response=$(...) || status=$?`), because the CLI exits non-zero on an API error
and we still want to print the message from `.result`.

Installation logic lives **in `ai`** (`link_binary`, `ensure_rc_block`, the `--link`
subcommand); after cloning, `install.sh` merely calls `ai --link`. Do not duplicate
the sed work or the markers there. This is what lets `ai --update` repair a broken
symlink and a missing rc entry.

## Conventions

- **Everything in the repository is in English**: code, names, user-facing messages,
  `--help` text, the system prompt, README, tests, commit messages, and this file.
- **Comments kept to an absolute minimum, ideally none.** Prefer a clear function or
  variable name over a comment. A single explanatory line only where the code does
  something that looks wrong but is not.
- `set -euo pipefail` at the top of every script; keep it that way when adding code.
- Messages go to stderr with an `ai:` prefix (the `log` and `die` helpers).
