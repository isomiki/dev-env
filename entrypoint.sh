#!/bin/bash
set -e

# Update package lists
apt-get update -qq

# Bootstrap SSH directory if volume is fresh
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Inject pubkey on first run
if [ -n "$DEFAULT_SSH_PUBLIC_KEY" ]; then
    grep -qxF "$DEFAULT_SSH_PUBLIC_KEY" /root/.ssh/authorized_keys 2>/dev/null \
        || echo "$DEFAULT_SSH_PUBLIC_KEY" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi

# Persist host keys in volume
if [ ! -f /root/.ssh/ssh_host_ed25519_key ]; then
    ssh-keygen -t ed25519 -f /root/.ssh/ssh_host_ed25519_key -N ""
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/ssh_host_rsa_key -N ""
fi

# Start the Docker daemon in the background (docker-in-docker)
dockerd > /var/log/dockerd.log 2>&1 &

# Expose the registry password to interactive SSH shells so you can `docker login`
# yourself. sshd doesn't inherit the container env, so write it to a profile snippet
# (sourced by both bash and zsh login shells via /etc/profile).
if [ -n "$DOCKER_REGISTRY_TOKEN" ]; then
    printf 'export DOCKER_REGISTRY_TOKEN=%q\n' "$DOCKER_REGISTRY_TOKEN" > /etc/profile.d/docker-creds.sh
    chmod 600 /etc/profile.d/docker-creds.sh
fi

# Install agent CLIs into /root (the persistent home volume) if missing. Runs in
# the background so SSH comes up immediately; a near-instant no-op once installed.
# Each is independent and non-fatal — comment one out to drop that agent. Logs to
# /var/log/agent-install.log.
(
    set +e
    [ -x /root/.local/bin/claude ]      || curl -fsSL https://claude.ai/install.sh | bash -s -- 2.1.179
    [ -x /root/.opencode/bin/opencode ] || curl -fsSL https://opencode.ai/install | bash -s -- --version 1.17.7
    [ -x /root/.local/bin/codex ]       || curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh -s -- --release 0.140.0
    [ -x /root/.openclaw/bin/openclaw ] || curl -fsSL https://openclaw.ai/install-cli.sh | bash -s -- --version 2026.6.8 --prefix /root/.openclaw
) > /var/log/agent-install.log 2>&1 &

exec /usr/sbin/sshd -D \
    -o HostKey=/root/.ssh/ssh_host_ed25519_key \
    -o HostKey=/root/.ssh/ssh_host_rsa_key
