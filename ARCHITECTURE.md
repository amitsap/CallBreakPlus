# Architecture

## Dependency direction

```text
SwiftUI views → GameViewModel → Engine
                         ├── BotStrategy implementations
                         └── StatsRepository protocol → SwiftData adapter
```

The engine is authoritative and headless: value types represent cards, bids, tricks, seats, and phases; mutations validate the current phase and legal action; deterministic tests inject a seeded random generator. Bots consume only engine state. Views contain presentation and input affordances, not rules.

## Game flow

`GameViewModel` owns one cancel-and-replace task that sequences dealing, bidding, card play, trick collection, and round transitions. The underlying `GameState` transitions synchronously. Completed-round and game-over results are recorded before cancellable celebration delays so leaving the screen cannot erase a finished result.

## Persistence

`StatsRepository` defines value-based result and summary operations without importing SwiftData. `SwiftDataStatsRepository` is the only persistence implementation. Failed saves roll back pending changes; reset deletes fetched objects individually so rollback remains meaningful.

## Privacy boundary

There is no network layer. The snapshot contains no production signing configuration, credentials, telemetry, or server component.
