package main

import "core:testing"
import "core:time"
import "core:log"
import ecs "../src"

Player :: struct {
	
}

@(test)
test_100k_entities_update :: proc(t: ^testing.T) {
	world: ecs.World
	ecs.create_component_pool(&world, ecs.Position)
	ecs.create_component_pool(&world, ecs.Velocity)
	ecs.create_component_pool(&world, Player)

	BENCH_N :: 100_000

	log.infof("Setting up %v entities...", BENCH_N)
	for i in 0..<BENCH_N {
		entity := ecs.make_entity(&world)
		ecs.add(&world, entity, ecs.Position{f32(i), f32(i)})
		ecs.add(&world, entity, ecs.Velocity{1, 1})
	}

	UPDATE_FRAMES :: 60
	log.infof("Running update loop for %v frames...", UPDATE_FRAMES)

	start_time := time.tick_now()

	for _ in 0..<UPDATE_FRAMES {
		// Use unified query (now fast by default)
		it := ecs.query(&world, ecs.Position, ecs.Velocity)
		
		for {
			entity, ok := ecs.next(it)
			if !ok {
				ecs.destroy_iterator(it)
				break
			}

			// Use the new helper function - no manual casting needed!
			pos, pos_ok := ecs.get_from_query(it, entity, ecs.Position)
			vel, vel_ok := ecs.get_from_query(it, entity, ecs.Velocity)
			
			// The components are already the right types
			if pos_ok && vel_ok {
				// This will compile and work correctly
				_ = pos.x  // pos is already ^Position
				_ = vel.dx // vel is already ^Velocity
			}
		}
	}

	end_time := time.tick_now()
	duration := time.tick_diff(start_time, end_time)
	avg_ms := time.duration_microseconds(duration) / f64(UPDATE_FRAMES) / 1000.0

	log.infof("Total time for %v frames: %v", UPDATE_FRAMES, duration)
	log.infof("Average update time per frame: %.4f ms", avg_ms)

	// According to our roadmap, we want this to be under 1ms
	testing.expect(t, avg_ms < 1.0, "Average update time should be less than 1.0 ms")

	// Clean up
	ecs.destroy_world(&world)
}

@(test)
test_10k_entities_add_remove :: proc(t: ^testing.T) {
	world: ecs.World
	ecs.create_component_pool(&world, ecs.Position)
	ecs.create_component_pool(&world, ecs.Velocity)

	BENCH_N :: 10_000

	log.infof("Setting up %v entities for add/remove test...", BENCH_N)
	entities := make([dynamic]ecs.EntityID, BENCH_N)
	defer delete(entities)

	for i in 0..<BENCH_N {
		entities[i] = ecs.make_entity(&world)
	}

	log.infof("Running add/remove benchmark for %v entities...", BENCH_N)

	start_time := time.tick_now()

	// Add components
	for entity in entities {
		ecs.add(&world, entity, ecs.Position{1, 1})
		ecs.add(&world, entity, ecs.Velocity{1, 1})
	}

	// Remove components
	for entity in entities {
		ecs.remove(&world, entity, ecs.Position)
		ecs.remove(&world, entity, ecs.Velocity)
	}

	end_time := time.tick_now()
	duration := time.tick_diff(start_time, end_time)

	log.infof("Total time for %v entity add/removes: %v", BENCH_N, duration)

	// Clean up
	ecs.destroy_world(&world)
}
