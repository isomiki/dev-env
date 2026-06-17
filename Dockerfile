FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages + Node.js 22
RUN apt update && apt install -y --no-install-recommends \
    git curl python3 python3-pip openssh-server tmux zsh sudo less neovim jq htop \
    ca-certificates gnupg build-essential libssl-dev pkg-config libsasl2-2 libnss3 ranger eza \
    zlib1g-dev libyaml-dev libffi-dev libreadline-dev libgdbm-dev \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set default shell to zsh
RUN chsh -s $(which zsh) root

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

# Enable pnpm via corepack (bundled with Node 22)
RUN corepack enable && corepack prepare pnpm@latest --activate

# Install Docker engine (docker-in-docker; requires privileged container)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install rbenv + ruby-build (Ruby version manager)
ENV RBENV_ROOT=/usr/local/rbenv
RUN git clone --depth 1 https://github.com/rbenv/rbenv.git "$RBENV_ROOT" \
    && git clone --depth 1 https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build" \
    && printf 'export RBENV_ROOT=%s\nexport PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"\neval "$(rbenv init -)"\n' "$RBENV_ROOT" \
        > /etc/profile.d/rbenv.sh

# Bake in Ruby versions (4.0.5 as default; 3.4.3 for legacy projects via .ruby-version)
ENV PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
RUN rbenv install 4.0.5 \
    && rbenv install 3.4.3 \
    && rbenv global 4.0.5

# Start
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
