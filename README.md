# Raven ECS

A simple ECS implementation in Odin.

## Odin ECS – Project Overview
A minimal-yet-extensible **Entity–Component–System** framework written in the **Odin programming language**.  
The design is data-oriented and cache-friendly by default, but small enough to drop into any solo-dev game project and grow over time.

### High-Level Roadmap (6 weekly sprints)

| Sprint | Theme | Deliverable |
| ------ | ----- | ----------- |
| 0 | Project bootstrap | Odin + Raylib window; hot-reload script |
| 1 | Entity & component core | Free-list `EntityID`s, generic sparse-set component pools; 10 k-dot demo @ ≥60 FPS |
| 2 | Query & System layer | `Query(Position, Velocity)` API; system scheduler |
| 3 | Sparse-set optimisation | Bench ≤ 1 ms update for 100 k entities |
| 4 | Archetype chunks & demo | Tank-arena game running live add/remove |
| 5 | Lifetime safety & events | Deferred destroy queue; event bus |
| 6 | Serialization & jobs | Save/load JSON; multithreaded systems |

---

## Completed Milestones

### ✅ Sprint 0 – Project Bootstrap
* Odin module initialised, Raylib bindings added.  
* `src/main.odin` opens a window; hot-reload script in `scripts/`.  

### ✅ Sprint 1 – Entity & Component Core
* `World` with free-list allocator for **O(1)** create/destroy.  
* Generic `ComponentPool(T)` implementing dense-array + sparse-index storage.  
* Swap-and-pop removal keeps arrays compact.  
* Unit tests for entity & component lifecycles (`tests/test.odin`).  
* Rendering test spawns **10 000** coloured circles at ~71 FPS (meets 60 FPS target).  

### ✅ Sprint 2 – Queries & Systems
*   **Iterator-Based Query System**: Implemented `ecs.query()` which takes a variable number of component pools and returns a `QueryIterator`.
*   **Optimized Iteration**: The query iterator automatically selects the smallest component pool as its source, minimizing iteration cost. It then checks for component existence in the other pools for each entity.
*   **Refactored Demo**: The main rendering loop in `tests/main.odin` was refactored to use the new `query` API, cleaning up the code and demonstrating the new functionality.
*   **Comprehensive Tests**: Added unit tests for the query system to ensure correctness and prevent regressions.

---

## ✅ Sprint 3 – Sparse-set optimisation

### 1. Benchmarking & Analysis (Complete)
*   **Dedicated Benchmark:** A benchmark test (`tests/benchmark.odin`) was created to measure performance for 100k entities with two components.
*   **Baseline Performance:** The initial implementation clocks in at **~2.1 ms** per frame, failing our ≤ 1 ms target.
*   **Bottleneck Identified:** Through careful measurement, we've confirmed the primary bottleneck is not the logic within the `next()` iterator itself, but the sheer **volume of calls** to it. The current algorithm iterates over the smallest component pool and performs a `base_has` check for every entity, leading to significant overhead from function calls and cache misses when scaled to 100k entities.

### 2. Next Steps: Algorithmic Optimisation
The path to sub-millisecond frame times requires a fundamental change to the query algorithm.
*   **Goal:** Reduce the number of iterations required to find matching entities.
*   **Strategy:**
    1.  Modify the `add` and `remove` procedures to maintain **sorted** entity ID lists within each component pool.
    2.  Rewrite the `next` iterator to use a cache-friendly, single-pass "merge" or "zip" algorithm over these sorted lists. This will find the intersection of entities far more efficiently.

_Once these tasks are green, tag the repository `v0.3-sprint3` and roll into Sprint 4._
