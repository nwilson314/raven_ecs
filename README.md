# Raven ECS

A simple ECS implementation in Odin.

## Odin ECS – Project Overview
A minimal-yet-extensible **Entity–Component–System** framework written in the **Odin programming language**.  
The design is data-oriented and cache-friendly by default, but small enough to drop into any solo-dev game project and grow over time.

## Installation

The recommended way to use Raven ECS in your own project is by adding it as a git submodule.

From the root of your project's repository, run the following command:

```bash
git submodule add https://github.com/nwilson314/raven_ecs.git vendor/raven_ecs
```

Then, when you compile your project, you need to tell the Odin compiler where to find the `raven` collection:

```bash
odin build . -collection:raven=vendor/raven_ecs
```

Finally, you can import and use the library in your code:

```odin
import ecs "raven:ecs"

// ...
world := ecs.World{}
```

### Updating the Submodule

To pull the latest changes from the Raven ECS repository into your project, navigate to your project's root directory and run the following command:

```bash
git submodule update --remote vendor/raven_ecs
```

## Usage

Here is a basic example of how to use Raven-ECS:

```odin
package main

import "core:fmt"
import ecs "vendor:raven_ecs/src" // Adjust import path as needed

// 1. Define components as simple structs
Position :: struct {
	x, y: f32,
}

Velocity :: struct {
	dx, dy: f32,
}

main :: proc() {
	// 2. Create a world
	world: ecs.World
	defer ecs.destroy_world(&world) // Handles all cleanup automatically

	// 3. Create component pools. The world will manage their memory.
	position_pool := ecs.create_component_pool(&world, Position)
	velocity_pool := ecs.create_component_pool(&world, Velocity)

	// 4. Create an entity and add components
	player := ecs.make_entity(&world)
	ecs.add(&world, player, Position{10, 20})
	ecs.add(&world, player, Velocity{1, 0})

	// 5. Query for entities with both Position and Velocity
	fmt.println("Moving entities:")
	it := ecs.query(&world, Position, Velocity)
	for {
		entity, ok := ecs.next(&it)
		if !ok {
			break
		}
		pos := ecs.get(&world, entity, Position)
		vel := ecs.get(&world, entity, Velocity)
		fmt.printf("  -> Entity %v is at (%v, %v) with velocity (%v, %v)\n", entity, pos.x, pos.y, vel.dx, vel.dy)
	}
}
```

## Performance

The query iterator has been optimized to achieve an average update time of **~0.16ms** for 100,000 entities on an Apple M1 Pro.

The key to this performance was not complex algorithmic changes, but rather enabling the Odin compiler's aggressive optimizations using the `-o:speed` flag during compilation. This highlights the power of the Odin compiler and the importance of benchmarking with release/optimized builds.

To run the benchmark:
```bash
odin test tests/ -vet -o:speed
```

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

## ✅ Sprint 3 – Sparse-set Optimisation (Complete)

*   **Goal:** Achieve ≤ 1 ms update time for 100,000 entities.
*   **Benchmark Created:** A dedicated benchmark (`tests/benchmark.odin`) was created to rigorously test query performance.
*   **Bottleneck Identified:** Initial tests showed performance at ~2.1ms. Analysis revealed the bottleneck was not algorithmic complexity, but CPU cache misses caused by random memory access in the `base_has` check during iteration.
*   **Solution Found:** After exploring several manual optimization strategies, the solution was discovered to be enabling the Odin compiler's built-in optimizations. Compiling with the `-o:speed` flag reduced the average update time to **~0.2ms**, far exceeding the original goal.
*   **Key Takeaway:** The Odin compiler is highly effective at optimizing memory access patterns. For performance-critical code, always benchmark with release optimizations (`-o:speed`) enabled.

---

### Sprint 3.5: World-Centric API (Complete)

*   **Goal:** Refactor the ECS to improve its ergonomics and safety, without changing the underlying sparse-set performance. The `World` will become the central owner of all component data.
*   **Result:** Refactored the core API so the `World` now owns and manages all component pools. Component pools are created on the heap and registered with the world automatically. `destroy_world` handles all cleanup. All ECS procedures (`add`, `get`, `has`, `remove`) now operate through the `world` pointer, improving ergonomics and safety.

---

## Current Goal: Sprint 4 - Archetype-Based Storage

With the world-centric API complete, the next major goal is to transition from a component-centric storage model (SoA) to an archetype-based model. This involves grouping entities with the same component composition into contiguous memory chunks, which will dramatically improve query performance and memory locality.

### Sprint 4: Archetype Chunk System (Next)

*   **Goal:** Evolve the ECS architecture from sparse sets to an archetype-based model to achieve maximum iteration performance and lay the foundation for a real game demo.
*   **Strategy:**
    1.  **Archetype Core:** Design and implement an `Archetype` struct that represents a unique combination of component types. The `World` will manage a collection of these archetypes.
    2.  **Chunk-Based Storage:** Instead of individual component pools, memory will be organized into large, contiguous `Chunks` of data. Each chunk will belong to a single archetype and store all the component data for the entities within it.
    3.  **Refactor API:** Update the `add`, `remove`, and `query` procedures to work with the new archetype system. Adding or removing a component will now involve moving an entity's data from one archetype to another.
    4.  **Tank Demo:** Build a simple "tank arena" demo to showcase the new architecture and its ability to handle live entity creation and destruction in a game context.

### Goal

- [x] Create a simple ECS framework in Odin.
- [x] Optimize the query iterator to be as fast as possible.
