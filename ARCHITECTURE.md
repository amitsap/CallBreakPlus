# Architecture

## Dependency direction

```text
SwiftUI views → GameViewModel → Engine
     │                   ├── BotStrategy implementations
     │                   ├── ProGate (stored preferences + hasPro → effective rules)
     │                   └── StatsRepository protocol → SwiftData adapter → versioned schema
     └── ProStore (environment) → StoreKit 2
```

The engine is authoritative and headless: value types represent cards, bids, tricks, seats, and phases; mutations validate the current phase and legal action; deterministic tests inject a seeded random generator. Bots consume only engine state. Views contain presentation and input affordances, not rules.

## Game flow

`GameViewModel` owns one cancel-and-replace task that sequences dealing, bidding, card play, trick collection, and round transitions. The underlying `GameState` transitions synchronously. Completed-round and game-over results are recorded before cancellable celebration delays so leaving the screen cannot erase a finished result.

## Pro entitlement

`ProStore` is the only StoreKit client: it loads the product, purchases, restores, and derives `hasPro` from `Transaction.currentEntitlements`, so refunds, Family Sharing, Ask to Buy and offline launches resolve the same way. The view model sees Pro only as an injected `hasPro` closure and never imports StoreKit. `ProGate` is pure: it resolves stored preferences to the values a game actually uses, and gating never rewrites a stored choice, so losing Pro falls back to the free defaults and regaining it restores the choice. Engine and bots know nothing of Pro.

## Persistence

`StatsRepository` defines value-based result and summary operations without importing SwiftData. `SwiftDataStatsRepository` is the only persistence implementation. Failed saves roll back pending changes; reset deletes fetched objects individually so rollback remains meaningful. The schema is versioned: a shipped version is never edited, and each model change adds a version, a migration stage and a test against a store written by the shipped build.

## Privacy boundary

There is no network layer of the app's own; StoreKit is the only system service it calls. The snapshot contains no production signing configuration, credentials, telemetry, or server component.
