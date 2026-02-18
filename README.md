# Raven ECS

A high-performance Entity Component System (ECS) written in Odin, designed for game development and simulation applications.

## Features

- **Fast Entity Management**: Efficient entity creation/destruction with ID recycling
- **Generational IDs**: Stale entity references are detected automatically — no more use-after-destroy bugs
- **Component Pools**: Sparse set data structure for optimal memory layout and cache performance
- **Query System**: Fast iteration over entities with specific component combinations
- **Type Safe**: Leverages Odin's type system for compile-time safety
- **Safe by Default**: Bounds checks on unregistered components, duplicate add protection, MAX_ENTITIES enforcement

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

// Create a world
world := ecs.World{}
defer ecs.destroy_world(&world)

// Create component pools for each component type
ecs.create_component_pool(&world, Transform)
ecs.create_component_pool(&world, Velocity)
```

### Updating the Submodule

To pull the latest changes from the Raven ECS repository into your project:

```bash
git submodule update --remote vendor/raven_ecs
```

## Architecture

The ECS uses a **sparse set** data structure where:
- **Dense arrays** store actual component data and entity owners
- **Sparse arrays** provide O(1) entity-to-index lookups
- **Component pools** are created per component type
- **Entity IDs** use generational indexing — the lower 32 bits are the entity index and the upper 32 bits are a generation counter, incremented each time an ID is recycled

## Basic Usage

### 1. Define Components

```odin
Transform :: struct {
    x, y: f32,
}

Velocity :: struct {
    dx, dy: f32,
}

Color :: struct {
    r, g, b, a: u8,
}
```

### 2. Setup

```odin
world := ecs.World{}
defer ecs.destroy_world(&world)

// Register component pools (once per type)
ecs.create_component_pool(&world, Transform)
ecs.create_component_pool(&world, Velocity)
ecs.create_component_pool(&world, Color)
```

### 3. Entity Management

```odin
// Create an entity
entity := ecs.make_entity(&world)

// Add components
ecs.add(&world, entity, Transform{100, 200})
ecs.add(&world, entity, Velocity{5, 3})

// Adding the same component again overwrites the existing value
ecs.add(&world, entity, Transform{300, 400})

// Check if entity has a component
if ecs.has(&world, entity, Transform) {
    // ...
}

// Get a component (returns pointer for in-place mutation)
if transform, ok := ecs.get(&world, entity, Transform); ok {
    transform.x += 10
}

// Remove a component
ecs.remove(&world, entity, Velocity)

// Destroy an entity (removes all components, recycles ID)
ecs.destroy_entity(&world, entity)
```

### 4. Generational IDs

Entity IDs are generational — when an entity is destroyed and its ID is recycled, old references become stale and are safely rejected:

```odin
enemy := ecs.make_entity(&world)
ecs.add(&world, enemy, Transform{0, 0})

// Store a reference
target := enemy

// Enemy gets destroyed and ID is recycled
ecs.destroy_entity(&world, enemy)
new_entity := ecs.make_entity(&world)

// The old reference is now stale — it won't accidentally hit the new entity
ecs.has(&world, target, Transform)   // returns false
ecs.get(&world, target, Transform)   // returns nil, false

// Check if a reference is still valid
ecs.is_alive(&world, target)         // returns false
```

### 5. Querying Entities

```odin
it := ecs.query(&world, Transform, Velocity)
defer ecs.destroy_iterator(it)

for {
    entity, ok := ecs.next(it)
    if !ok { break }

    transform, _ := ecs.get(&world, entity, Transform)
    velocity, _ := ecs.get(&world, entity, Velocity)

    transform.x += velocity.dx
    transform.y += velocity.dy
}
```

`get_from_query` is also available as an alternative to `get` that avoids the world pool map lookup, though in practice both perform similarly.

#### Collect All Matching Entities

```odin
entities := ecs.query_collect(&world, Transform, Color)
defer delete(entities)

for entity in entities {
    transform, _ := ecs.get(&world, entity, Transform)
    color, _ := ecs.get(&world, entity, Color)
    // ...
}
```

## Performance

All benchmarks run with `-o:speed`, 2 components (Position + Velocity), 60 frames.

| Benchmark | Result |
|---|---|
| Pure iteration (100k entities) | ~0.45 ms/frame |
| Iteration + component access (100k entities) | ~0.60 ms/frame |
| Add + remove (100k entities, single pass) | ~8-10 ms |

### Scaling

| Entities | ms/frame | Throughput |
|---|---|---|
| 10k | ~0.08 | ~130k entities/ms |
| 50k | ~0.38 | ~130k entities/ms |
| 100k | ~0.57 | ~175k entities/ms |

### Complexity

| Operation | Complexity |
|---|---|
| Entity creation | O(1) amortized |
| Component add | O(1) amortized |
| Component get/has | O(1) |
| Component remove | O(1) swap-and-pop |
| Query iteration | O(n) where n = size of smallest matching pool |
| Entity destruction | O(p) where p = number of registered component types |

## API Reference

| Proc | Description |
|---|---|
| `make_entity(&world)` | Create a new entity (panics if MAX_ENTITIES exceeded) |
| `destroy_entity(&world, entity)` | Destroy entity, remove all components, recycle ID |
| `is_alive(&world, entity)` | Check if an entity reference is still valid |
| `add(&world, entity, component)` | Add a component (overwrites if already present) |
| `get(&world, entity, T)` | Get pointer to component, returns `(^T, bool)` |
| `has(&world, entity, T)` | Check if entity has component |
| `remove(&world, entity, T)` | Remove a component |
| `query(&world, ..types)` | Create iterator for entities matching all types |
| `next(it)` | Advance iterator, returns `(EntityID, bool)` |
| `get_from_query(it, entity, T)` | Get component via iterator (no world map lookup) |
| `destroy_iterator(it)` | Free iterator memory |
| `query_collect(&world, ..types)` | Collect all matching entities into a dynamic array |
| `create_component_pool(&world, T)` | Register a component type (once per type) |
| `destroy_world(&world)` | Free all pools and world resources |
| `entity_index(id)` | Extract the index portion of an EntityID |
| `entity_generation(id)` | Extract the generation portion of an EntityID |

## Limitations

- Maximum entities: 100,000 (configurable via `MAX_ENTITIES`)
- Component types must be known at compile time
- No built-in serialization
- No built-in systems scheduler — systems are just procs that call `query`

## Building and Testing

```bash
# Run tests
odin test tests/

# Run tests with memory leak detection (on by default) and reporting
odin test tests/ -o:speed -define:ODIN_TEST_ALWAYS_REPORT_MEMORY=true

# Build the Raylib demo
odin build tests/main.odin
```
