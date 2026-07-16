# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A local/dev LiteLLM gateway plus a bundle of relocatable Claude Code launchers. Despite `pyproject.toml`, the real artifacts are shell scripts and YAML — there is no application code to build. The proxy exposes a stable endpoint on `localhost:4000` that routes Claude Code requests to upstream OpenAI/Gemini models, and the `claude/` launchers point Claude Code at either that proxy or (for Kimi/Z.ai) directly at a provider.

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
bash -n claude/*.sh
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

### Launcher bundle (`claude/`)

Relocatable — copied into a target repo as `.claude/litellm-launchers/`, not run from this repo. Launchers resolve sibling scripts from their own dir but keep the **target** repo as the working directory, so `.mcp.json` and `CLAUDE_PROJECT_DIR` stay scoped to the repo Claude Code operates in. Every launcher requires a `.mcp.json` in the current directory.

- `start-tmux.sh <session>` → lays out a tmux workspace and runs `select-claude-model.sh`.
- `select-claude-model.sh` → two-stage menu: model family, then `CLAUDE_PROFILE` (fast/default/deep). Exports `CLAUDE_PROFILE` and execs the chosen launcher.
- **LiteLLM-routed** launchers (`start-claude-gpt-5-6.sh`, `-gpt-5-4.sh`, `-gemini.sh`) set `ANTHROPIC_BASE_URL=http://localhost:4000`, a hardcoded virtual key, and `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL`. They require the proxy up on `:4000` (checked via `nc`).
- **Direct** launchers (`start-claude-kimi.sh`, `-glm-5-2.sh`, `-glm-4-7.sh`) bypass the proxy: they `unset ANTHROPIC_API_KEY`, set `ANTHROPIC_AUTH_TOKEN` from `KIMI_CODING_API_KEY`/`ZAI_CODING_API_KEY` (sourced from the target repo's `.env.local`), and point at the provider's Anthropic-compatible endpoint. These are **not** LiteLLM-metered.

`CLAUDE_PROFILE` (fast/default/deep) maps to `MAX_THINKING_TOKENS`, output-token cap, and effort level inside each launcher.

## Constraints and gotchas

- **Docker vs local pool settings.** Compose hardcodes the internal `LITELLM_DATABASE_URL`, `REDIS_HOST`, and a 10-connection pool, overriding local-mode vars. Do **not** set `LITELLM_DATABASE_URL`/`REDIS_HOST`/`REDIS_PORT` in a Compose `.env`. Local mode defaults `LITELLM_DATABASE_CONNECTION_POOL_LIMIT` to `1` (conservative for external/Supabase Postgres with small connection caps).
- **`--num_workers 1` is intentional** — paired with pool limit 1 and `?connection_limit=1` to survive a shared/free-tier Postgres connection cap.
- **`LITELLM_SALT_KEY` must not rotate** once LiteLLM has stored encrypted credentials.
- The pinned LiteLLM image tag lives in `docker-compose.yml` (`image:`); updating LiteLLM under Docker means bumping that tag, not `pyproject.toml`.
- Compose deliberately does not publish Postgres/Redis ports to the host.
- Three env templates, chosen by mode: `.env.docker.example`, `.env.local.example`, `.env.example` (pointer). Real `.env*` files are gitignored except the three examples.
- GLM was removed from LiteLLM config/keys/templates; Z.ai GLM is now direct-only via the `claude/` launchers.
