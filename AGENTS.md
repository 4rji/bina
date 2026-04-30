# Repository Guidelines

## Project Structure & Module Organization

This repository is a personal collection of standalone command-line tools and scripts. Nearly all working files live in `binarios/`; keep that flat layout because installer scripts copy `binarios/*` directly to `/opt/4rji/bin/`. The catalog in `binarios/README.md` is the source of truth for script descriptions and grouping. Update it whenever you add, rename, or remove a script.

Notable paths:

- `binarios/`: executable Bash, Python, Go, PowerShell, binaries, archives, and support files.
- `binarios/static/`: static assets used by scripts.
- `binarios/win-ps1-scripts/`: Windows PowerShell scripts.
- `binarios/discontinued/`: retired scripts kept for reference.
- `CLAUDE.md`: detailed maintainer notes for agent work.

## Build, Test, and Development Commands

There is no package manifest, build system, CI setup, or project-wide test runner. Work on scripts directly.

- `rg -i '<keyword>' binarios/README.md`: find a tool by catalog description.
- `rg -l '<pattern>' binarios/`: find scripts by implementation detail.
- `bash binarios/<script>`: run a Bash script locally for manual validation.
- `python3 binarios/<script>.py`: run a Python script locally when applicable.
- `shellcheck binarios/<script>`: lint Bash scripts when ShellCheck is available.

Do not run installer or privileged scripts against a real system unless you understand their side effects and have authorization.

## Coding Style & Naming Conventions

Match the edited file's existing style. New Bash scripts should prefer `#!/usr/bin/env bash`; Python scripts should prefer `#!/usr/bin/env python3`. Use executable permissions for scripts intended to be copied into `$PATH`.

Common naming patterns include `*inst` for installers, `*comm` for command references, `*test` for stack checks, `*Win.ps1` for Windows variants, and `.enc` for encrypted files. Do not decrypt or modify `.enc` files unless explicitly asked. Prompts and comments are often Spanish; keep the surrounding language and tone consistent.

## Testing Guidelines

Tests are manual and script-specific. Before changing behavior, inspect the catalog entry and the target script, then run the narrowest safe command that exercises your change. For scripts with dangerous, network, system, or root effects, validate syntax only where possible, for example `bash -n binarios/<script>` or `python3 -m py_compile binarios/<script>.py`.

## Commit & Pull Request Guidelines

Recent commits use short subjects such as `Update gocom`, `Create webcc`, or brief one-word updates. Keep commit messages concise and imperative when possible. Pull requests should describe changed scripts, mention catalog updates, list manual validation performed, and include screenshots only for UI or terminal-output changes.
