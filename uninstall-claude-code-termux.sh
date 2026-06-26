#!/data/data/com.termux/files/usr/bin/sh
set -eu

# Claude Code Termux uninstaller.
# By default, this removes the launcher and installed Termux-patched binaries.
# User configuration under ~/.claude is preserved unless REMOVE_USER_DATA=1 is set.

VERSION="${VERSION:-2.1.193}"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
INSTALL_DIR="${CLAUDE_INSTALL_DIR:-$HOME/.local/share/claude/versions}"
WRAPPER="$PREFIX/bin/claude"
REMOVE_USER_DATA="${REMOVE_USER_DATA:-0}"
REMOVE_BACKUPS="${REMOVE_BACKUPS:-1}"
FORCE="${FORCE:-0}"

STEP_INDEX=0
STEP_TOTAL=6

display_path() {
  case "$1" in
    */.local/share/claude/versions/*) printf '%s\n' ".../versions/${1##*/}" ;;
    /data/data/com.termux/files/*) printf '%s\n' ".../${1#/data/data/com.termux/files/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

banner() {
  if [ "$REMOVE_USER_DATA" = "1" ]; then
    user_data_action="remove"
  else
    user_data_action="preserve"
  fi

  cat <<EOF

+------------------------------------------------------------+
| Claude Code for Termux                                     |
| Uninstaller                                                |
+------------------------------------------------------------+
EOF
  printf '| %-58s |\n' "Target version : $VERSION"
  printf '| %-58s |\n' "Install path   : $(display_path "$INSTALL_DIR/$VERSION")"
  printf '| %-58s |\n' "Launcher       : $(display_path "$WRAPPER")"
  printf '| %-58s |\n' "User data      : $user_data_action"
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

complete_banner() {
  cat <<EOF

+------------------------------------------------------------+
| Uninstall complete                                         |
+------------------------------------------------------------+
EOF
  printf '| %-58s |\n' "Claude Code version $VERSION removal workflow has finished."
  cat <<EOF
+------------------------------------------------------------+

EOF
}

remove_file_if_exists() {
  target_path="$1"
  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    rm -f "$target_path"
    ok "Removed: $target_path"
  fi
}

banner

step "Removing deprecated npm-based Claude Code package"
if command -v npm >/dev/null 2>&1; then
  npm uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1 || true
fi
ok "npm package cleanup completed."

step "Removing Claude Code launcher"
if [ -e "$WRAPPER" ] || [ -L "$WRAPPER" ]; then
  if grep -q "$HOME/.local/share/claude/versions" "$WRAPPER" 2>/dev/null || [ "$FORCE" = "1" ]; then
    rm -f "$WRAPPER"
    ok "Removed launcher: $WRAPPER"
  else
    warn "Launcher was not removed because it does not look like a Termux-patched Claude launcher: $WRAPPER"
    warn "Set FORCE=1 to remove it anyway."
  fi
else
  ok "Launcher is already absent."
fi

step "Removing installed Claude Code version $VERSION"
remove_file_if_exists "$INSTALL_DIR/$VERSION"
remove_file_if_exists "$INSTALL_DIR/$VERSION.pre-dns-patch"

step "Removing backup files"
if [ "$REMOVE_BACKUPS" = "1" ] && [ -d "$INSTALL_DIR" ]; then
  for backup_path in "$INSTALL_DIR/$VERSION.backup."* "$INSTALL_DIR/$VERSION."*.backup.*; do
    [ -e "$backup_path" ] || continue
    rm -f "$backup_path"
    ok "Removed backup: $backup_path"
  done
fi

if [ -d "$INSTALL_DIR" ]; then
  rmdir "$INSTALL_DIR" 2>/dev/null || true
fi
if [ -d "$HOME/.local/share/claude" ]; then
  rmdir "$HOME/.local/share/claude" 2>/dev/null || true
fi

if [ "$REMOVE_BACKUPS" = "1" ]; then
  for wrapper_backup in "$PREFIX/bin/claude.backup."*; do
    [ -e "$wrapper_backup" ] || continue
    rm -f "$wrapper_backup"
    ok "Removed launcher backup: $wrapper_backup"
  done
fi

step "Handling user configuration"
if [ "$REMOVE_USER_DATA" = "1" ]; then
  rm -rf "$HOME/.claude" "$HOME/.claude.json"
  ok "Removed Claude Code user configuration."
else
  ok "User configuration was preserved. Set REMOVE_USER_DATA=1 to remove ~/.claude and ~/.claude.json."
fi

step "Checking command availability"
if command -v claude >/dev/null 2>&1; then
  warn "claude is still available at: $(command -v claude)"
else
  ok "claude command is no longer available."
fi

ok "Claude Code Termux uninstall completed."
complete_banner
