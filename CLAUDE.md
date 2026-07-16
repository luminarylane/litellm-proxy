# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A local/dev LiteLLM gateway. Despite `pyproject.toml`, the real artifacts are shell scripts and YAML — there is no application code to build. The proxy exposes a stable endpoint on `localhost:4000` that routes Anthropic-API (Claude Code) requests to upstream OpenAI/Gemini models. The relocatable Claude Code / Codex launcher bundles that used to live here now have their own repo: [luminarylane/code-gen-optim](https://github.com/luminarylane/code-gen-optim).

This is local/dev infrastructure only, not stage/prod runtime.

## Commands

Two deployment modes, dispatched by the root `run.sh`:

```bash
./run.sh docker   # self-contained Compose stack: LiteLLM + Postgres + Redis (default)
./run.sh local    # host runtime via uv; needs external Redis (6379) + Postgres
./run.sh          # interactive mode picker
```

Docker lifecycle:

```bash
docker compose ps
docker compose logs -f litellm
docker compose up --build -d      # rebuild after config/image change
docker compose down               # stop, keep data
docker compose down -v            # DESTRUCTIVE: wipe Postgres + Redis volumes
```

Local host mode:

```bash
./local/setup.sh    # bootstrap: uv sync, prisma generate, start proxy, register keys
./local/run.sh      # start proxy (expects setup already run)
./local/update.sh   # uv lock --upgrade + uv sync, then re-register keys
```

Validation (there are no unit tests — this is the full check suite):

```bash
bash -n run.sh
bash -n local/*.sh
sh -n register-keys.sh
docker compose config --quiet
```

## Architecture

### Model routing is defined in three places that must stay in sync

1. `config.yaml` `model_list` — declares each upstream model and its `os.environ/` API-key reference.
2. `register-keys.sh` — maps Claude Code's built-in aliases (`claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-6`) to those upstream models, one mapping set per virtual key.
3. README profile tables — human-facing documentation of the same mappings.

Adding or renaming a route means editing `config.yaml` **and** `register-keys.sh` **and** the README together. `register-keys.sh` is the linchpin: it POSTs `key/generate` with an `aliases` object so a single virtual key silently rewrites Claude's alias to the chosen upstream model.

### `register-keys.sh` is shared by both deploy modes

- Docker: runs as the one-shot `register-keys` Compose service (`curlimages/curl`) once `litellm` is healthy.
- Local: invoked by `local/setup.sh` and `local/update.sh` after the proxy passes its healthcheck.

It waits for `/health`, then registers three virtual keys. Any change to alias mappings takes effect on both modes with no other edits.

## Constraints and gotchas

- **Docker vs local pool settings.** Compose hardcodes the internal `LITELLM_DATABASE_URL`, `REDIS_HOST`, and a 10-connection pool, overriding local-mode vars. Do **not** set `LITELLM_DATABASE_URL`/`REDIS_HOST`/`REDIS_PORT` in a Compose `.env`. Local mode defaults `LITELLM_DATABASE_CONNECTION_POOL_LIMIT` to `1` (conservative for external/Supabase Postgres with small connection caps).
- **`--num_workers 1` is intentional** — paired with pool limit 1 and `?connection_limit=1` to survive a shared/free-tier Postgres connection cap.
- **`LITELLM_SALT_KEY` must not rotate** once LiteLLM has stored encrypted credentials.
- The pinned LiteLLM image tag lives in `docker-compose.yml` (`image:`); updating LiteLLM under Docker means bumping that tag, not `pyproject.toml`.
- Compose deliberately does not publish Postgres/Redis ports to the host.
- Three env templates, chosen by mode: `.env.docker.example`, `.env.local.example`, `.env.example` (pointer). Real `.env*` files are gitignored except the three examples.
- GLM was removed from LiteLLM config/keys/templates.
