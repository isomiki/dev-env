FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages + Node.js 22
RUN apt update && apt install -y --no-install-recommends \
    git curl python3 python3-pip openssh-server tmux zsh sudo less neovim jq htop \
    ca-certificates gnupg build-essential libssl-dev pkg-config libsasl2-2 libnss3 ranger eza \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y gh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up SSH
RUN mkdir -p /etc/ssh /root/.ssh \
    && chmod 700 /root /root/.ssh \
    && sed -i 's/^[#[:space:]]*PermitRootLogin.*$/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -i 's/^[#[:space:]]*PasswordAuthentication.*$/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^[#[:space:]]*AllowTcpForwarding.*$/AllowTcpForwarding yes/' /etc/ssh/sshd_config \
    && sed -i 's/^[#[:space:]]*PubkeyAuthentication.*$/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^[#[:space:]]*X11Forwarding.*$/X11Forwarding no/' /etc/ssh/sshd_config

# Install AI agents
RUN npm install -g @anthropic-ai/claude-code opencode-ai @openai/codex openclaw @devcontainers/cli

# Start
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
