#!/bin/sh
# you-should-use installer
# Usage: curl -fsSL https://raw.githubusercontent.com/vangie/you-should-use/main/install.sh | sh
set -e

REPO="https://github.com/vangie/you-should-use.git"
INSTALL_DIR="$HOME/.you-should-use"

info() { printf '\033[1;34m%s\033[0m\n' "$1"; }
success() { printf '\033[1;32m%s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$1"; }
error() { printf '\033[1;31m%s\033[0m\n' "$1"; exit 1; }

# Check for git
command -v git >/dev/null 2>&1 || error "git is required but not installed."

# Clone or update
if [ -d "$INSTALL_DIR" ]; then
  info "Updating existing installation..."
  git -C "$INSTALL_DIR" pull --ff-only
else
  info "Cloning you-should-use..."
  git clone "$REPO" "$INSTALL_DIR"
fi

# Detect current shell
detect_shell() {
  case "$SHELL" in
    */zsh)  echo "zsh" ;;
    */bash) echo "bash" ;;
    */fish) echo "fish" ;;
    *)
      # Fallback: check what's available
      if command -v zsh >/dev/null 2>&1; then echo "zsh"
      elif command -v bash >/dev/null 2>&1; then echo "bash"
      elif command -v fish >/dev/null 2>&1; then echo "fish"
      else echo "unknown"
      fi
      ;;
  esac
}

DETECTED_SHELL=$(detect_shell)
info "Detected shell: $DETECTED_SHELL"

SOURCE_LINE=""
RC_FILE=""

case "$DETECTED_SHELL" in
  zsh)
    SOURCE_LINE="source $INSTALL_DIR/you-should-use.plugin.zsh"
    RC_FILE="$HOME/.zshrc"
    ;;
  bash)
    SOURCE_LINE="source $INSTALL_DIR/you-should-use.plugin.bash"
    RC_FILE="$HOME/.bashrc"
    ;;
  fish)
    FISH_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d"
    mkdir -p "$FISH_CONF_DIR"
    ln -sf "$INSTALL_DIR/conf.d/you-should-use.fish" "$FISH_CONF_DIR/you-should-use.fish"
    success "Linked fish plugin to $FISH_CONF_DIR/you-should-use.fish"
    success "Restart your shell to activate: exec fish"
    exit 0
    ;;
  *)
    warn "Could not detect your shell. Manual setup required."
    echo ""
    echo "Add one of the following to your shell config:"
    echo "  Zsh:  source $INSTALL_DIR/you-should-use.plugin.zsh"
    echo "  Bash: source $INSTALL_DIR/you-should-use.plugin.bash"
    echo "  Fish: ln -sf $INSTALL_DIR/conf.d/you-should-use.fish ~/.config/fish/conf.d/"
    exit 0
    ;;
esac

# Add source line to rc file if not already present
if [ -f "$RC_FILE" ] && grep -qF "$SOURCE_LINE" "$RC_FILE" 2>/dev/null; then
  warn "Already configured in $RC_FILE"
else
  echo "" >> "$RC_FILE"
  echo "# you-should-use: shell plugin for alias reminders and modern command suggestions" >> "$RC_FILE"
  echo "$SOURCE_LINE" >> "$RC_FILE"
  success "Added to $RC_FILE"
fi

success "Installation complete! Restart your shell to activate: exec \$SHELL"
