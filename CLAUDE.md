# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal collection of ~800 standalone scripts (mostly bash, ~76 Python, a handful of Go/Mach-O/ELF/PE binaries and PowerShell). All live in `binarios/`. There is **no build system, no test suite, no linter, no package manifest** — each file is meant to be executed directly. Categories include: pentesting/recon, CCDC defense, sysadmin/install scripts, networking, SSH tooling, hardening, honeypots, Splunk/Wazuh/Zeek/Suricata, Docker/Distrobox, QEMU, hardware, and HTB shortcuts.

Remote: `https://github.com/4rji/todo.git`. The directory is named `todo` but the working content is `binarios/`.

## The script catalog is the source of truth

`binarios/README.md` is a hand-maintained index of EVERY script with a one-line Spanish description, grouped by category (`###------linux`, `###------ssh`, `###------CCDC`, `###----- Redteam`, etc.). Before guessing what a script does, look it up there:

```bash
rg -i '<keyword>' binarios/README.md
```

When you **add, rename, or remove** a script, update `binarios/README.md` in the matching section. The README is what users grep with `todoo`/`todo` after install — out-of-date entries break their workflow.

## Naming conventions (recognize these to navigate fast)

- `*inst` → installer (e.g. `kasminst`, `cargoinst`, `zeekinst`). Long-running, often interactive, usually OS-detecting.
- `*comm` → command/cheatsheet reference (e.g. `dnscomm`, `wgcomm`, `qemucomm`).
- `*test` → connectivity/sanity test for a stack (e.g. `zeektest`, `suricatatest`).
- `*Mac`, `m` suffix → macOS variant of a Linux script (e.g. `clamvMacinst`, `pingsm`, `ccssh` is M1 version of `cssh`).
- `*Win.ps1`, `*win.ps1` → Windows PowerShell variant (`bannerWin.ps1`, `clamWinst.ps1`).
- `*.enc` → AES-encrypted script (don't try to read; do not decrypt unless explicitly asked).
- `expo`, `expo1`..`expo5` → numbered iterations of evolving tools; the latest number is the active one (`expos` is the recommended scan replacement for `expo`).

## Distribution model

Scripts are deployed to `/opt/4rji/bin/` on a target machine and that path is added to `$PATH`. The deployer scripts:

| Script       | Package manager |
|--------------|-----------------|
| `herrabin`   | apt (Debian/Kali) — default |
| `herrabinp`  | pacman (Arch) |
| `herrabiny`  | yum (RHEL/CentOS) |
| `herrabind`  | dnf |
| `herralias`  | aliases only (no binaries) |

Flags: `-a` full install (download + prompts), `-p` prompts only, `-c` wipe `/opt/4rji/bin/*`. `herrabin` `git clone --depth 1`s this repo, copies `binarios/*` to `/opt/4rji/bin/`, optionally appends `export PATH=$PATH:/opt/4rji/bin` to `~/.zshrc`, and optionally pulls `alias.sh` from the sibling `4rji/4rji` repo.

`bashfun` is the companion that injects shell functions (e.g. `mktemm`, `nv`, `nets`) into `.zshrc`/`.bashrc`. `todoinst` is the bootstrapper that clones this repo into `/opt/4rji/img-bin/` and pulls `descriptions.json` from the sibling `4rji/bina` repo.

## Conventions inside scripts

- Shebang: `#!/usr/bin/env bash` or `#!/usr/bin/env python3`. Almost always present.
- Safety: `set -euo pipefail` is used on ~97 of the more recent/hardened scripts. Older scripts often lack it — match the style of the file you're editing rather than retrofitting silently.
- Root check pattern (when needed): test `$EUID -ne 0`, print a colored "run with sudo" message including `readlink -f "$0"`, then `exit 1`. See `backd-detect` for the canonical version.
- Interactive UX: `read -p` prompts in Spanish, ANSI color escape sequences inline (`\033[1;34m...`, `\e[32m...`), banner separators of underscores. Scripts are made to be run by hand, not piped.
- OS detection: source `/etc/os-release` and branch on `$ID` / `$ID_LIKE`. See `kasminst` for the canonical multi-distro pattern (apt / yum / dnf / pacman arrays).
- `mktem` / `mktem1` helpers create work dirs under `/dev/shm/tmp.XXXXXX` (RAM, no traces) or `/tmp/tmp.XXXXXX`.
- Language: comments and prompts are predominantly **Rioplatense Spanish** (voseo: "ejecutá", "instalá", "dale"), some English. Match the language of the file you're editing.

## Working on this repo

- **Never refactor across files.** Each script is its own universe — there is no shared library to extract into. If two scripts duplicate logic, that is intentional (they ship and run independently on stripped-down target machines).
- **Don't add a Makefile, tests, or CI.** This is a script dump, not a Go module. Resist the urge.
- **Don't reorganize the directory** (one flat `binarios/` folder is the contract `herrabin` relies on — `cp -rf binarios/* /opt/4rji/bin`).
- **Don't break the `*inst` ↔ README.md link.** Renaming `fooinst` to `installFoo` breaks every machine that has `herrabin`-installed binaries plus the README catalog plus `todoo`/`todo` lookups.
- **Don't touch `.enc` files.** They were encrypted on purpose.
- **Commits**: short imperative present tense, often "Update <script>" or "Create <script>". Per the user's global rules: no AI co-author trailers, no build step after changes.

## Common ops

```bash
# Find a script by description (catalog lookup)
rg -i '<keyword>' binarios/README.md

# Find a script by content
rg -l '<pattern>' binarios/

# Inspect a script before changing it
bat binarios/<script>

# Run a script locally
bash binarios/<script>           # one-shot
chmod +x binarios/<script> && ./binarios/<script>

# Install all scripts to /opt/4rji/bin (target machine)
bash binarios/herrabin           # Debian/apt
bash binarios/herrabinp          # Arch/pacman
```

## Sibling repos referenced at runtime

- `github.com/4rji/4rji` — fetched by `herrabin` for `alias.sh`.
- `github.com/4rji/bina` — fetched by `todoinst` for `binarios/descriptions.json`.

If a script `wget`s or `git clone`s one of these, that's why.
