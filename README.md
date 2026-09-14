# Remote dev sandbox

Debian container with SSH + the usual dev tooling (git, node 24 via fnm, pnpm, bun, python, ruby via rbenv, nvim, tmux, zsh, eza, ranger) and AI agents (claude-code, codex, grok, opencode, omp, openclaw) preinstalled. Docker-in-Docker enabled.

Also includes [Orca](https://github.com/stablyai/orca) (v1.4.197, headless server + CLI) and [Herdr](https://herdr.dev/docs/install/) (terminal agent multiplexer). Orca is baked into the image and its headless server auto-starts with the container; Herdr installs on first boot into the persistent home volume alongside the agent CLIs. Installation output is in `/var/log/agent-install.log`.

## Run

```bash
docker compose up -d
```

SSH in:

```bash
ssh root@<host>
```

Run `herdr` to open its terminal workspace.

Orca's headless server starts automatically with the container and logs to `/var/log/orca-serve.log`. Its settings and sessions live in the persistent `/root` volume. **The pairing URL is minted fresh on every start**, so don't save it — read the current one out of the log:

```bash
grep -i pairing /var/log/orca-serve.log
```

To run it by hand instead, set `ORCA_AUTOSTART=0` and start it yourself (in tmux or Herdr, since it runs in the foreground):

```bash
ELECTRON_DISABLE_SANDBOX=1 LIBGL_ALWAYS_SOFTWARE=1 orca serve --port 6768 --pairing-address localhost
```

Three things about that command, each of which is easy to get wrong:

- **`ELECTRON_DISABLE_SANDBOX=1`, not `ORCA_APPIMAGE_NO_SANDBOX=1`.** Orca is installed here as a system package (`/usr/local/bin/orca` → `/usr/bin/orca-ide` → `/opt/Orca/...`), not as an AppImage, so `ORCA_APPIMAGE_NO_SANDBOX` is never read — it is consumed only by the AppImage wrapper. Without the Electron override, Chromium refuses to run as root (`Running as root without --no-sandbox is not supported`) and dies on SIGTRAP.
- **Leave `DISPLAY` unset.** Orca starts and verifies its own Xvfb, and rejects one you hand it (`DISPLAY=:99 is not verifiably live; leaving it untouched. Unset DISPLAY to let Orca start its own Xvfb.`). `xvfb-run` doesn't work either — `xauth` isn't installed.
- **The startup noise is harmless.** Expect D-Bus connection errors, `The OS keyring is unavailable, so secrets are stored unencrypted`, and even `FATAL:...gpu_data_manager_impl_private.cc:416] GPU process isn't usable. Goodbye.` That last one reads like a crash but is only the GPU *child* process dying; the server itself stays up and serves. Check `runtime: ready` in the log, or just hit the port.

See the [headless Linux guide](https://github.com/stablyai/orca/blob/main/docs/reference/headless-linux-server.md) for other connection options.

Two ways to reach it from your laptop:

- **SSH tunnel (default, works out of the box):** forward its port with `ssh -L 6768:localhost:6768 root@<host>`, then use the pairing link printed by Orca. This works because Orca's port is published on host loopback by default.
- **Direct via Tailscale (no tunnel to keep open):** set `ORCA_BIND` to the host's Tailscale IP (see below) so the port is published on the tailnet instead of loopback, then use the pairing link directly against that address.

## Setup

- Not on Coolify? The service references named volumes `home→/root` and `docker-data→/var/lib/docker` but there's no top-level `volumes:` block (Coolify provisions them). Add one yourself, or `/root` (host keys, `authorized_keys`) and your Docker images won't persist.
- Runtime env vars (set them in Coolify, or however you run the container):
  - `DEFAULT_SSH_PUBLIC_KEY` (required in practice) — your pubkey, injected into `authorized_keys`. Not compose-enforced, but without it nothing can log in.
  - `SSH_PORT` (optional, default `2222`) — host port mapped to container `22`. Set it to your chosen port; the default is only a parse-time fallback.
  - `DOCKER_REGISTRY_TOKEN` (optional) — for a private registry; exposed in your login shell so you can log in manually, e.g. `echo "$DOCKER_REGISTRY_TOKEN" | docker login ghcr.io -u <user> --password-stdin`.
  - `APP_PORT` (optional) — host port mapped to your app's container `3000`.
  - `ORCA_BIND` (optional, default `127.0.0.1`) — bind address for Orca's port. The default publishes on host loopback only, reachable via the `ssh -L` tunnel above. Set it to the host's Tailscale IP to publish on the tailnet instead, for a direct connection without a tunnel. Never set it to `0.0.0.0` — that exposes the Orca pairing endpoint (device token + E2EE material) on the public interface.
  - `ORCA_PORT` (optional, default `6768`) — host port mapped to Orca's container `6768`. It is a compose-level mapping only and is not passed into the container, so the server inside always listens on `6768`.
  - `ORCA_AUTOSTART` (optional, default `1`) — set to `0` to stop the entrypoint from starting `orca serve`, e.g. to run it by hand while debugging. Any other value (or unset) starts it.
  - `ORCA_PAIRING_ADDRESS` (optional, default `localhost`) — the `--pairing-address` the auto-started server advertises. `localhost` is right for the `ssh -L` tunnel; set it to the host's Tailscale IP or hostname if you reach Orca directly over the tailnet.
  - `MEM_LIMIT` / `MEMSWAP_LIMIT` (optional) — container memory cap; keep them equal to disable container swap (clean OOM instead of host thrash). `MEMSWAP_LIMIT` must be ≥ `MEM_LIMIT`. Size below host RAM, leaving headroom for the host and other services.
  - `CPUS` (optional) — vCPU cap for the container; leave headroom so the host stays responsive under load.

## Notes

- Your pubkey is injected on every boot (appended if missing). `/root` is a volume, so host keys + `authorized_keys` persist across restarts.
- Docker-in-Docker: the container runs `privileged`, `dockerd` starts before sshd, and images/containers persist in `docker-data`.
- Ruby: rbenv with 4.0.5 (default) + 3.4.3 baked in; projects auto-select via `.ruby-version`.
- Hostname is `dev`; password auth is off; root login is key-only.
