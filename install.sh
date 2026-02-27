#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Installiert 'claude-yolo' und 'claude-docker' als Terminal-Befehle.
#
# Usage:
#   cd claude-code-docker/
#   ./install-commands.sh
#
# Danach nutzbar:
#   claude-yolo ~/projects/mein-projekt
#   claude-docker ~/projects/mein-projekt
#   claude-docker --login
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$SCRIPT_DIR/claude-docker.sh"
BIN_DIR="$HOME/.local/bin"

if [[ ! -f "$LAUNCHER" ]]; then
    echo "❌ claude-docker.sh nicht gefunden in $SCRIPT_DIR"
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

echo "✅ Befehle installiert:"
echo "   $BIN_DIR/claude-docker"
echo "   $BIN_DIR/claude-yolo"
echo ""
echo "   Verwendung:"
echo "   claude-yolo ~/projects/mein-projekt"
echo "   claude-docker --login"
echo "   claude-docker ~/projects/mein-projekt"
echo ""

if [[ "$IN_PATH" == false ]]; then
    # Detect shell config file
    SHELL_NAME="$(basename "$SHELL")"
    case "$SHELL_NAME" in
        zsh)  RC_FILE="$HOME/.zshrc" ;;
        bash) RC_FILE="$HOME/.bashrc" ;;
        *)    RC_FILE="$HOME/.profile" ;;
    esac

    echo "⚠️  $BIN_DIR ist nicht in deinem PATH."
    echo "   Füge folgende Zeile zu $RC_FILE hinzu:"
    echo ""
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""

    read -rp "   Soll ich das automatisch tun? [J/n]: " confirm
    if echo "$confirm" | grep -iqv '^n$'; then
        echo '' >> "$RC_FILE"
        echo '# Claude Code Docker commands' >> "$RC_FILE"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC_FILE"
        echo "   ✅ Zu $RC_FILE hinzugefügt."
        echo "   Einmal 'source $RC_FILE' ausführen oder neues Terminal öffnen."
    fi
fi