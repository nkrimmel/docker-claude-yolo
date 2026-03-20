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
#   ./claude-docker.sh --login                  # login via subscription first
# ============================================================================

# --- Get script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.config"

# --- Defaults (overridden by .config) ---
AUTH_MODE="auto"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
IMAGE_NAME="claude-code"
CONTAINER_NAME="claude-code-session"
CPU_LIMIT=""
MEMORY_LIMIT=""
GPU=""
AGENT_TEAMS=""
MAX_TURNS=""

# --- Load config ---
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    echo "⚠️  No .config found. Copy .config.example to .config and edit it."
    echo "   cp $SCRIPT_DIR/.config.example $CONFIG_FILE"
    echo ""
fi

# --- Parse CLI arguments (override config) ---
YOLO_MODE=false
FORCE_BUILD=false
LOGIN_MODE=false
PROJECT_DIR=""

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
        --login)
            LOGIN_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [PROJECT_DIR]"
            echo ""
            echo "Options:"
            echo "  --yolo     Start Claude Code with --dangerously-skip-permissions"
            echo "  --build    Force rebuild of the Docker image"
            echo "  --login    Login via Claude subscription (opens browser on host)"
            echo "  -h,--help  Show this help"
            echo ""
            echo "Configuration: edit .config (see .config.example)"
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
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# --- Build image if needed ---
if [[ "$FORCE_BUILD" == true ]] || ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "🔨 Building Docker image '$IMAGE_NAME'..."
    docker build \
        --build-arg USER_UID="$(id -u)" \
        --build-arg USER_GID="$(id -g)" \
        -t "$IMAGE_NAME" "$SCRIPT_DIR"
    echo "✅ Image built successfully."
    echo ""
else
    echo "✅ Image '$IMAGE_NAME' already exists. Use --build to rebuild."
    echo ""
fi

# --- Login mode: run claude login on HOST (not in container) ---
if [[ "$LOGIN_MODE" == true ]]; then
    echo "🔐 Starting subscription login..."
    echo ""

    mkdir -p "$HOME/.claude"

    # Check if claude CLI is available on host
    if command -v claude &>/dev/null; then
        claude login
    else
        echo "❌ Claude Code CLI ist nicht auf dem Host installiert."
        echo ""
        echo "   Installieren mit:"
        echo "   npm install -g @anthropic-ai/claude-code"
        echo ""
        echo "   Oder manuell einloggen:"
        echo "   1. claude-docker starten (ohne --login)"
        echo "   2. Im Container: claude login"
        echo "   Die Tokens werden in ~/.claude gespeichert."
        exit 1
    fi

    echo ""
    echo "✅ Login successful! Tokens saved to ~/.claude"
    echo "   You can now run without --login."
    echo ""
    exit 0
fi

# --- Resolve auth mode ---
if [[ "$AUTH_MODE" == "auto" ]]; then
    HAS_SUBSCRIPTION=false
    HAS_API_KEY=false

    if [[ -d "$HOME/.claude" ]] && find "$HOME/.claude" -name "*.json" -print -quit 2>/dev/null | grep -q .; then
        HAS_SUBSCRIPTION=true
    fi

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        HAS_API_KEY=true
    fi

    if [[ "$HAS_SUBSCRIPTION" == true && "$HAS_API_KEY" == true ]]; then
        echo "⚡ Both auth methods detected."
        echo "   [1] Subscription (via ~/.claude)"
        echo "   [2] API Key (via ANTHROPIC_API_KEY)"
        read -rp "   Choose [1/2] (default: 1): " choice
        case "${choice:-1}" in
            2) AUTH_MODE="apikey" ;;
            *) AUTH_MODE="subscription" ;;
        esac
    elif [[ "$HAS_SUBSCRIPTION" == true ]]; then
        AUTH_MODE="subscription"
    elif [[ "$HAS_API_KEY" == true ]]; then
        AUTH_MODE="apikey"
    else
        echo "❌ No authentication found!"
        echo ""
        echo "   Option 1 – Subscription login:"
        echo "     $0 --login"
        echo ""
        echo "   Option 2 – API Key:"
        echo "     Set ANTHROPIC_API_KEY in .config"
        exit 1
    fi
fi

echo "╔══════════════════════════════════════════════╗"
echo "║         Claude Code Docker Launcher          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Project:    $PROJECT_DIR"
echo "  Auth:       $AUTH_MODE"
echo "  YOLO mode:  $YOLO_MODE"
echo ""

# --- Ensure config paths exist for persistent config ---
mkdir -p "$HOME/.claude"
touch "$HOME/.claude.json"

# Ensure settings.json exists and has autoMemoryEnabled for persistent context
SETTINGS_FILE="$HOME/.claude/settings.json"
if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{}' > "$SETTINGS_FILE"
fi
# Enable auto-memory and configure claude-hud plugin
if command -v jq &>/dev/null; then
    tmp=$(jq '
        .autoMemoryEnabled = true |
        .extraKnownMarketplaces["jarrodwatts-claude-hud"] //= {
            "source": { "source": "github", "repo": "jarrodwatts/claude-hud" }
        } |
        .enabledPlugins["claude-hud@jarrodwatts-claude-hud"] = true
    ' "$SETTINGS_FILE") && echo "$tmp" > "$SETTINGS_FILE"
fi

# Deploy global CLAUDE.md if not present (unattended mode instructions)
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
BUNDLED_MD="$SCRIPT_DIR/CLAUDE.md"
if [[ ! -f "$CLAUDE_MD" && -f "$BUNDLED_MD" ]]; then
    cp "$BUNDLED_MD" "$CLAUDE_MD"
    echo "📝 Global CLAUDE.md deployed to ~/.claude/CLAUDE.md"
fi

# --- Stop old container if running ---
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "🧹 Removing previous container..."
    docker rm -f "$CONTAINER_NAME" &>/dev/null
fi

# --- Build the claude command ---
# Install claude-hud plugin (no-op if already installed), then start claude
PLUGIN_SETUP="claude plugin marketplace add jarrodwatts/claude-hud 2>/dev/null; claude plugin install claude-hud@jarrodwatts-claude-hud 2>/dev/null; "
CLAUDE_CMD="cd /workspace && ${PLUGIN_SETUP}claude"
if [[ "$YOLO_MODE" == true ]]; then
    CLAUDE_CMD="cd /workspace && ${PLUGIN_SETUP}claude --dangerously-skip-permissions"
fi

# Add max-turns for unattended runs
if [[ -n "${MAX_TURNS:-}" ]]; then
    CLAUDE_CMD="$CLAUDE_CMD --max-turns $MAX_TURNS"
fi

# --- Build docker run arguments ---
DOCKER_ARGS=(
    -it --rm
    --name "$CONTAINER_NAME"
    -v "$PROJECT_DIR":/workspace
    -v claude-code-npm-cache:/home/claude/.npm
    -v "$HOME/.claude":/home/claude/.claude
    -v "$HOME/.claude.json":/home/claude/.claude.json
    -e TERM="xterm-256color"
)

# Auth
if [[ "$AUTH_MODE" == "subscription" ]]; then
    echo "🔑 Using subscription auth"
elif [[ "$AUTH_MODE" == "apikey" ]]; then
    DOCKER_ARGS+=(-e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY")
    echo "🔑 Using API key auth"
fi

# Resource limits from config
if [[ -n "${CPU_LIMIT:-}" ]]; then
    DOCKER_ARGS+=(--cpus="$CPU_LIMIT")
    echo "⚙️  CPU limit: $CPU_LIMIT"
fi

if [[ -n "${MEMORY_LIMIT:-}" ]]; then
    DOCKER_ARGS+=(--memory="$MEMORY_LIMIT")
    echo "⚙️  Memory limit: $MEMORY_LIMIT"
fi

if [[ -n "${GPU:-}" ]]; then
    DOCKER_ARGS+=(--gpus "$GPU")
    echo "⚙️  GPU: $GPU"
fi

# Agent Teams
if [[ "${AGENT_TEAMS:-}" == "true" ]]; then
    DOCKER_ARGS+=(-e CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
    echo "🤖 Agent Teams: enabled (tmux split panes)"
fi

echo ""
echo "🚀 Starting container..."
echo "   Mounting: $PROJECT_DIR → /workspace"
echo ""
echo "   Claude Code will start automatically."
echo "   Type 'exit' or Ctrl+D to leave."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# When agent teams are enabled, start Claude inside a tmux session
# so teammates get their own split panes automatically.
# Uses detached-then-attach pattern for Mac compatibility (Docker Desktop
# routes the PTY through a Linux VM, which breaks tmux command chaining).
if [[ "${AGENT_TEAMS:-}" == "true" ]]; then
    docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" \
        bash -c "tmux new-session -d -s claude && tmux send-keys -t claude '$CLAUDE_CMD' Enter && exec tmux attach -t claude"
else
    docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" \
        bash -c "$CLAUDE_CMD"
fi