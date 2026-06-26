# Claude Code for Termux

This script is for Android Termux only. It installs Claude Code from Anthropic's official repository and signed release path, then applies the compatibility patches required to run it on Termux `aarch64`.

## Install

Installation via npm is deprecated. Use the one-shot installer below in Termux:

```sh
curl -fsSL https://raw.githubusercontent.com/dextune/claude-code-termux/main/install-claude-code-termux.sh | sh
```

Or, if you already cloned this repository:

```sh
sh ./install-claude-code-termux.sh
```

```text
Claude Code for Termux
Secure installer for Android aarch64

Target version : 2.1.193
Platform       : linux-arm64
Install path   : .../versions/2.1.193
Launcher       : .../usr/bin/claude
```

## Version status

This repository is currently prepared and documented for:

- Claude Code version: `2.1.193`
- Release tag verified by the installer: `v2.1.193`
- Platform artifact: `linux-arm64`
- Installation status marker: this workflow is completed through `2.1.193`

You can test another release by setting `VERSION`, but this repository's default and documented version is `2.1.193`.

## What this installer does

Claude Code is published by Anthropic. The public GitHub repository is available at `https://github.com/anthropics/claude-code`, but the executable binary is not stored directly in that repository. The official installer path referenced by Anthropic downloads signed release metadata and the platform binary from Anthropic release endpoints.

This Termux installer keeps that trust path intact:

1. Installs required Termux packages.
2. Removes the deprecated npm-based Claude Code package if it is present.
3. Verifies that the official Anthropic GitHub tag `v2.1.193` exists.
4. Clones the official repository at that tag.
5. Confirms that the official README still references `https://claude.ai/install.sh`.
6. Downloads the official release manifest and signature.
7. Imports the Anthropic release signing key.
8. Verifies the signing key fingerprint.
9. Verifies `manifest.json.sig`.
10. Downloads the official `linux-arm64` Claude Code binary.
11. Checks the binary SHA256 checksum against the signed manifest.
12. Patches the ELF interpreter for Termux glibc.
13. Applies the Termux DNS resolver compatibility patch.
14. Installs the `claude` launcher wrapper.
15. Disables Claude Code auto-updates for this patched Termux installation.
16. Runs `claude --version` and confirms that it reports `2.1.193`.

## Requirements

- Android with Termux.
- `aarch64` or `arm64` CPU architecture.
- Network access to GitHub and Anthropic release endpoints.
- Enough storage for Termux packages, temporary downloads, and the Claude Code binary.

The script installs its own package dependencies through `pkg`, including `curl`, `git`, `jq`, `gnupg`, `glibc-runner`, and `patchelf-glibc`.

## Installer output

The installer displays a Claude Code-style terminal screen and numbered progress steps:

```text
Claude Code for Termux
Secure installer for Android aarch64

Target version : 2.1.193
Platform       : linux-arm64
Install path   : .../versions/2.1.193
Launcher       : .../usr/bin/claude

[01/12] Installing required Termux packages
         done: Required Termux packages are installed.

[12/12] Running installation verification
2.1.193 (Claude Code)
         done: Claude Code 2.1.193 is installed successfully.

Installation complete

Claude Code version 2.1.193 has been installed.
Command: claude
Path   : .../usr/bin/claude
```

## Installed files

Default paths:

- Launcher: `/data/data/com.termux/files/usr/bin/claude`
- Patched binary: `~/.local/share/claude/versions/2.1.193`
- Pre-DNS-patch backup: `~/.local/share/claude/versions/2.1.193.pre-dns-patch`
- Claude settings: `~/.claude/settings.json`

If an existing launcher or binary is found, the installer creates a timestamped backup before replacing it.

## Verify installation

Run:

```sh
command -v claude
claude --version
```

Expected output:

```text
/data/data/com.termux/files/usr/bin/claude
2.1.193 (Claude Code)
```

You can also confirm the patched ELF interpreter:

```sh
glibc-runner /data/data/com.termux/files/usr/glibc/bin/patchelf \
  --print-interpreter ~/.local/share/claude/versions/2.1.193
```

Expected output:

```text
/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1
```

## Uninstall

Use the one-shot uninstaller below in Termux:

```sh
curl -fsSL https://raw.githubusercontent.com/dextune/claude-code-termux/main/uninstall-claude-code-termux.sh | sh
```

Or, if you already cloned this repository:

```sh
sh ./uninstall-claude-code-termux.sh
```

The uninstaller also displays a terminal screen and numbered progress steps:

```text
Claude Code for Termux
Uninstaller

Target version : 2.1.193
Install path   : .../versions/2.1.193
Launcher       : .../usr/bin/claude

[01/06] Removing deprecated npm-based Claude Code package
         done: npm package cleanup completed.

[06/06] Checking command availability
         done: claude command is no longer available.
```

By default, uninstall removes:

- `/data/data/com.termux/files/usr/bin/claude`
- `~/.local/share/claude/versions/2.1.193`
- `~/.local/share/claude/versions/2.1.193.pre-dns-patch`
- timestamped backups for this version
- the deprecated global npm package `@anthropic-ai/claude-code`, if present

By default, uninstall preserves:

- `~/.claude`
- `~/.claude.json`

## Remove user data

To remove Claude Code user configuration as well:

```sh
curl -fsSL https://raw.githubusercontent.com/dextune/claude-code-termux/main/uninstall-claude-code-termux.sh | REMOVE_USER_DATA=1 sh
```

If you already cloned this repository:

```sh
REMOVE_USER_DATA=1 sh ./uninstall-claude-code-termux.sh
```

## Force launcher removal

The uninstaller only removes `/data/data/com.termux/files/usr/bin/claude` automatically when it appears to be the Termux-patched launcher created by this project. If the launcher was created by another method and you still want to remove it:

```sh
curl -fsSL https://raw.githubusercontent.com/dextune/claude-code-termux/main/uninstall-claude-code-termux.sh | FORCE=1 sh
```

If you already cloned this repository:

```sh
FORCE=1 sh ./uninstall-claude-code-termux.sh
```

## Change version

The default version is `2.1.193`.

To test another version:

```sh
curl -fsSL https://raw.githubusercontent.com/dextune/claude-code-termux/main/install-claude-code-termux.sh | VERSION=2.1.194 sh
```

Use this only when you are ready to validate the new release. A future version can fail if Anthropic changes tag naming, manifest schema, signing keys, binary layout, resolver behavior, or glibc requirements.

## Auto-update policy

The installer writes or updates:

```json
{
  "autoUpdates": false
}
```

This is intentional. Claude Code's own auto-update flow may replace the patched Termux binary with an unpatched official Linux binary. For this Termux workflow, update by running this installer again after validating the target version.

## Patch details

This project does not rebuild Claude Code and does not modify Claude Code source code. It downloads the official signed binary, verifies it, and then applies the minimal runtime compatibility changes needed for Termux.

See `INSTALLATION_DETAILS.md` for the technical installation and patch details.
