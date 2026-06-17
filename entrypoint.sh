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

exec /usr/sbin/sshd -D \
    -o HostKey=/root/.ssh/ssh_host_ed25519_key \
    -o HostKey=/root/.ssh/ssh_host_rsa_key
