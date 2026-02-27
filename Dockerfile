FROM node:22-slim

# System dependencies
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
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Remove default "node" user (UID 1000) that ships with node image,
# then create "claude" user with host UID/GID for correct file permissions
ARG USER_UID=1000
ARG USER_GID=1000
RUN userdel -r node 2>/dev/null; \
    groupdel node 2>/dev/null; \
    groupadd -g $USER_GID claude && \
    useradd -m -s /bin/bash -u $USER_UID -g $USER_GID claude

USER claude
WORKDIR /workspace

CMD ["bash"]