FROM node:22-slim

# System dependencies + tmux for agent teams
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    build-essential \
    openssh-client \
    jq \
    ripgrep \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Create "claude" user with host UID/GID for correct file permissions.
# Handles conflicts with existing users/groups (e.g. "node" at 1000,
# or "dialout" at GID 20 on macOS hosts).
ARG USER_UID=1000
ARG USER_GID=1000
RUN set -e; \
    # Remove default node user if present
    userdel -r node 2>/dev/null || true; \
    # Try to create group, or reuse existing GID
    if getent group $USER_GID >/dev/null 2>&1; then \
        EXISTING_GROUP=$(getent group $USER_GID | cut -d: -f1); \
        groupmod -n claude "$EXISTING_GROUP" 2>/dev/null || true; \
    else \
        groupadd -g $USER_GID claude; \
    fi; \
    # Try to create user, or reuse existing UID
    if getent passwd $USER_UID >/dev/null 2>&1; then \
        EXISTING_USER=$(getent passwd $USER_UID | cut -d: -f1); \
        usermod -l claude -d /home/claude -m -g $USER_GID "$EXISTING_USER" 2>/dev/null || true; \
    else \
        useradd -m -s /bin/bash -u $USER_UID -g $USER_GID claude; \
    fi; \
    # Ensure home directory exists
    mkdir -p /home/claude && chown $USER_UID:$USER_GID /home/claude

USER claude
WORKDIR /workspace

CMD ["bash"]