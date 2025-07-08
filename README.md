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

## Current TODO – Sprint 3 (Sparse-set optimisation)

1.  **Benchmarking**
    *   Create a dedicated benchmark test.
    *   Profile the `update` loop with 100k entities.
    *   Identify bottlenecks in the `query` and `component` procedures.

2.  **Optimisation**
    *   Implement optimisations based on profiling data.
    *   Target ≤ 1 ms update time for 100k entities with `Position` and `Velocity` components.

_Once these tasks are green, tag the repository `v0.3-sprint3` and roll into Sprint 4._
