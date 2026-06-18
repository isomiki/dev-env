# Remote dev sandbox

Debian container with SSH + the usual dev tooling (git, node 24 via fnm, pnpm, bun, python, ruby via rbenv, nvim, tmux, zsh, eza, ranger) and AI agents (claude-code, codex, opencode, openclaw) preinstalled. Docker-in-Docker enabled.

## Run

```bash
docker compose up -d
```

SSH in:

```bash
ssh root@<host>
```

## Setup

- Not on Coolify? The service references named volumes `home→/root` and `docker-data→/var/lib/docker` but there's no top-level `volumes:` block (Coolify provisions them). Add one yourself, or `/root` (host keys, `authorized_keys`) and your Docker images won't persist.
- Runtime env vars (set them in Coolify, or however you run the container):
  - `DEFAULT_SSH_PUBLIC_KEY` (required in practice) — your pubkey, injected into `authorized_keys`. Not compose-enforced, but without it nothing can log in.
  - `SSH_PORT` (optional, default `2222`) — host port mapped to container `22`. Set it to your chosen port; the default is only a parse-time fallback.
  - `DOCKER_REGISTRY_TOKEN` (optional) — for a private registry; exposed in your login shell so you can log in manually, e.g. `echo "$DOCKER_REGISTRY_TOKEN" | docker login ghcr.io -u <user> --password-stdin`.
  - `APP_PORT` (optional) — host port mapped to your app's container `3000`.
  - `MEM_LIMIT` / `MEMSWAP_LIMIT` (optional) — container memory cap; keep them equal to disable container swap (clean OOM instead of host thrash). `MEMSWAP_LIMIT` must be ≥ `MEM_LIMIT`. Size below host RAM, leaving headroom for the host and other services.
  - `CPUS` (optional) — vCPU cap for the container; leave headroom so the host stays responsive under load.

## Notes

- Your pubkey is injected on every boot (appended if missing). `/root` is a volume, so host keys + `authorized_keys` persist across restarts.
- Docker-in-Docker: the container runs `privileged`, `dockerd` starts before sshd, and images/containers persist in `docker-data`.
- Ruby: rbenv with 4.0.5 (default) + 3.4.3 baked in; projects auto-select via `.ruby-version`.
- Hostname is `dev`; password auth is off; root login is key-only.
