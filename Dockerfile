FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages + Node.js 22
RUN apt update && apt install -y --no-install-recommends \
    git curl python3 python3-pip openssh-server tmux sudo less neovim jq htop \
    ca-certificates gnupg build-essential libssl-dev pkg-config libsasl2-2 libnss3 ranger \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up SSH
RUN mkdir -p /etc/ssh /root/.ssh \
    && ssh-keygen -A \
    && chmod 700 /root /root/.ssh \
    && sed -i 's/^[#[:space:]]*PermitRootLogin.*$/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -i 's/^[#[:space:]]*PasswordAuthentication.*$/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^[#[:space:]]*AllowTcpForwarding.*$/AllowTcpForwarding yes/' /etc/ssh/sshd_config \
    && sed -i 's/^[#[:space:]]*PubkeyAuthentication.*$/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^[#[:space:]]*X11Forwarding.*$/X11Forwarding no/' /etc/ssh/sshd_config \
    && touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys

# Install AI agents
RUN npm install -g @anthropic-ai/claude-code opencode-ai @openai/codex openclaw @devcontainers/cli

# Create ai wrapper
# RUN printf '%s\n' '#!/bin/bash' \
#     'case "$1" in' \
#     '    claude) tmux new -s claude 2>/dev/null || tmux attach -t claude; claude-code ;;' \
#     '    opencode) tmux new -s opencode 2>/dev/null || tmux attach -t opencode; opencode-ai ;;' \
#     '    codex) tmux new -s codex 2>/dev/null || tmux attach -t codex; codex ;;' \
#     '    openclaw) tmux new -s openclaw 2>/dev/null || tmux attach -t openclaw; openclaw ;;' \
#     '    *) echo "Available: claude, opencode, codex, openclaw"; exit 1 ;;' \
#     'esac' > /root/ai \
#     && chmod +x /root/ai

# Start
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
