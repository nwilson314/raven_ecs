package main

import "core:testing"
import ecs "../src"

@(test)
test_entity_lifecycle :: proc(t: ^testing.T) {
    world: ecs.World

    // 1. Test making a new entity
    entity1 := ecs.make_entity(&world)
    testing.expect(t, entity1 == 0, "First entity should have ID 0")
    testing.expect(t, world.next == 1, "World.next should be incremented to 1")

    // 2. Test making another entity
    entity2 := ecs.make_entity(&world)
    testing.expect(t, entity2 == 1, "Second entity should have ID 1")
    testing.expect(t, world.next == 2, "World.next should be incremented to 2")

    // 3. Destroy the first entity
    ecs.destroy_entity(&world, entity1)
    testing.expect(t, len(world.free_list) == 1, "Free list should contain 1 element")
    testing.expect(t, world.free_list[0] == u64(entity1), "Free list should contain the destroyed entity ID")

    // 4. Create a new entity, it should recycle the old ID
    entity3 := ecs.make_entity(&world)
    testing.expect(t, entity3 == entity1, "New entity should recycle the ID from the free list")
    testing.expect(t, len(world.free_list) == 0, "Free list should be empty after recycling")
    testing.expect(t, world.next == 2, "World.next should not be incremented when recycling")

    // 5. Clean up the world
    ecs.destroy_world(&world)
}



@(test)
test_component_lifecycle :: proc(t: ^testing.T) {
    world: ecs.World
    ecs.create_component_pool(&world, Position)

    // 1. Create entities
    entity1 := ecs.make_entity(&world)
    entity2 := ecs.make_entity(&world)

    // 2. Add components
    ecs.add(&world, entity1, Position{10, 20})
    ecs.add(&world, entity2, Position{30, 40})

    testing.expect(t, ecs.has(&world, entity1, Position), "Entity1 should have a Position component")
    testing.expect(t, ecs.has(&world, entity2, Position), "Entity2 should have a Position component")

    // 3. Get components
    pos1, _ := ecs.get(&world, entity1, Position)
    testing.expect(t, pos1.x == 10 && pos1.y == 20, "Position data for entity1 is incorrect")

    // 4. Remove a component
    ecs.remove(&world, entity1, Position)
    testing.expect(t, !ecs.has(&world, entity1, Position), "Entity1 should not have a Position component after removal")

    // 5. Verify swap-and-pop
    pos2, _ := ecs.get(&world, entity2, Position)
    testing.expect(t, pos2.x == 30 && pos2.y == 40, "Position data for entity2 should be unchanged after removing entity1's component")

    // 6. Clean up
    ecs.destroy_world(&world)
}

@(test)
test_query_collect :: proc(t: ^testing.T) {
    world: ecs.World
    ecs.create_component_pool(&world, Position)
    ecs.create_component_pool(&world, Velocity)

    // Entity 1: Has Position only
    e1 := ecs.make_entity(&world)
    ecs.add(&world, e1, Position{1, 1})

    // Entity 2: Has Position and Velocity
    e2 := ecs.make_entity(&world)
    ecs.add(&world, e2, Position{2, 2})
    ecs.add(&world, e2, Velocity{2, 2})

    // Entity 3: Has Position and Velocity
    e3 := ecs.make_entity(&world)
    ecs.add(&world, e3, Position{3, 3})
    ecs.add(&world, e3, Velocity{3, 3})

    // Collect entities with both components
    collected_entities := ecs.query_collect(&world, Position, Velocity)
    defer delete(collected_entities)

    testing.expect_value(t, len(collected_entities), 2)

    // Check that the correct entities were found
    found_e2 := false
    found_e3 := false
    for entity in collected_entities {
        if entity == e2 { found_e2 = true }
        if entity == e3 { found_e3 = true }
    }
    testing.expect(t, found_e2 && found_e3, "Did not collect the correct entities")

    // Clean up
    ecs.destroy_world(&world)
}

@(test)
test_destroy_entity_removes_components :: proc(t: ^testing.T) {
    world: ecs.World
    ecs.create_component_pool(&world, Position)

    // 1. Create and destroy an entity
    e1 := ecs.make_entity(&world)
    ecs.add(&world, e1, Position{1, 1})
    testing.expect(t, ecs.has(&world, e1, Position), "Entity should have component before being destroyed")
    
    ecs.destroy_entity(&world, e1)

    // 2. Create a new entity, which should reuse the ID of e1
    e2 := ecs.make_entity(&world)

    // 3. Assert that the new entity does not have the old one's component
    testing.expect_value(t, e1, e2)
    testing.expect(t, !ecs.has(&world, e2, Position), "New entity should not have component from destroyed entity")

    // Clean up
    ecs.destroy_world(&world)
}