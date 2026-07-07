# litellm-proxy

A small, team-usable LiteLLM gateway setup for local Claude Code workflows.

This repo packages a local LiteLLM proxy with:

- env-driven model routing in `config.yaml`
- bootstrap and run scripts for a fresh clone
- reusable virtual-key registration for Claude Code launchers
- tmux launchers for OpenAI/Codex-style and Gemini-backed Claude Code sessions

## What this repo is for

Use this repo when you want a single local LiteLLM proxy that:

- exposes a stable endpoint on `localhost:4000`
- routes Claude Code requests to named upstream models
- registers reusable virtual keys for different launcher profiles
- gives teammates a reproducible setup without relying on one person's `~/Developer/...` layout

## What this repo is not

This is **local/dev infrastructure**, not stage/prod runtime infrastructure.

It assumes:

- you are running on your own machine
- you can provide your own provider API keys
- Redis is available locally on port `6379`
- a Postgres database is available for `LITELLM_DATABASE_URL` (a free-tier Supabase Postgres works; see note below)

## Files you should care about

- `config.yaml` — canonical LiteLLM routing/config
- `.env.example` — required environment variables
- `setup.sh` — bootstrap dependencies, launch the proxy, register virtual keys
- `run.sh` — start the proxy after setup
- `start-litellm-codex.sh` — launch Claude Code against the OpenAI/Codex virtual key
- `start-litellm-gemini.sh` — launch Claude Code against the Gemini virtual key
- `start-litellm-codex-in-tmux.sh` — launch Claude Code + lazygit in a tmux session (OpenAI/Codex)
- `start-litellm-gemini-in-tmux.sh` — launch Claude Code + lazygit in a tmux session (Gemini)

## Prerequisites

Install these locally first:

- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- Redis on `localhost:6379`
- Postgres reachable from your `LITELLM_DATABASE_URL`
- `tmux`
- `claude`
- `lazygit`
- `curl`
- `nc` (netcat)

## Quick start

### 1. Clone the repo

```bash
git clone https://github.com/luminarylane/litellm-proxy.git
cd litellm-proxy
```

### 2. Create your local `.env`

```bash
cp .env.example .env
```

Fill in the values:

- `OPENAI_API_KEY`
- `GEMINI_API_KEY`
- `GEMINI_API_KEY_ALT`
- `LITELLM_MASTER_KEY`
- `LITELLM_DATABASE_URL`
- `LITELLM_OPENAI_VIRTUAL_KEY`
- `LITELLM_GEMINI_VIRTUAL_KEY`

> **Supabase Postgres note:** A Supabase free-tier database works fine for `LITELLM_DATABASE_URL`, but it enforces a small connection cap (commonly 15 in session mode). If you share one DB across multiple local proxies, keep each proxy small: this repo defaults to `--num_workers 1`, `database_connection_pool_limit: 1`, and `?connection_limit=1` on the URL. Upgrading to a paid plan is required for the IPv4 transaction pooler that removes the cap.

### 3. Bootstrap and register the launcher keys

```bash
./setup.sh
```

This script will:

- load your `.env`
- verify local prerequisites
- create/sync `.venv` using `uv`
- generate the Prisma client LiteLLM expects
- start LiteLLM on port `4000`
- register the OpenAI and Gemini virtual keys used by the included launchers
- tail the proxy log so you can confirm startup

### 4. Start the proxy later

Once the environment already exists, you can run:

```bash
./run.sh
```

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

> This password is only for the `/ui` admin interface. Claude Code requests still authenticate with the virtual keys (`LITELLM_OPENAI_VIRTUAL_KEY`, `LITELLM_GEMINI_VIRTUAL_KEY`).

From there you can inspect registered virtual keys, track spend, view request logs, and manage model routing without touching `config.yaml` directly.

## Virtual-key profiles

The setup script registers two virtual keys:

- `LITELLM_OPENAI_VIRTUAL_KEY`
- `LITELLM_GEMINI_VIRTUAL_KEY`

Those map Claude Code model aliases to the configured upstream models in `config.yaml`.

### OpenAI/Codex profile

- `claude-opus-4-7` → `openai/gpt-5.5`
- `claude-sonnet-4-6` → `openai/gpt-5.4`
- `claude-haiku-4-6` → `openai/gpt-5.4-mini`

### Gemini profile

- `claude-opus-4-7` → `gemini/gemini-3.1-pro-preview`
- `claude-sonnet-4-6` → `gemini/gemini-3.1-pro-preview`
- `claude-haiku-4-6` → `gemini/gemini-3.5-flash`

## Using the tmux launchers

The included launchers are designed to be run from the repository you want Claude Code to operate in.

For example, from your app repo:

```bash
cd ~/Developer/luminarylane2/repos/stream-4
/path/to/litellm-proxy/start-litellm-codex-in-tmux.sh stream-4-openai
```

or:

```bash
cd ~/Developer/luminarylane2/repos/stream-4
/path/to/litellm-proxy/start-litellm-gemini-in-tmux.sh stream-4-gemini
```

The launchers expect:

- `.mcp.json` exists in the current working directory
- the LiteLLM proxy is already running on `localhost:4000`
- the virtual keys from your `.env` are available

If you want a non-default proxy endpoint, set:

- `LITELLM_BASE_URL_OVERRIDE`

before launching.

## Optional: DX and cost optimizations

A few open-source add-ons that improve the Claude Code experience when using this proxy:

- **[lean-ctx](https://github.com/yvgude/lean-ctx)** — a context runtime that sits between Claude Code and the filesystem. It compresses repeated file reads with AST-aware logic, strips noise from shell output, and manages cross-session memory.
- **[caveman](https://github.com/JuliusBrussee/caveman)** — a Claude Code plugin that trims verbose model output. Reports suggest it can cut output tokens by roughly 65–75% by keeping replies short and direct.
- **[tweakcc](https://github.com/Piebald-AI/tweakcc)** — customize Claude Code's look and feel: themes, thinking verbs, spinners, input styling, system prompts, custom toolsets, and more.

None of these are required to use the proxy, but they can make long sessions cheaper, faster, or more pleasant.

## Validation

Basic shell validation for the shipped scripts:

```bash
bash -n setup.sh
bash -n run.sh
bash -n start-litellm-codex.sh
bash -n start-litellm-gemini.sh
bash -n start-litellm-codex-in-tmux.sh
bash -n start-litellm-gemini-in-tmux.sh
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
