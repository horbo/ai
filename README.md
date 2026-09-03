# ai

Describe what you want in plain language; `ai` prints one shell command.

The core rule: **`ai` never runs the command it generates.** It writes it to stdout
and nothing else. A shell wrapper puts that command into your editing buffer, so you
read it, edit it if needed, and press Enter yourself.

```console
$ ai find files larger than 100MB in my home directory
$ find ~ -type f -size +100M 2>/dev/null      # <- waiting in your prompt, not executed
```

## Requirements

- `bash`
- `jq`
- The [`claude`](https://claude.ai/code) CLI in your `PATH`
- `zsh` or `bash` for the wrapper

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/horbo/ai/main/install.sh | bash
```

Prefer to read the script first:

```bash
curl -fsSL https://raw.githubusercontent.com/horbo/ai/main/install.sh -o install.sh
less install.sh
bash install.sh
```

The installer clones the repository, symlinks `ai` into your `PATH` and adds a
wrapper to your shell config. It is idempotent, so running it again just updates
the checkout.

| variable | default | meaning |
| --- | --- | --- |
| `AI_INSTALL_DIR` | `~/.local/share/ai` | where the repository is cloned |
| `AI_BIN_DIR` | `~/.local/bin` | where the `ai` symlink is created |
| `AI_RC_FILE` | detected from `$SHELL` | shell config to edit |

Flags: `--dir`, `--bin-dir`, `--no-rc`, `--help`.

The wrapper is added between markers, so it can be updated or removed cleanly:

```zsh
# >>> ai >>>
eval "$(ai init zsh)"
# <<< ai <<<
```

### Manual install

```bash
git clone https://github.com/horbo/ai.git ~/.local/share/ai
ln -s ~/.local/share/ai/ai ~/.local/bin/ai
echo 'eval "$(ai init zsh)"' >> ~/.zshrc
```

### Uninstall

```bash
rm -rf ~/.local/share/ai ~/.local/bin/ai
# then delete the marked block from your shell config
```

## Update

```bash
ai --update
```

Fast-forwards the checkout, then verifies the symlink and the shell config entry
and restores them if either is missing.

## Usage

```bash
ai list processes using the most memory
ai --no-context find large files
ai -e show disk usage             # also print a one-line explanation on stderr
ai -m sonnet rewrite this git history interactively
ai                                # interactive prompt
echo "show disk usage" | ai       # request on stdin
ai -- --version                   # treat the rest as the request, not as flags
```

`ai init zsh` and `ai init bash` print the wrapper if you want to wire it up yourself.

## Output contract

Only the generated command ever reaches stdout. Explanations, warnings, questions
and errors go to stderr, so nothing but a runnable command can end up in your
editing buffer.

| exit code | meaning |
| --- | --- |
| `0` | command on stdout |
| `1` | usage error or missing dependency |
| `2` | the request was too vague; a clarifying question is on stderr |
| `3` | the `claude` CLI failed |

Because the wrapper uses `|| return`, codes 1-3 leave your prompt untouched — you
just see the message.

Without the wrapper `ai` behaves like an ordinary filter:

```bash
ai delete .tmp files older than 7 days | tee /dev/tty | bash   # at your own risk
```

## Configuration

| variable | default | meaning |
| --- | --- | --- |
| `AI_MODEL` | `haiku` | model used for generation |
| `AI_FALLBACK_MODEL` | `sonnet` | model used when the primary one is unavailable |
| `AI_CONTEXT` | `os,shell,tools,cwd` | which environment details to send |
| `AI_MAX_BUDGET_USD` | unset | spending cap for a single call |

## What is sent to the model

Your request, plus an environment block that helps the model produce a command that
actually works on your machine:

- `os` — the distribution name from `/etc/os-release`, so you do not get `apt` on Fedora
- `shell` — `zsh` or `bash`, since their syntax differs
- `tools` — which of `fd`, `rg`, `jq`, `gh`, `docker`, … are installed
- `cwd` — the current directory path and **the names of the files in it**

Drop any part you would rather not send:

```bash
export AI_CONTEXT=os,shell,tools   # no directory listing
export AI_CONTEXT=none             # request only
ai --no-context find large files   # one-off
```

The model runs with all tools disabled, without your Claude Code settings, hooks,
MCP servers or `CLAUDE.md`, and without persisting a session.

## Caveats

Models get things wrong and shell commands can be irreversible. The whole point of
this tool is that you see the command before it runs — read it, especially when it
contains `rm`, `dd`, `mkfs` or a redirect that overwrites a file. `ai` flags
commands the model considers destructive, but that flag is a hint, not a guarantee.

## Development

```bash
tests/run.sh
```

Runs syntax checks, `shellcheck` when available, the output-contract assertions
against a stubbed `claude`, and an end-to-end installer run in a temporary
directory. It makes no API calls.
