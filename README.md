# Remote dev sandbox

Debian container with SSH + the usual dev tooling (git, node 22, python, nvim, tmux) and AI agents (claude-code, codex, opencode, openclaw) preinstalled.

## Run

```bash
DEFAULT_SSH_PUBLIC_KEY="ssh-ed25519 AAAA... your key" docker compose up -d
```

SSH in:

```bash
ssh -p 60001 root@<host>
```

## Notes

- Your pubkey is injected on first boot only. `/root` is a volume, so host keys + `authorized_keys` persist across restarts.
- Built for Coolify, which provisions the `home` volume for you. Not on Coolify? Add a `volumes:` block to `compose.yaml` yourself, else `/root` won't persist.
- Ports: `60001→22` (ssh), `3001→3000` (your app). Tweak in `compose.yaml`.
- Password auth is off; root login is key-only.
- Image: `ghcr.io/isomiki/dev-env:latest`. Rebuild from the `Dockerfile` if you want to bake in more.
