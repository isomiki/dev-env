# Remote dev sandbox

Debian container with SSH + the usual dev tooling (git, node 22, pnpm, python, ruby via rbenv, nvim, tmux, zsh, eza, ranger) and AI agents (claude-code, codex, opencode, openclaw) preinstalled. Docker-in-Docker enabled.

## Run

```bash
docker compose up -d
```

SSH in:

```bash
ssh -p 60001 root@<host>
```

## Setup

- Not on Coolify? The service references named volumes `home→/root` and `docker-data→/var/lib/docker` but there's no top-level `volumes:` block (Coolify provisions them). Add one yourself, or `/root` (host keys, `authorized_keys`) and your Docker images won't persist.
- Runtime env vars (set them in Coolify, or however you run the container):
  - `DEFAULT_SSH_PUBLIC_KEY` (required) — your pubkey, injected into `authorized_keys`.
  - `DOCKER_REGISTRY_TOKEN` (optional) — for a private registry; exposed in your login shell so you can log in manually, e.g. `echo "$DOCKER_REGISTRY_TOKEN" | docker login ghcr.io -u <user> --password-stdin`.
- Ports default to `60001→22` (ssh) and `3001→3000` (your app); change in `compose.yaml` if they clash.

## Notes

- Your pubkey is injected on every boot (appended if missing). `/root` is a volume, so host keys + `authorized_keys` persist across restarts.
- Docker-in-Docker: the container runs `privileged`, `dockerd` starts before sshd, and images/containers persist in `docker-data`.
- Ruby: rbenv with 4.0.5 (default) + 3.4.3 baked in; projects auto-select via `.ruby-version`.
- Hostname is `dev`; password auth is off; root login is key-only.
