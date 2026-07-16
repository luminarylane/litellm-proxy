# litellm-proxy

A small, team-usable LiteLLM gateway setup for local Claude Code workflows.

This repo packages a local LiteLLM proxy with:

- env-driven model routing in `config.yaml`
- bootstrap and run scripts for a fresh clone
- reusable virtual-key registration for downstream clients
- a Docker Compose stack that bundles LiteLLM, Postgres, and Redis

## What this repo is for

Use this repo when you want a single local LiteLLM proxy that:

- exposes a stable endpoint on `localhost:4000`
- routes Claude Code requests to named upstream models
- registers reusable virtual keys for different client profiles
- gives teammates a reproducible setup without relying on one person's `~/Developer/...` layout

## What this repo is not

This is **local/dev infrastructure**, not stage/prod runtime infrastructure.

It assumes:

- you are running on your own machine or an organization-managed Docker host
- you can provide your own provider API keys
- Docker Compose for the self-contained default, or local Redis/Postgres for the legacy host-run scripts
- network access only to the model providers you configure

## Files you should care about

- `config.yaml` — canonical LiteLLM routing/config
- `.env.docker.example` — Docker Compose environment and dedicated-Postgres pool settings
- `.env.local.example` — host-run environment and conservative external-Postgres pool settings
- `.env.example` — pointer to the mode-specific templates
- `run.sh` — root dispatcher: select Docker Compose or local host mode
- `docker-compose.yml` — self-contained stack using LiteLLM's official proxy image, Postgres, and Redis
- `register-keys.sh` — shared virtual-key registration used by Compose and `local/`
- `local/` — host-managed runtime scripts (`setup.sh`, `run.sh`, and `update.sh`)

> The Claude Code / Codex **launcher bundles** (formerly `claude/` and `codex/`) have moved to their own repo — **[luminarylane/code-gen-optim](https://github.com/luminarylane/code-gen-optim)** — and no longer depend on this proxy.

## Prerequisites

For the recommended self-contained setup, install [Docker Desktop](https://www.docker.com/products/docker-desktop/), Docker Engine with the Compose plugin, or [Colima](https://github.com/abiosoft/colima) on macOS if you prefer a lighter Docker-compatible runtime than Docker Desktop.

The legacy host-run scripts additionally require [uv](https://docs.astral.sh/uv/getting-started/installation/), Redis on `localhost:6379`, and Postgres reachable from `LITELLM_DATABASE_URL`.

## Quick start: self-contained Docker Compose stack

### 1. Clone the repo

```bash
git clone https://github.com/luminarylane/litellm-proxy.git
cd litellm-proxy
```

### 2. Create your Docker Compose `.env`

```bash
cp .env.docker.example .env
```

Set at least:

- `OPENAI_API_KEY` and/or `GEMINI_API_KEY` (the configured provider credentials)
- `LITELLM_MASTER_KEY` (strong administrator secret)
- `LITELLM_SALT_KEY` (strong stable secret; do not rotate after LiteLLM stores credentials)
- `POSTGRES_PASSWORD` (strong password for the bundled Postgres database)
- `LITELLM_OPENAI_VIRTUAL_KEY`, `LITELLM_OPENAI_5_6_VIRTUAL_KEY`, `LITELLM_GEMINI_VIRTUAL_KEY`

`docker-compose.yml` supplies the internal Postgres connection string and Redis hostname. It explicitly uses a 10-connection LiteLLM database pool with 10 overflow connections for the bundled dedicated Postgres service, overriding any local-mode pool variables; do not set `LITELLM_DATABASE_URL`, `REDIS_HOST`, or `REDIS_PORT` for Compose. The Compose file deliberately does not publish Postgres or Redis ports to the host.

### 3. Start the stack

```bash
# Prompts for Docker Compose or local mode. Choose Docker Compose.
./run.sh

# Deterministic equivalent for documentation, teams, and automation.
./run.sh docker
docker compose ps
docker compose logs -f litellm
```

The `litellm` container uses LiteLLM's official `docker.litellm.ai/berriai/litellm:v1.92.0` image, waits for healthy Postgres and Redis, and starts the proxy on `http://localhost:4000`. The one-shot `register-keys` service registers Claude Code virtual-key aliases once LiteLLM is healthy. Postgres and Redis data persist in named Docker volumes across restarts.

### 4. Stop, update, or reset the stack

```bash
# Stop containers without deleting data.
docker compose down

# Rebuild and restart after config, dependency, or image changes.
docker compose up --build -d

# Destructive: delete all LiteLLM database and Redis data.
docker compose down -v
```

## Local host-run setup

If your organization already manages Redis and Postgres outside Docker, create `.env` from the local template, set `LITELLM_DATABASE_URL`, and use the local host-run flow:

```bash
cp .env.local.example .env
./local/setup.sh

# Later starts:
./run.sh local
# Equivalent direct command:
./local/run.sh
```

`./local/update.sh` updates the host-managed Python dependencies and refreshes the virtual-key aliases. Local mode defaults `LITELLM_DATABASE_CONNECTION_POOL_LIMIT` to `1`, preserving the conservative setting for constrained external Postgres services. Docker Compose users update LiteLLM by changing the pinned official image tag in `docker-compose.yml`, then running `./run.sh docker`.

> **Supabase Postgres note:** A Supabase free-tier database works for `LITELLM_DATABASE_URL`, but it enforces a small connection cap (commonly 15 in session mode). If you share one database across local proxies, keep each proxy small: this repo defaults to `--num_workers 1`, `database_connection_pool_limit: 1`, and `?connection_limit=1` on the URL.

## Default local ports

- LiteLLM proxy: `4000`
- Redis: `6379`

## LiteLLM proxy UI

LiteLLM exposes a built-in admin UI at:

```
http://localhost:4000/ui
```

Log in with `LITELLM_MASTER_KEY` as the password (default username is `admin`).

You can override the UI credentials by setting `UI_USERNAME` and `UI_PASSWORD` in your `.env` before starting the proxy.

> This password is only for the `/ui` admin interface. Claude Code requests still authenticate with the virtual keys (`LITELLM_OPENAI_VIRTUAL_KEY`, `LITELLM_OPENAI_5_6_VIRTUAL_KEY`, `LITELLM_GEMINI_VIRTUAL_KEY`).

From there you can inspect registered virtual keys, track spend, view request logs, and manage model routing without touching `config.yaml` directly.

## Virtual-key profiles

The setup script registers three virtual keys:

- `LITELLM_OPENAI_5_6_VIRTUAL_KEY`
- `LITELLM_OPENAI_VIRTUAL_KEY`
- `LITELLM_GEMINI_VIRTUAL_KEY`

Those map Claude Code model aliases to the configured upstream models in `config.yaml`.

### OpenAI GPT 5.6 profile

- `claude-opus-4-7` → `openai/gpt-5.6-sol`
- `claude-sonnet-4-6` → `openai/gpt-5.6-terra`
- `claude-haiku-4-6` → `openai/gpt-5.6-luna`

### OpenAI GPT 5.4 profile

- `claude-opus-4-7` → `openai/gpt-5.5`
- `claude-sonnet-4-6` → `openai/gpt-5.4`
- `claude-haiku-4-6` → `openai/gpt-5.4-mini`

### Gemini profile

- `claude-opus-4-7` → `gemini/gemini-3.1-pro-preview`
- `claude-sonnet-4-6` → `gemini/gemini-3.1-pro-preview`
- `claude-haiku-4-6` → `gemini/gemini-3.5-flash`

## Validation

Basic shell validation for the shipped scripts:

```bash
bash -n run.sh
bash -n local/*.sh
sh -n register-keys.sh
docker compose config --quiet
```

## Open-source boundary

This repo intentionally does **not** include:

- real `.env` files
- provider API keys
- personal machine paths
- local virtualenv state
- local logs
- non-LiteLLM launcher experiments with embedded secrets

## License

MIT
