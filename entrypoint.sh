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

# Start cron (daemonizes itself). The container runs neither syslog nor an MTA, so
# cron's own logging and any job output are both discarded — redirect explicitly in
# the crontab line, e.g. `* * * * * /path/job >> /var/log/job.log 2>&1`.
cron

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
    [ -x /root/.local/bin/codex ]       || curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh -s -- --release 0.140.0
    [ -x /root/.grok/bin/grok ]         || curl -fsSL https://x.ai/cli/install.sh | bash -s -- 1.0.5
    [ -x /root/.opencode/bin/opencode ] || curl -fsSL https://opencode.ai/install | bash -s -- --version 1.17.7
    [ -x /root/.local/bin/omp ]         || curl -fsSL https://omp.sh/install | sh -s -- --binary
    [ -x /root/.openclaw/bin/openclaw ] || curl -fsSL https://openclaw.ai/install-cli.sh | bash -s -- --version 2026.6.8 --prefix /root/.openclaw
    [ -x /root/.local/bin/herdr ]       || curl -fsSL https://herdr.dev/install.sh | HERDR_INSTALL_DIR=/root/.local/bin sh
) > /var/log/agent-install.log 2>&1 &

# Start Orca's headless runtime in the background, logging to /var/log/orca-serve.log.
# Backgrounded because `orca serve` never returns, and wrapped in a `set +e` subshell
# so no failure here — missing binary, crash on startup — can trip this script's
# `set -e` and leave the container without sshd. ELECTRON_DISABLE_SANDBOX is what
# makes it work as root: this is a system (.deb) install, not an AppImage, so the
# AppImage-only ORCA_APPIMAGE_NO_SANDBOX is never read and Electron otherwise refuses
# to run as root. DISPLAY is left unset on purpose — Orca starts and verifies its own
# Xvfb, and rejects one it is handed. Set ORCA_AUTOSTART=0 to run it by hand instead.
if [ "${ORCA_AUTOSTART:-1}" != "0" ]; then
    (
        set +e
        command -v orca > /dev/null 2>&1 || exit 0
        unset DISPLAY
        ELECTRON_DISABLE_SANDBOX=1 LIBGL_ALWAYS_SOFTWARE=1 \
            orca serve \
                --port "${ORCA_PORT:-6768}" \
                --pairing-address "${ORCA_PAIRING_ADDRESS:-localhost}"
    ) > /var/log/orca-serve.log 2>&1 &
fi

exec /usr/sbin/sshd -D \
    -o HostKey=/root/.ssh/ssh_host_ed25519_key \
    -o HostKey=/root/.ssh/ssh_host_rsa_key
