# Installation Details

This document describes the compatibility changes applied by `install-claude-code-termux.sh` after it verifies the official Claude Code release artifact.

## Version status

- Completed target version: `2.1.193`
- Official tag checked by the installer: `v2.1.193`
- Platform artifact: `linux-arm64`
- Runtime target: Android Termux `aarch64` with Termux glibc support

## Scope

The installer does not rebuild Claude Code and does not modify Claude Code source code. It downloads the official signed release artifact, verifies the release metadata, verifies the binary checksum, and then applies Termux-specific binary compatibility adjustments.

## 1. ELF interpreter patch

The official `linux-arm64` binary expects the standard Linux glibc dynamic loader:

```text
/lib/ld-linux-aarch64.so.1
```

Termux does not provide that path. The installer uses `patchelf-glibc` through `glibc-runner` to point the binary at the Termux glibc loader:

```text
/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1
```

Command shape:

```sh
glibc-runner patchelf --set-interpreter "$PREFIX/glibc/lib/ld-linux-aarch64.so.1" claude
```

This changes ELF metadata. It does not rewrite application logic.

## 2. DNS resolver fd patch

The Claude Code runtime can reference standard Linux resolver files:

```text
/etc/resolv.conf
/etc/hosts
```

Termux keeps those files under:

```text
/data/data/com.termux/files/usr/etc/resolv.conf
/data/data/com.termux/files/usr/etc/hosts
```

On Android, `/etc/resolv.conf` may not exist or may not resolve the way a normal Linux distribution expects. That can cause DNS lookups to fall back to `127.0.0.1:53` and time out.

To avoid that, the installer replaces the embedded path strings with short file descriptor paths:

```text
/etc/resolv.conf -> /dev/fd/3
/etc/hosts       -> /dev/fd/4
```

The replacement strings are shorter than the original strings, so the remaining bytes are padded with NUL bytes:

```text
/etc/resolv.conf -> /dev/fd/3\0\0\0\0\0\0\0
/etc/hosts       -> /dev/fd/4\0
```

This is a string constant patch, not an instruction patch.

## 3. Launcher wrapper

The installer writes a launcher to:

```text
/data/data/com.termux/files/usr/bin/claude
```

The wrapper clears library path variables that can interfere with a glibc binary, opens the Termux resolver files as file descriptors `3` and `4`, and then executes the patched Claude Code binary:

```sh
unset LD_PRELOAD
unset LD_LIBRARY_PATH
export TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
exec 3< "/data/data/com.termux/files/usr/etc/resolv.conf"
exec 4< "/data/data/com.termux/files/usr/etc/hosts"
exec "$HOME/.local/share/claude/versions/2.1.193" "$@"
```

File descriptors `3` and `4` are paired with the DNS resolver fd patch.

## 4. Auto-update disable

The installer writes or updates:

```json
{
  "autoUpdates": false
}
```

Claude Code auto-updates can replace the patched Termux binary with a fresh unpatched Linux binary. For this workflow, the safer update path is to run the installer again for a specific version after validating that version.

## 5. Verification points

The installer verifies:

- official GitHub tag `v2.1.193`
- official README installer URL
- release signing key fingerprint
- signed release manifest
- `linux-arm64` checksum from the signed manifest
- patched ELF interpreter
- `claude --version` output containing `2.1.193`

Manual checks:

```sh
command -v claude
claude --version
glibc-runner /data/data/com.termux/files/usr/glibc/bin/patchelf \
  --print-interpreter ~/.local/share/claude/versions/2.1.193
```

Expected output:

```text
/data/data/com.termux/files/usr/bin/claude
2.1.193 (Claude Code)
/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1
```

## 6. Upstream change risks

Future Claude Code versions may require changes if Anthropic changes:

- GitHub tag naming
- release manifest schema
- platform key names
- signing keys
- binary checksum fields
- ELF layout
- embedded resolver path strings
- runtime DNS behavior
- glibc dependencies
- syscall usage

The DNS resolver patch is the most version-sensitive part because it depends on embedded path strings remaining present in the binary.
