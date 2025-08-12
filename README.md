# Raven ECS

A high-performance Entity Component System (ECS) written in Odin, designed for game development and simulation applications.

## Features

- **Fast Entity Management**: Efficient entity creation/destruction with ID recycling
- **Component Pools**: Sparse set data structure for optimal memory layout and cache performance
- **Query System**: Fast iteration over entities with specific component combinations
- **Memory Efficient**: Uses sparse arrays and dense arrays for optimal memory usage
- **Type Safe**: Leverages Odin's type system for compile-time safety

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

// Create component pools for each component type
ecs.create_component_pool(&world, Transform)
ecs.create_component_pool(&world, Color)
ecs.create_component_pool(&world, Velocity)

// Clean up when done
defer ecs.destroy_world(&world)
```



### Updating the Submodule

To pull the latest changes from the Raven ECS repository into your project, navigate to your project's root directory and run the following command:

```bash
git submodule update --remote vendor/raven_ecs
```

## Architecture

The ECS uses a **sparse set** data structure where:
- **Dense arrays** store actual component data and entity owners
- **Sparse arrays** provide O(1) entity-to-index lookups
- **Component pools** are created per component type
- **Entity IDs** are recycled when entities are destroyed

## Basic Usage

### 1. Setup

```odin
import ecs "path/to/raven_ecs"

// Create a world
world := ecs.World{}

// Create component pools for each component type
ecs.create_component_pool(&world, Transform)
ecs.create_component_pool(&world, Color)
ecs.create_component_pool(&world, Velocity)

// Clean up when done
defer ecs.destroy_world(&world)
```

### 2. Component Definitions

```odin
Transform :: struct {
    x, y: f32
}

Color :: struct {
    r, g, b, a: u8
}

Velocity :: struct {
    dx, dy: f32
}
```

### 3. Entity Management

```odin
// Create an entity
entity := ecs.make_entity(&world)

// Add components to an entity
ecs.add(&world, entity, Transform{100, 200})
ecs.add(&world, entity, Color{255, 0, 0, 255})
ecs.add(&world, entity, Velocity{5, 3})

// Check if entity has a component
if ecs.has(&world, entity, Transform) {
    // Entity has Transform component
}

// Get a component (returns pointer and success flag)
if transform, ok := ecs.get(&world, entity, Transform); ok {
    transform.x += 10
    transform.y += 5
}

// Remove a component
ecs.remove(&world, entity, Color)

// Destroy an entity (removes all components)
ecs.destroy_entity(&world, entity)
```

### 4. Querying Entities

Raven ECS provides a unified query system that balances performance and ease of use:

#### **Unified Query API (Fast by Default)**
```odin
// Simple and clean API - now fast by default!
it := ecs.query(&world, Transform, Velocity)
defer ecs.destroy_iterator(it)

for {
    entity, ok := ecs.next(it)
    if !ok {
        break
    }
    
    // Option 1: Standard component access (slower, does map lookups)
    transform, _ := ecs.get(&world, entity, Transform)
    velocity, _ := ecs.get(&world, entity, Velocity)
    
    // Option 2: Fast component access (no map lookups - recommended!)
    transform, _ := ecs.get_from_query(it, entity, Transform)
    velocity, _ := ecs.get_from_query(it, entity, Velocity)
    
    // Update logic
    transform.x += velocity.dx
    transform.y += velocity.dy
}
```

**Performance Options:**
- **Pure iteration**: ~0.23ms for 100,000 entities
- **With `get_from_query`**: ~0.59ms for 100,000 entities (2x faster than `get`)
- **With standard `get`**: ~1.15ms for 100,000 entities (slower due to map lookups)

**Best Practice**: Use `get_from_query` for performance-critical loops!

#### **Collect All Matching Entities**
```odin
// Get all entities with specific components
entities := ecs.query_collect(&world, Transform, Color)
defer delete(entities)

for entity in entities {
    // Process each entity
    transform, _ := ecs.get(&world, entity, Transform)
    color, _ := ecs.get(&world, entity, Color)
    
    // Render logic
    draw_circle(transform.x, transform.y, color)
}
```

## Performance Characteristics

- **Entity Creation**: O(1) amortized
- **Component Addition**: O(1) amortized
- **Component Access**: O(1)
- **Component Removal**: O(1) with swap-and-pop optimization
- **Query Iteration**: O(n) where n is the number of entities with the rarest component
- **Memory**: Sparse arrays use MAX_ENTITIES (100,000) slots per component type

### **Query Performance Breakdown**

| Query Type | Pure Iteration | With Component Access | Performance Gain |
|------------|----------------|----------------------|------------------|
| **Unified Query** (`query`/`next`) | ~0.23ms | ~0.59ms with `get_from_query` | **2x faster** than `get` |
| **Standard `get`** | N/A | ~1.15ms | Baseline (slower due to map lookups) |
| **Performance Ratio** | Fast by default | **1.95x faster** with `get_from_query` | Significant improvement |

## Best Practices

1. **Use the Unified Query System**:
   - **`query`/`next`** is now fast by default (no map lookups during iteration)
   - Use **`get_from_query`** instead of `get` for best performance
   - The simple API now gives you the performance benefits automatically

2. **Reuse Iterators**: Create iterators once and reuse them in update loops
3. **Batch Operations**: Group entity operations when possible
4. **Component Pool Order**: Create component pools in the order they'll be used most frequently
5. **Memory Management**: Always call `destroy_world()` to clean up resources
6. **Iterator Cleanup**: Use `defer ecs.destroy_iterator(it)` or manually destroy iterators

## Example: Simple Game Loop

```odin
package main

import "core:fmt"
import ecs "path/to/raven_ecs"

Transform :: struct { x, y: f32 }
Velocity :: struct { dx, dy: f32 }
Renderable :: struct { color: u32 }

main :: proc() {
    world := ecs.World{}
    defer ecs.destroy_world(&world)
    
    // Setup component pools
    ecs.create_component_pool(&world, Transform)
    ecs.create_component_pool(&world, Velocity)
    ecs.create_component_pool(&world, Renderable)
    
    // Spawn entities
    for i in 0..<1000 {
        entity := ecs.make_entity(&world)
        ecs.add(&world, entity, Transform{f32(i), 0})
        ecs.add(&world, entity, Velocity{1, 1})
        ecs.add(&world, entity, Renderable{0xFF0000FF})
    }
    
    // Game loop
    for frame in 0..<60 {
        // Update physics (now fast by default!)
        it := ecs.query(&world, Transform, Velocity)
        for {
            entity, ok := ecs.next(it)
            if !ok {
                ecs.destroy_iterator(it)
                break
            }
            
            // Use get_from_query for best performance
            transform, _ := ecs.get_from_query(it, entity, Transform)
            velocity, _ := ecs.get_from_query(it, entity, Velocity)
            
            transform.x += velocity.dx
            transform.y += velocity.dy
        }
        
        // Render (now fast by default!)
        render_it := ecs.query(&world, Transform, Renderable)
        for {
            entity, ok := ecs.next(render_it)
            if !ok {
                ecs.destroy_iterator(render_it)
                break
            }
            
            transform, _ := ecs.get_from_query(render_it, entity, Transform)
            renderable, _ := ecs.get_from_query(render_it, entity, Renderable)
            
            // Draw entity
            fmt.printf("Drawing entity %v at (%v, %v) with color %v\n", 
                      entity, transform.x, transform.y, renderable.color)
        }
    }
}
```

### **Alternative: Simple Game Loop (Using Standard get)**

```odin
// Simpler but slower version - good for prototyping
for frame in 0..<60 {
    // Update physics (simple API, slower performance)
    it := ecs.query(&world, Transform, Velocity)
    for {
        entity, ok := ecs.next(it)
        if !ok {
            ecs.destroy_iterator(it)
            break
        }
        
        // Standard get is slower but simpler
        transform, _ := ecs.get(&world, entity, Transform)
        velocity, _ := ecs.get(&world, entity, Velocity)
        
        transform.x += velocity.dx
        transform.y += velocity.dy
    }
}
```

## Performance Trade-offs

### **Unified Query System**

Raven ECS now provides a single, fast query system with performance options:

| Aspect | Unified Query (`query`/`next`) | Performance Options |
|--------|--------------------------------|-------------------|
| **API Complexity** | Simple, clean | Same simple API |
| **Performance** | Fast by default (~0.23ms pure iteration) | Choose your component access speed |
| **Memory Overhead** | Optimized (cached pools) | Efficient memory usage |
| **Use Case** | Everything - from prototyping to production | Scales with your needs |
| **Learning Curve** | Easy to learn | One system to master |

### **Component Access Performance**

- **`get_from_query`**: Fastest (~0.59ms for 100k entities) - **Recommended for performance**
- **Standard `get`**: Slower (~1.15ms for 100k entities) - **Good for prototyping and simple code**

### **When to Use Each**

- **Start Simple**: Use `query`/`next` with standard `get` when learning
- **Optimize When Needed**: Switch to `get_from_query` for performance-critical loops
- **Best of Both Worlds**: Simple API that's fast by default, with optional performance boost

## Limitations

- Maximum entities: 100,000 (configurable via `MAX_ENTITIES`)
- Component types must be known at compile time
- No built-in serialization
- No component inheritance or composition
- No automatic memory management for component data

## Building and Testing

```bash
# Run tests
odin test tests/

# Run benchmarks
odin test tests/benchmark.odin -file -o:speed

# Build example
odin build tests/main.odin
```
