package main

import "core:testing"
import "core:time"
import "core:log"
import ecs "../src"

// All benchmarks use the same components, frame count, and work per entity.
// Only one variable changes at a time.

BENCH_FRAMES :: 60

Position :: struct {
	x, y: f32,
}

Velocity :: struct {
	dx, dy: f32,
}

Health :: struct {
	current, max: f32,
}

// Helper: create N entities with Position + Velocity
setup_world_2c :: proc(world: ^ecs.World, n: int) {
	ecs.create_component_pool(world, Position)
	ecs.create_component_pool(world, Velocity)
	for i in 0..<n {
		entity := ecs.make_entity(world)
		ecs.add(world, entity, Position{f32(i), f32(i)})
		ecs.add(world, entity, Velocity{1, 1})
	}
}

// Helper: run iteration + get_from_query with real work
run_get_from_query :: proc(world: ^ecs.World, frames: int) -> f64 {
	start := time.tick_now()
	for _ in 0..<frames {
		it := ecs.query(world, Position, Velocity)
		for {
			entity, ok := ecs.next(it)
			if !ok {
				ecs.destroy_iterator(it)
				break
			}
			pos, pos_ok := ecs.get_from_query(it, entity, Position)
			vel, vel_ok := ecs.get_from_query(it, entity, Velocity)
			if pos_ok && vel_ok {
				pos.x += vel.dx * 0.016
				pos.y += vel.dy * 0.016
			}
		}
	}
	duration := time.tick_diff(start, time.tick_now())
	return time.duration_microseconds(duration) / f64(frames) / 1000.0
}

// Helper: run iteration + get (map lookup) with real work
run_get :: proc(world: ^ecs.World, frames: int) -> f64 {
	start := time.tick_now()
	for _ in 0..<frames {
		it := ecs.query(world, Position, Velocity)
		for {
			entity, ok := ecs.next(it)
			if !ok {
				ecs.destroy_iterator(it)
				break
			}
			pos, pos_ok := ecs.get(world, entity, Position)
			vel, vel_ok := ecs.get(world, entity, Velocity)
			if pos_ok && vel_ok {
				pos.x += vel.dx * 0.016
				pos.y += vel.dy * 0.016
			}
		}
	}
	duration := time.tick_diff(start, time.tick_now())
	return time.duration_microseconds(duration) / f64(frames) / 1000.0
}

// --- Benchmark 1: get_from_query vs get (same entity count, same work) ---

@(test)
bench_get_from_query_vs_get_100k :: proc(t: ^testing.T) {
	N :: 100_000

	world1: ecs.World
	setup_world_2c(&world1, N)
	defer ecs.destroy_world(&world1)

	world2: ecs.World
	setup_world_2c(&world2, N)
	defer ecs.destroy_world(&world2)

	fast_ms := run_get_from_query(&world1, BENCH_FRAMES)
	slow_ms := run_get(&world2, BENCH_FRAMES)

	log.infof("[%vk entities, 2 components, %v frames]", N / 1000, BENCH_FRAMES)
	log.infof("  get_from_query: %.4f ms/frame", fast_ms)
	log.infof("  get:            %.4f ms/frame", slow_ms)
	log.infof("  ratio:          %.2fx", slow_ms / fast_ms)
}

// --- Benchmark 2: Scaling — same test at 10k, 50k, 100k ---

@(test)
bench_scaling_get_from_query :: proc(t: ^testing.T) {
	sizes := [?]int{10_000, 50_000, 100_000}

	log.infof("[get_from_query scaling, 2 components, %v frames]", BENCH_FRAMES)
	for n in sizes {
		world: ecs.World
		setup_world_2c(&world, n)
		ms := run_get_from_query(&world, BENCH_FRAMES)
		log.infof("  %6vk entities: %.4f ms/frame (%.0f entities/ms)", n / 1000, ms, f64(n) / ms)
		ecs.destroy_world(&world)
	}
}

// --- Benchmark 3: Pure iteration (no component access) ---

@(test)
bench_pure_iteration_100k :: proc(t: ^testing.T) {
	N :: 100_000

	world: ecs.World
	setup_world_2c(&world, N)
	defer ecs.destroy_world(&world)

	count := 0
	start := time.tick_now()
	for _ in 0..<BENCH_FRAMES {
		it := ecs.query(&world, Position, Velocity)
		for {
			_, ok := ecs.next(it)
			if !ok {
				ecs.destroy_iterator(it)
				break
			}
			count += 1
		}
	}
	duration := time.tick_diff(start, time.tick_now())
	avg_ms := time.duration_microseconds(duration) / f64(BENCH_FRAMES) / 1000.0

	log.infof("[pure iteration, %vk entities, 2 components, %v frames]", N / 1000, BENCH_FRAMES)
	log.infof("  %.4f ms/frame (%v entities visited)", avg_ms, count)
}

// --- Benchmark 4: Add/remove throughput ---

@(test)
bench_add_remove_100k :: proc(t: ^testing.T) {
	N :: 100_000

	world: ecs.World
	ecs.create_component_pool(&world, Position)
	ecs.create_component_pool(&world, Velocity)
	defer ecs.destroy_world(&world)

	entities := make([dynamic]ecs.EntityID, N)
	defer delete(entities)
	for i in 0..<N {
		entities[i] = ecs.make_entity(&world)
	}

	start := time.tick_now()

	for entity in entities {
		ecs.add(&world, entity, Position{1, 1})
		ecs.add(&world, entity, Velocity{1, 1})
	}
	for entity in entities {
		ecs.remove(&world, entity, Position)
		ecs.remove(&world, entity, Velocity)
	}

	duration := time.tick_diff(start, time.tick_now())
	total_ms := time.duration_microseconds(duration) / 1000.0

	log.infof("[add+remove, %vk entities, 2 components]", N / 1000)
	log.infof("  total: %.4f ms", total_ms)
	log.infof("  per entity (add+remove both): %.4f µs", total_ms * 1000.0 / f64(N))
}
