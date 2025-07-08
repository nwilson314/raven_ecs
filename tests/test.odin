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
    position_pool := ecs.create_component_pool(Position)

    // 1. Create entities
    entity1 := ecs.make_entity(&world)
    entity2 := ecs.make_entity(&world)

    // 2. Add components
    ecs.add(&position_pool, &world, entity1, Position{10, 20})
    ecs.add(&position_pool, &world, entity2, Position{30, 40})

    testing.expect(t, ecs.has(&position_pool, entity1), "Entity1 should have a Position component")
    testing.expect(t, ecs.has(&position_pool, entity2), "Entity2 should have a Position component")

    // 3. Get components
    pos1 := ecs.get(&position_pool, entity1)
    testing.expect(t, pos1.x == 10 && pos1.y == 20, "Position data for entity1 is incorrect")

    // 4. Remove a component
    ecs.remove(&position_pool, entity1)
    testing.expect(t, !ecs.has(&position_pool, entity1), "Entity1 should not have a Position component after removal")

    // 5. Verify swap-and-pop
    pos2 := ecs.get(&position_pool, entity2)
    testing.expect(t, pos2.x == 30 && pos2.y == 40, "Position data for entity2 should be unchanged after removing entity1's component")

    // 6. Clean up
    ecs.destroy_world(&world)
    ecs.destroy_component_pool(&position_pool)
}