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

# Create non-root user (Claude Code prefers this)
RUN useradd -m -s /bin/bash claude
USER claude
WORKDIR /workspace

# Default: interactive bash (user starts claude manually)
CMD ["bash"]
