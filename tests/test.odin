package main

import "core:testing"
import ecs "../src"

@(test)
test_entity_lifecycle :: proc(t: ^testing.T) {
    world: ecs.World

    // 1. Test making a new entity
    entity1 := ecs.make_entity(&world)
    testing.expect(t, ecs.entity_index(entity1) == 0, "First entity should have index 0")
    testing.expect(t, ecs.entity_generation(entity1) == 0, "First entity should have generation 0")
    testing.expect(t, world.next == 1, "World.next should be incremented to 1")

    // 2. Test making another entity
    entity2 := ecs.make_entity(&world)
    testing.expect(t, ecs.entity_index(entity2) == 1, "Second entity should have index 1")
    testing.expect(t, world.next == 2, "World.next should be incremented to 2")

    // 3. Destroy the first entity
    ecs.destroy_entity(&world, entity1)
    testing.expect(t, len(world.free_list) == 1, "Free list should contain 1 element")
    testing.expect(t, ecs.entity_index(world.free_list[0]) == ecs.entity_index(entity1), "Free list should contain the destroyed entity index")
    testing.expect(t, ecs.entity_generation(world.free_list[0]) == 1, "Free list entry should have bumped generation")

    // 4. Create a new entity, it should recycle the index but with a new generation
    entity3 := ecs.make_entity(&world)
    testing.expect(t, ecs.entity_index(entity3) == ecs.entity_index(entity1), "New entity should recycle the index")
    testing.expect(t, ecs.entity_generation(entity3) == 1, "Recycled entity should have generation 1")
    testing.expect(t, entity3 != entity1, "Recycled entity should NOT equal the old entity (different generation)")
    testing.expect(t, len(world.free_list) == 0, "Free list should be empty after recycling")
    testing.expect(t, world.next == 2, "World.next should not be incremented when recycling")

    // 5. Clean up the world
    ecs.destroy_world(&world)
}



@(test)
test_component_lifecycle :: proc(t: ^testing.T) {
    world: ecs.World
    ecs.create_component_pool(&world, ecs.Position)

    // 1. Create entities
    entity1 := ecs.make_entity(&world)
    entity2 := ecs.make_entity(&world)

    // 2. Add components
    ecs.add(&world, entity1, ecs.Position{10, 20})
    ecs.add(&world, entity2, ecs.Position{30, 40})

    testing.expect(t, ecs.has(&world, entity1, ecs.Position), "Entity1 should have a Position component")
    testing.expect(t, ecs.has(&world, entity2, ecs.Position), "Entity2 should have a Position component")

    // 3. Get components
    pos1, _ := ecs.get(&world, entity1, ecs.Position)
    testing.expect(t, pos1.x == 10 && pos1.y == 20, "Position data for entity1 is incorrect")

    // 4. Remove a component
    ecs.remove(&world, entity1, ecs.Position)
    testing.expect(t, !ecs.has(&world, entity1, ecs.Position), "Entity1 should not have a Position component after removal")

    // 5. Verify swap-and-pop
    pos2, _ := ecs.get(&world, entity2, ecs.Position)
    testing.expect(t, pos2.x == 30 && pos2.y == 40, "Position data for entity2 should be unchanged after removing entity1's component")

    // 6. Clean up
    ecs.destroy_world(&world)
}

@(test)
test_query_collect :: proc(t: ^testing.T) {
    world: ecs.World
    ecs.create_component_pool(&world, ecs.Position)
    ecs.create_component_pool(&world, ecs.Velocity)

    // Entity 1: Has Position only
    e1 := ecs.make_entity(&world)
    ecs.add(&world, e1, ecs.Position{1, 1})

    // Entity 2: Has Position and Velocity
    e2 := ecs.make_entity(&world)
    ecs.add(&world, e2, ecs.Position{2, 2})
    ecs.add(&world, e2, ecs.Velocity{2, 2})

    // Entity 3: Has Position and Velocity
    e3 := ecs.make_entity(&world)
    ecs.add(&world, e3, ecs.Position{3, 3})
    ecs.add(&world, e3, ecs.Velocity{3, 3})

    // Collect entities with both components
    collected_entities := ecs.query_collect(&world, ecs.Position, ecs.Velocity)
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
    ecs.create_component_pool(&world, ecs.Position)

    // 1. Create and destroy an entity
    e1 := ecs.make_entity(&world)
    ecs.add(&world, e1, ecs.Position{1, 1})
    testing.expect(t, ecs.has(&world, e1, ecs.Position), "Entity should have component before being destroyed")

    ecs.destroy_entity(&world, e1)

    // 2. Create a new entity, which should reuse the index of e1
    e2 := ecs.make_entity(&world)

    // 3. The recycled entity has the same index but different generation
    testing.expect(t, ecs.entity_index(e1) == ecs.entity_index(e2), "New entity should reuse the index")
    testing.expect(t, e1 != e2, "New entity should not equal old entity (different generation)")
    testing.expect(t, !ecs.has(&world, e2, ecs.Position), "New entity should not have component from destroyed entity")

    // 4. Verify stale reference doesn't work
    testing.expect(t, !ecs.has(&world, e1, ecs.Position), "Stale reference should not have component")

    // Clean up
    ecs.destroy_world(&world)
}

@(test)
test_query_with_helper_functions :: proc(t: ^testing.T) {
    world: ecs.World
    ecs.create_component_pool(&world, ecs.Position)
    ecs.create_component_pool(&world, ecs.Velocity)

    // Create entities with both components
    e1 := ecs.make_entity(&world)
    ecs.add(&world, e1, ecs.Position{10, 20})
    ecs.add(&world, e1, ecs.Velocity{5, 3})

    e2 := ecs.make_entity(&world)
    ecs.add(&world, e2, ecs.Position{30, 40})
    ecs.add(&world, e2, ecs.Velocity{1, 2})

    // Test the new helper functions
    it := ecs.query(&world, ecs.Position, ecs.Velocity)

    // Get first entity
    entity, ok := ecs.next(it)
    testing.expect(t, ok, "Should get first entity")

    // Use helper functions to get components
    pos, pos_ok := ecs.get_from_query(it, entity, ecs.Position)
    vel, vel_ok := ecs.get_from_query(it, entity, ecs.Velocity)

    testing.expect(t, pos_ok, "Should get Position component")
    testing.expect(t, vel_ok, "Should get Velocity component")
    testing.expect(t, pos.x == 10 && pos.y == 20, "Position data should be correct")
    testing.expect(t, vel.dx == 5 && vel.dy == 3, "Velocity data should be correct")

    // Test that components are the right types (this will compile if types are correct)
    pos.x += vel.dx  // This should work if pos is ^Position and vel is ^Velocity
    pos.y += vel.dy

    testing.expect(t, pos.x == 15 && pos.y == 23, "Component modification should work")

    ecs.destroy_iterator(it)
    ecs.destroy_world(&world)
}


@(test)
  test_add_duplicate_overwrites :: proc(t: ^testing.T) {
      world: ecs.World
      ecs.create_component_pool(&world, ecs.Position)

      entity := ecs.make_entity(&world)
      ecs.add(&world, entity, ecs.Position{10, 20})
      ecs.add(&world, entity, ecs.Position{30, 40})

      // Should have overwritten, not duplicated
      pos, ok := ecs.get(&world, entity, ecs.Position)
      testing.expect(t, ok, "Should still have Position")
      testing.expect(t, pos.x == 30 && pos.y == 40, "Position should be overwritten to new value")   

      // Dense array should have exactly 1 entry, not 2
      base_pool := world.pools[ecs.Position]
      testing.expect_value(t, len(base_pool.owners), 1)

      ecs.destroy_world(&world)
  }

  @(test)
  test_unregistered_component_no_crash :: proc(t: ^testing.T) {
      world: ecs.World
      entity := ecs.make_entity(&world)

      // None of these should crash — Position pool was never created
      testing.expect(t, !ecs.has(&world, entity, ecs.Position), "has should return false")

      pos, ok := ecs.get(&world, entity, ecs.Position)
      testing.expect(t, !ok, "get should return false")
      testing.expect(t, pos == nil, "get should return nil")

      ecs.remove(&world, entity, ecs.Position)  // should be a no-op
      ecs.add(&world, entity, ecs.Position{1, 2})  // should be a no-op

      ecs.destroy_world(&world)
  }