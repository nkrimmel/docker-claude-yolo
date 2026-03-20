#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Installs 'claude-yolo' and 'claude-docker' as terminal commands.
#
# Usage:
#   cd claude-code-docker/
#   ./install.sh
#
# After installation:
#   claude-yolo ~/projects/my-project
#   claude-docker ~/projects/my-project
#   claude-docker --login
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$SCRIPT_DIR/claude-docker.sh"
BIN_DIR="$HOME/.local/bin"

if [[ ! -f "$LAUNCHER" ]]; then
    echo "❌ claude-docker.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Ensure launcher is executable
chmod +x "$LAUNCHER"

# Ensure ~/.local/bin exists
mkdir -p "$BIN_DIR"

# --- Create wrapper: claude-docker ---
cat > "$BIN_DIR/claude-docker" << EOF
#!/usr/bin/env bash
exec "$LAUNCHER" "\$@"
EOF
chmod +x "$BIN_DIR/claude-docker"

# --- Create wrapper: claude-yolo ---
cat > "$BIN_DIR/claude-yolo" << EOF
#!/usr/bin/env bash
exec "$LAUNCHER" --yolo "\$@"
EOF
chmod +x "$BIN_DIR/claude-yolo"

# --- Ensure ~/.local/bin is in PATH ---
IN_PATH=false
if echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    IN_PATH=true
fi

echo "✅ Commands installed:"
echo "   $BIN_DIR/claude-docker"
echo "   $BIN_DIR/claude-yolo"
echo ""
echo "   Usage:"
echo "   claude-yolo ~/projects/my-project"
echo "   claude-docker --login"
echo "   claude-docker ~/projects/my-project"
echo ""

if [[ "$IN_PATH" == false ]]; then
    # Detect shell config file
    SHELL_NAME="$(basename "$SHELL")"
    case "$SHELL_NAME" in
        zsh)  RC_FILE="$HOME/.zshrc" ;;
        bash) RC_FILE="$HOME/.bashrc" ;;
        *)    RC_FILE="$HOME/.profile" ;;
    esac

    echo "⚠️  $BIN_DIR is not in your PATH."
    echo "   Add the following line to $RC_FILE:"
    echo ""
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""

    read -rp "   Should I add it automatically? [Y/n]: " confirm
    if echo "$confirm" | grep -iqv '^n$'; then
        echo '' >> "$RC_FILE"
        echo '# Claude Code Docker commands' >> "$RC_FILE"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC_FILE"
        echo "   ✅ Added to $RC_FILE."
        echo "   Run 'source $RC_FILE' or open a new terminal."
    fi
fi