# CLI demo

> **This is a presenter's script, not a clone-and-run sample.** It drives a live
> webinar walkthrough against private fixtures: real credentials in `../.env`, a
> reachable Postgres warehouse, and a persistent Soda Cloud data source backed by
> an online Runner. Steps 1, 4, 5, and 6 need that infrastructure and will not
> work without it. Only `soda contract test` (syntax check) runs standalone.
> The `soda contract create` step degrades gracefully — see below.

Run the data-contract walkthrough:

```bash
./demo.sh
```

On first run `demo.sh` builds a local `.venv` and installs `soda-core` +
`soda-postgres` from public PyPI — that's all the demo needs to **verify** a
contract and publish results to Soda Cloud. A working `.venv` is reused as-is.

Env knobs: `TYPE_SPEED=0` (instant typing, for rehearsal), `RESET_ONLY=1`
(just restore the repo to its pre-demo state).

## The `soda contract create` step

Generating a contract skeleton (Step 2) uses `soda contract create`, which lives
in Soda's **extensions library**. That package is **not published on public
PyPI**, so it can't be `pip install`ed and we can't bundle its wheel.

`demo.sh` handles this automatically:

- **Extensions present** (importable as `soda.contract_generator`) → runs the
  real `soda contract create`.
- **Extensions absent** → stands in with the pre-generated skeleton at
  `parts/customers.skeleton.contract.yml` (identical to what the generator
  emits) and shows an on-screen note that it's doing so.

To run Step 2 for real, install the extensions library into `.venv` before
running the demo; otherwise the fallback keeps the walkthrough intact.

> Every other command in the demo (`contract test`, `contract verify
> --use-runner --publish`, and the local verify in `show_query.sh`) is plain
> `soda-core`. Note those steps still require the demo's Postgres/Soda Cloud
> fixtures reachable via `../.env`.
