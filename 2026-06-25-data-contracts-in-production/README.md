# Soda webinar demo

Source for a Soda data-quality webinar demo. Two ways to catch bad data and publish
results to Soda Cloud — one **CLI/contract** flow, one **agentic/MCP** flow — sharing a
common Postgres dataset.

## Layout

| Dir | What it is |
|---|---|
| `data/` | Generates and loads the demo dataset — a reproducible e-commerce dataset in a `clean/` and a deliberately `failing/` variant. |
| `cli/` | Key-advance terminal walkthrough of the data-contract flow: load failing → generate contract → add checks → verify (fails) → load clean → verify (passes). Run `cli/demo.sh`. |
| `agentic/` | Drives the same outcome via the Soda MCP server and Claude Code (`demo-prompt.txt`), plus `prep.sh` / `clean.sh` reset helpers. |
| `poll/` | Static live audience poll (Supabase + Vercel). Keys live only in `.env`; run `poll/gen-config.sh` to emit the gitignored `poll/config.js` for the browser. Nothing with a key is committed. |

## Setup

Copy `.env.example` to `.env` and fill in your Soda Cloud, Postgres, and (optional)
BigQuery credentials. Every script and YAML reads its secrets and hosts from there
(`${env.VAR}`) — nothing sensitive is committed.

```bash
cp .env.example .env      # then edit
python3 data/generate_data.py --mode failing --out data/failing   # or ./data/generate_data.sh
```

Then run the CLI demo (`cd cli && ./demo.sh`) or the agentic demo (see `agentic/demo-prompt.txt`).

> Local Claude config (`.claude/`) and Vercel state (`poll/.vercel/`, `poll/.env.local`)
> are gitignored — they hold local tokens and aren't part of the published source.
