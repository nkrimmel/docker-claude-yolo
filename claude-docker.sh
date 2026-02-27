#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Claude Code Docker Launcher
# 
# Usage:
#   ./claude-docker.sh /path/to/your/project
#   ./claude-docker.sh                          # uses current directory
#   ./claude-docker.sh --yolo /path/to/project  # with --dangerously-skip-permissions
#   ./claude-docker.sh --build                  # force rebuild image
# ============================================================================

IMAGE_NAME="claude-code"
CONTAINER_NAME="claude-code-session"
YOLO_MODE=false
FORCE_BUILD=false
PROJECT_DIR=""

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yolo)
            YOLO_MODE=true
            shift
            ;;
        --build)
            FORCE_BUILD=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [PROJECT_DIR]"
            echo ""
            echo "Options:"
            echo "  --yolo     Start Claude Code with --dangerously-skip-permissions"
            echo "  --build    Force rebuild of the Docker image"
            echo "  -h,--help  Show this help"
            echo ""
            echo "If PROJECT_DIR is omitted, the current directory is used."
            exit 0
            ;;
        *)
            PROJECT_DIR="$1"
            shift
            ;;
    esac
done

# Default to current directory
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"  # resolve to absolute path

echo "╔══════════════════════════════════════════════╗"
echo "║         Claude Code Docker Launcher          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Project:    $PROJECT_DIR"
echo "  YOLO mode:  $YOLO_MODE"
echo ""

# --- Get script directory (where the Dockerfile lives) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Build image if needed ---
if [[ "$FORCE_BUILD" == true ]] || ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "🔨 Building Docker image '$IMAGE_NAME'..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
    echo "✅ Image built successfully."
    echo ""
else
    echo "✅ Image '$IMAGE_NAME' already exists. Use --build to rebuild."
    echo ""
fi

# --- Stop old container if running ---
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "🧹 Removing previous container..."
    docker rm -f "$CONTAINER_NAME" &>/dev/null
fi

# --- Build the claude command ---
CLAUDE_CMD="claude"
if [[ "$YOLO_MODE" == true ]]; then
    CLAUDE_CMD="claude --dangerously-skip-permissions"
fi

# --- Run container ---
echo "🚀 Starting container..."
echo "   Mounting: $PROJECT_DIR → /workspace"
echo ""
echo "   Claude Code will start automatically."
echo "   Type 'exit' or Ctrl+D to leave."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

docker run -it --rm \
    --name "$CONTAINER_NAME" \
    -v "$PROJECT_DIR":/workspace \
    -v claude-code-npm-cache:/home/claude/.npm \
    -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
    -e TERM="xterm-256color" \
    "$IMAGE_NAME" \
    bash -c "$CLAUDE_CMD"
