FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt update && apt install -y --no-install-recommends \
    git curl python3 python3-pip openssh-server tmux zsh sudo less neovim jq htop \
    ca-certificates gnupg build-essential libssl-dev pkg-config libsasl2-2 libnss3 ranger eza unzip \
    zlib1g-dev libyaml-dev libffi-dev libreadline-dev libgdbm-dev \
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

# Install fnm + Node 24 (default; per-project switching via .node-version/.nvmrc)
ENV FNM_DIR=/usr/local/fnm
ENV PATH="$FNM_DIR:$FNM_DIR/aliases/default/bin:$PATH"
RUN curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell \
    && fnm install 24 \
    && fnm default 24 \
    && printf 'export FNM_DIR=%s\nexport PATH="$FNM_DIR:$FNM_DIR/aliases/default/bin:$PATH"\n' "$FNM_DIR" \
        > /etc/profile.d/fnm.sh

# Agent CLIs (claude, opencode, codex, openclaw) are installed at runtime by
# entrypoint.sh, because they live in /root — the home volume — and self-heal on
# any volume (fresh or existing). Here we only put their bin dirs on PATH for SSH
# login shells (sshd doesn't inherit the Docker ENV); harmless before they exist.
RUN printf 'export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.openclaw/bin:$PATH"\n' \
        > /etc/profile.d/agents.sh

# profile.d is only sourced by *login* shells; tmux (and other) interactive shells
# are non-login, so load it for them too. Also run fnm's cd-hook here in the native
# shell — it can't go in profile.d, which zsh sources under sh-emulation (breaks the
# zsh-flavored `fnm env` output, esp. with extendedglob). Runs before ~/.zshrc.
RUN printf '\nfor f in /etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done\ncommand -v fnm >/dev/null && eval "$(fnm env --use-on-cd)"\n' \
    | tee -a /etc/zsh/zshrc >> /etc/bash.bashrc

# devcontainers CLI (no standalone installer; stays an npm global on the default Node)
RUN npm install -g @devcontainers/cli

# Enable pnpm via corepack (bundled with Node 24)
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

# Install Bun (standalone runtime/pkg-manager; independent of fnm/Node/pnpm).
# Placed late so adding/bumping it doesn't invalidate the Ruby-compile cache.
ENV BUN_INSTALL=/usr/local/bun
ENV PATH="$BUN_INSTALL/bin:$PATH"
RUN curl -fsSL https://bun.sh/install | bash -s "bun-v1.3.14" \
    && printf 'export BUN_INSTALL=%s\nexport PATH="$BUN_INSTALL/bin:$PATH"\n' "$BUN_INSTALL" \
        > /etc/profile.d/bun.sh

# Start
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
