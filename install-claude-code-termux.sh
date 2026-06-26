#!/data/data/com.termux/files/usr/bin/sh
set -eu

# Claude Code Termux installer.
# This script validates the official Anthropic GitHub tag, downloads the
# official signed release artifact, and applies the Termux compatibility
# patches required for Android/aarch64.

VERSION="${VERSION:-2.1.193}"
OFFICIAL_GIT_URL="${OFFICIAL_GIT_URL:-https://github.com/anthropics/claude-code.git}"
RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://downloads.claude.ai/claude-code-releases}"
KEY_URL="${KEY_URL:-https://downloads.claude.ai/keys/claude-code.asc}"
EXPECTED_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
PLATFORM="linux-arm64"

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
INSTALL_DIR="${CLAUDE_INSTALL_DIR:-$HOME/.local/share/claude/versions}"
BINARY="$INSTALL_DIR/$VERSION"
WRAPPER="$PREFIX/bin/claude"
GLIBC_RUNNER="$PREFIX/bin/glibc-runner"
PATCHELF_GLIBC="$PREFIX/glibc/bin/patchelf"
GLIBC_LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"

STEP_INDEX=0
STEP_TOTAL=12

display_path() {
  case "$1" in
    */.local/share/claude/versions/*) printf '%s\n' ".../versions/${1##*/}" ;;
    /data/data/com.termux/files/*) printf '%s\n' ".../${1#/data/data/com.termux/files/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

banner() {
  cat <<EOF

+------------------------------------------------------------+
| Claude Code for Termux                                     |
| Secure installer for Android aarch64                       |
+------------------------------------------------------------+
EOF
  printf '| %-58s |\n' "Target version : $VERSION"
  printf '| %-58s |\n' "Platform       : $PLATFORM"
  printf '| %-58s |\n' "Install path   : $(display_path "$BINARY")"
  printf '| %-58s |\n' "Launcher       : $(display_path "$WRAPPER")"
  cat <<EOF
+------------------------------------------------------------+

EOF
}

step() {
  STEP_INDEX=$((STEP_INDEX + 1))
  printf '\n[%02d/%02d] %s\n' "$STEP_INDEX" "$STEP_TOTAL" "$*"
}

ok() {
  printf '         done: %s\n' "$*"
}

warn() {
  printf '%s\n' "Warning: $*" >&2
}

fail() {
  printf '%s\n' "Error: $*" >&2
  exit 1
}

complete_banner() {
  cat <<EOF

+------------------------------------------------------------+
| Installation complete                                      |
+------------------------------------------------------------+
EOF
  printf '| %-58s |\n' "Claude Code version $VERSION has been installed."
  printf '| %-58s |\n' "Command: claude"
  printf '| %-58s |\n' "Path   : $(display_path "$WRAPPER")"
  cat <<EOF
+------------------------------------------------------------+

EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command is not available: $1"
}

backup_if_exists() {
  target_path="$1"
  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    timestamp="$(date +%Y%m%d%H%M%S)"
    backup_path="$target_path.backup.$timestamp"
    mv "$target_path" "$backup_path"
    ok "Existing file was backed up: $backup_path"
  fi
}

case "$(uname -m)" in
  aarch64|arm64) ;;
  *) fail "Unsupported architecture: $(uname -m). This installer supports Termux aarch64/arm64 only." ;;
esac

case "$PREFIX" in
  */com.termux/files/usr) ;;
  *) warn "PREFIX is set to $PREFIX. This installer is intended for Termux." ;;
esac

mkdir -p "$PREFIX/tmp"
WORK_DIR="$(mktemp -d "$PREFIX/tmp/claude-code-install-$VERSION.XXXXXX")"
GNUPGHOME="$WORK_DIR/gnupg"
export GNUPGHOME
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

banner

step "Installing required Termux packages"
export DEBIAN_FRONTEND=noninteractive
pkg update -y
pkg install -y ca-certificates curl git jq gnupg binutils file coreutils grep sed gawk perl glibc-repo
pkg update -y
pkg install -y glibc-runner patchelf-glibc
ok "Required Termux packages are installed."

require_command curl
require_command git
require_command jq
require_command gpg
require_command sha256sum
require_command perl
require_command grep

[ -x "$GLIBC_RUNNER" ] || fail "glibc-runner was not found at $GLIBC_RUNNER"
[ -x "$PATCHELF_GLIBC" ] || fail "patchelf-glibc was not found at $PATCHELF_GLIBC"
[ -e "$GLIBC_LOADER" ] || fail "glibc loader was not found at $GLIBC_LOADER"

step "Removing deprecated npm-based Claude Code package"
if command -v npm >/dev/null 2>&1; then
  npm uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1 || true
fi
ok "npm package cleanup completed."

mkdir -p "$INSTALL_DIR" "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
cd "$WORK_DIR"

# The official GitHub repository does not publish the executable binary.
# It is used here as the release authority, while the signed binary artifact
# is downloaded from the official release endpoint used by Anthropic's installer.
step "Validating official Anthropic GitHub tag v$VERSION"
GIT_TAG_LINE="$(git ls-remote --tags "$OFFICIAL_GIT_URL" "refs/tags/v$VERSION" | head -n 1)"
[ -n "$GIT_TAG_LINE" ] || fail "Official GitHub tag v$VERSION was not found."
GIT_COMMIT="$(printf '%s\n' "$GIT_TAG_LINE" | cut -f 1)"
git clone --depth 1 --branch "v$VERSION" "$OFFICIAL_GIT_URL" "$WORK_DIR/claude-code-official" >/dev/null 2>&1
grep -q 'https://claude.ai/install.sh' "$WORK_DIR/claude-code-official/README.md" || fail "Official README did not contain the expected installer URL."
ok "Official GitHub tag verified: v$VERSION ($GIT_COMMIT)"

BASE="$RELEASE_BASE_URL/$VERSION"
step "Downloading release manifest and signature"
curl -fsSL "$BASE/manifest.json" -o manifest.json
curl -fsSL "$BASE/manifest.json.sig" -o manifest.json.sig

step "Importing Anthropic release signing key"
curl -fsSL "$KEY_URL" -o claude-code.asc
gpg --batch --import claude-code.asc >/dev/null
ACTUAL_FPR="$(gpg --batch --with-colons --fingerprint security@anthropic.com | sed -n 's/^fpr:::::::::\([0-9A-F]*\):/\1/p' | head -n 1)"
[ "$ACTUAL_FPR" = "$EXPECTED_FPR" ] || fail "Unexpected signing key fingerprint: $ACTUAL_FPR"
ok "Signing key fingerprint verified."

step "Verifying signed release manifest"
gpg --batch --verify manifest.json.sig manifest.json
ok "Release manifest signature verified."

TMP_BINARY="$WORK_DIR/claude.$VERSION.tmp"
step "Downloading official $PLATFORM binary"
curl -fsSL "$BASE/$PLATFORM/claude" -o "$TMP_BINARY"

EXPECTED_SHA="$(jq -r '.platforms["linux-arm64"].checksum // empty' manifest.json)"
[ -n "$EXPECTED_SHA" ] || fail "linux-arm64 checksum was not found in the manifest."
ACTUAL_SHA="$(sha256sum "$TMP_BINARY" | cut -d ' ' -f 1)"
[ "$EXPECTED_SHA" = "$ACTUAL_SHA" ] || fail "Checksum verification failed. expected=$EXPECTED_SHA actual=$ACTUAL_SHA"
ok "Binary checksum verified."

step "Patching ELF interpreter for Termux glibc"
env -u LD_PRELOAD -u LD_LIBRARY_PATH "$GLIBC_RUNNER" "$PATCHELF_GLIBC" \
  --set-interpreter "$GLIBC_LOADER" \
  "$TMP_BINARY"
ok "ELF interpreter patch applied."

step "Applying Termux DNS resolver compatibility patch"
cp "$TMP_BINARY" "$BINARY.pre-dns-patch"
perl -0pi -e 's{\Q/etc/resolv.conf\E}{"/dev/fd/3" . "\0" x 7}ge; s{\Q/etc/hosts\E}{"/dev/fd/4" . "\0"}ge' "$TMP_BINARY"
grep -a -q '/dev/fd/3' "$TMP_BINARY" || fail "DNS patch did not add /dev/fd/3."
grep -a -q '/dev/fd/4' "$TMP_BINARY" || fail "DNS patch did not add /dev/fd/4."
ok "DNS resolver compatibility patch applied."

chmod 700 "$TMP_BINARY"
backup_if_exists "$BINARY"
mv "$TMP_BINARY" "$BINARY"
ok "Patched Claude Code binary installed: $BINARY"

step "Installing Claude Code launcher"
backup_if_exists "$WRAPPER"
cat > "$WRAPPER.tmp" <<EOF
#!$PREFIX/bin/sh
unset LD_PRELOAD
unset LD_LIBRARY_PATH
export TMPDIR="\${TMPDIR:-$PREFIX/tmp}"
exec 3< "$PREFIX/etc/resolv.conf"
exec 4< "$PREFIX/etc/hosts"
exec "$BINARY" "\$@"
EOF
chmod 755 "$WRAPPER.tmp"
mv "$WRAPPER.tmp" "$WRAPPER"
ok "Launcher installed: $WRAPPER"

step "Disabling Claude Code auto-updates"
mkdir -p "$HOME/.claude"
SETTINGS="$HOME/.claude/settings.json"
if [ -s "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.backup.$(date +%Y%m%d%H%M%S)"
  jq '.autoUpdates = false' "$SETTINGS" > "$SETTINGS.tmp"
  mv "$SETTINGS.tmp" "$SETTINGS"
else
  printf '{\n  "autoUpdates": false\n}\n' > "$SETTINGS"
fi
chmod 600 "$SETTINGS"
ok "Claude Code auto-updates are disabled."

step "Running installation verification"
INTERPRETER="$(env -u LD_PRELOAD -u LD_LIBRARY_PATH "$GLIBC_RUNNER" "$PATCHELF_GLIBC" --print-interpreter "$BINARY")"
[ "$INTERPRETER" = "$GLIBC_LOADER" ] || fail "Unexpected ELF interpreter: $INTERPRETER"

VERSION_OUTPUT="$(claude --version)"
printf '%s\n' "$VERSION_OUTPUT"
printf '%s\n' "$VERSION_OUTPUT" | grep -q "$VERSION" || fail "claude --version did not report $VERSION."

ok "Claude Code $VERSION is installed successfully."
complete_banner
