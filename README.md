# PaymentRouter (Haskell)

A small, pure-functional payment validation & routing engine, written while learning Haskell specifically to understand how functional programming is used to express payment business logic — the pattern Juspay's engineering org is built around.

**Honesty note:** this is a learning project, not professional Haskell experience. I built it to actually understand the concepts (immutability, algebraic data types, `Either`/`Maybe` for explicit error handling, pure function composition) by applying them to a real-shaped problem, not to pad a resume. I can walk through every line of it and explain why it's written the way it is.

## What it does

1. **Validation** (`src/Validation.hs`) — validates a transaction request (amount, payment method, merchant limits) using `Either`, so every failure mode is explicit in the type signature and the pipeline short-circuits on the first failure — no exceptions, no forgotten null checks.
2. **Routing** (`src/Routing.hs`) — scores available payment service providers (PSPs) and selects the best *healthy* one, automatically "failing over" to the next-best PSP if the top-ranked one is down. There's no special-case failover branch; it falls out of composing "rank by score" with "filter by health."
3. **Analytics** (`src/Analytics.hs`) — aggregates a batch of transaction outcomes into per-PSP success rates using `map`/`filter`/`fold`-style list processing.

## Why these three specifically

They mirror language straight out of Juspay's own job description:
- *"Concise Expression of Complex Payment Logic"* → the `Either`-based validation pipeline
- *"Intelligent traffic routing" / "Self-Healing systems"* → the health-aware PSP scoring/selection
- *"Intelligence from transactions"* → the analytics aggregation

## Concepts demonstrated

- **Immutability** — no value is ever mutated; every function takes inputs and returns new outputs
- **Algebraic data types** (`PaymentMethod`, `ValidationError`) — GHC enforces exhaustive pattern matching, so a forgotten case is a compile-time warning, not a production incident
- **`Either` for explicit, typed error handling** — no exceptions
- **Pure function composition** — `rankedHealthyPSPs` + filtering = failover, without writing failover-specific code
- **Higher-order functions** (`map`, `filter`, `groupBy`) for batch data processing

## Run it

```bash
# Compile the demo
ghc -Wall -isrc -iapp -o payment_router app/Main.hs
./payment_router

# Compile and run the test suite (hand-rolled — no external test
# framework, since this was built without package-index access)
ghc -Wall -isrc -o test_runner test/Tests.hs
./test_runner
```

Expected test output: `10/10 tests passed`.

## What I'd learn next

- Monad transformers / `ExceptT` for combining `Either` with `IO` cleanly
- Property-based testing with QuickCheck instead of hand-rolled assertions
- Real concurrency in Haskell (`STM`, `async`) — the Haskell equivalent of the `asyncio` work in my [DistribuLB](../distribulb) project
