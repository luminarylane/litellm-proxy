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
- `update.sh` — refresh the proxy libraries and re-register the OpenAI 5.6 virtual-key aliases
- `scripts/` — relocatable Claude Code launchers to copy into a target repository

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
- `LITELLM_OPENAI_5_6_VIRTUAL_KEY`
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

> This password is only for the `/ui` admin interface. Claude Code requests still authenticate with the virtual keys (`LITELLM_OPENAI_VIRTUAL_KEY`, `LITELLM_OPENAI_5_6_VIRTUAL_KEY`, and `LITELLM_GEMINI_VIRTUAL_KEY`).

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

## Install and use the Claude Code launchers

The `scripts/` directory is a relocatable launcher bundle. Copy it into the target repository under `.claude/litellm-launchers/`; do not replace the target repository's own `scripts/` directory.

The launchers resolve sibling scripts from their own directory, while preserving the target repository as the working directory. That keeps `.mcp.json` and `CLAUDE_PROJECT_DIR` scoped to the repository Claude Code should operate in.

```bash
# Start the proxy first, from this repository.
./setup.sh
# For later starts, use: ./run.sh

# Then install the launcher bundle in the target repository.
cd ~/Developer/my-project
mkdir -p .claude
cp -R ~/Developer/litellm-proxy/scripts .claude/litellm-launchers

# Start the model selector in a tmux workspace.
.claude/litellm-launchers/start-tmux.sh my-project
```

The target repository must provide `.mcp.json`. The LiteLLM-backed choices also require the local proxy to be running on `localhost:4000`; Kimi and Z.ai choices use their direct provider endpoints and their credentials are read from the target repository's `.env.local`.

To refresh the copied launcher bundle after updating this repository:

```bash
rm -rf .claude/litellm-launchers
cp -R ~/Developer/litellm-proxy/scripts .claude/litellm-launchers
```

## Optional: Claude Code themes with Tinty

[Tinty](https://github.com/tinted-theming/tinty) and [tinted-claude-code](https://github.com/tinted-theming/tinted-claude-code) compile Base16, Base24, and Tinted8 color schemes into Claude Code themes. Claude Code hot-reloads the theme file, so switching a Tinty scheme updates the active session without a restart.

### Default: one hot-reloaded theme

Add the following item to `~/.config/tinted-theming/tinty/config.toml`. The executable flavor is recommended because it provides themed diffs and shimmer effects; it requires Node.js.

```toml
[[items]]
name = "tinted-claude-code"
path = "https://github.com/tinted-theming/tinted-claude-code"
themes-dir = "scripts"
theme-file-extension = ".js"
supported-systems = ["base16", "base24", "tinted8"]
hook = "mkdir -p \"$HOME/.claude/themes\" && node \"$TINTY_THEME_FILE_PATH\" > \"$HOME/.claude/themes/tinty.json\""
```

Install the bindings and apply a scheme:

```bash
tinty install
tinty apply base16-ayu-dark
```

The first time only, start Claude Code and run `/theme`, then select **Tinty**. Claude Code stores this as `custom:tinty`; later `tinty apply` calls replace `~/.claude/themes/tinty.json`, which all instances using that theme hot-reload.

For a static JSON-only setup, use `themes` and `.json` instead, with this hook:

```toml
hook = "mkdir -p \"$HOME/.claude/themes\" && cp -f \"$TINTY_THEME_FILE_PATH\" \"$HOME/.claude/themes/tinty.json\""
```

### Optional: distinct colors for concurrent Claude Code instances

The default `tinty.json` is intentionally shared, so switching it updates every running Claude Code instance that selected **Tinty**. If you run several instances and want each to have a distinct color, copy the static JSON themes from the [tinted-claude-code `themes/` directory](https://github.com/tinted-theming/tinted-claude-code/tree/main/themes) to the global Claude Code theme directory using different filenames:

```bash
mkdir -p ~/.claude/themes
cp ~/Developer/tinted-claude-code/themes/base16-ayu-dark.json ~/.claude/themes/stream-a.json
cp ~/Developer/tinted-claude-code/themes/base16-dracula.json ~/.claude/themes/stream-b.json
```

In each running instance, use `/theme` and select its corresponding custom theme. Theme discovery is global (`~/.claude/themes`), while the selection is per Claude Code instance, so `stream-a` and `stream-b` can run side-by-side with independent colors. Use the `tinty.json` workflow when a single coordinated theme is preferable; use named static files when visual differentiation matters more.

## Optional: token and context efficiency

These add-ons reduce avoidable context and output tokens, helping subscriptions last longer without reducing the work Claude Code performs:

- **[lean-ctx](https://github.com/yvgude/lean-ctx)** — a context runtime that compresses repeated file reads with AST-aware logic, strips noise from shell output, and manages cross-session memory.
- **[caveman](https://github.com/JuliusBrussee/caveman)** — a Claude Code plugin that trims verbose model output. Reports suggest it can cut output tokens by roughly 65–75% by keeping replies short and direct.

Neither is required to use the proxy. They are most useful in long-running sessions where repeated context reads and overly verbose responses would otherwise consume the subscription allowance.

## Optional: Claude Code developer experience with TweakCC

**[TweakCC](https://github.com/Piebald-AI/tweakcc)** is a visual and interaction customization tool for Claude Code. It does not reduce token use, but it can make long-running, multi-instance workflows clearer and more pleasant.

Use it to experiment with:

- themes, color palettes, and interface styling
- thinking verbs, spinners, and other feedback states
- input and chat presentation
- system prompts and custom toolsets

It complements Tinty: use Tinty when you want scheme-driven Claude Code themes and hot reloads; use TweakCC when you want broader CLI presentation and interaction customization.

## Validation

Basic shell validation for the shipped scripts:

```bash
bash -n setup.sh
bash -n run.sh
bash -n update.sh
bash -n scripts/*.sh
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
