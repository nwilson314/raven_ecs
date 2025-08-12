package main

import "core:testing"
import "core:time"
import "core:log"
import ecs "../src"

// Component definitions for benchmarking
Position :: struct {
    x, y: f32
}

Velocity :: struct {
    dx, dy: f32
}

Health :: struct {
    current: f32,
    max: f32,
}

@(test)
test_query_api_performance :: proc(t: ^testing.T) {
    world: ecs.World
    ecs.create_component_pool(&world, Position)
    ecs.create_component_pool(&world, Velocity)
    ecs.create_component_pool(&world, Health)

    BENCH_N :: 100_000
    UPDATE_FRAMES :: 60

    log.infof("Setting up %v entities...", BENCH_N)
    
    // Setup phase - not timed
    for i in 0..<BENCH_N {
        entity := ecs.make_entity(&world)
        ecs.add(&world, entity, Position{f32(i), f32(i)})
        ecs.add(&world, entity, Velocity{1, 1})
        ecs.add(&world, entity, Health{100, 100})
    }

    log.infof("Running query API benchmark for %v frames...", UPDATE_FRAMES)

    start_time := time.tick_now()

    // This is what users will actually write - the clean query API
    for _ in 0..<UPDATE_FRAMES {
        it := ecs.query(&world, Position, Velocity, Health)
        
        for {
            entity, ok := ecs.next(it)
            if !ok {
                ecs.destroy_iterator(it)
                break
            }

            // Simulate real usage - get components and do work
            pos, pos_ok := ecs.get(&world, entity, Position)
            vel, vel_ok := ecs.get(&world, entity, Velocity)
            health, health_ok := ecs.get(&world, entity, Health)
            
            if pos_ok && vel_ok && health_ok {
                // Simulate physics update
                pos.x += vel.dx * 0.016  // 60 FPS delta time
                pos.y += vel.dy * 0.016
                
                // Simulate health decay
                health.current -= 0.1
                if health.current < 0 {
                    health.current = 0
                }
            }
        }
    }

    end_time := time.tick_now()
    duration := time.tick_diff(start_time, end_time)
    avg_ms := time.duration_microseconds(duration) / f64(UPDATE_FRAMES) / 1000.0

    log.infof("Total time for %v frames: %v", UPDATE_FRAMES, duration)
    log.infof("Average update time per frame: %.4f ms", avg_ms)
    log.infof("Entities processed per frame: %v", BENCH_N)
    log.infof("Performance: %.2f entities per millisecond", f64(BENCH_N) / avg_ms)

    // According to our roadmap, we want this to be under 1ms
    testing.expect(t, avg_ms < 1.0, "Average update time should be less than 1.0 ms")

    // Clean up
    ecs.destroy_world(&world)
}

@(test)
test_query_performance_with_component_access :: proc(t: ^testing.T) {
    world: ecs.World
    ecs.create_component_pool(&world, Position)
    ecs.create_component_pool(&world, Velocity)

    BENCH_N :: 50_000
    UPDATE_FRAMES :: 30

    log.infof("Setting up %v entities for performance test...", BENCH_N)
    
    // Setup phase
    for i in 0..<BENCH_N {
        entity := ecs.make_entity(&world)
        ecs.add(&world, entity, Position{f32(i), f32(i)})
        ecs.add(&world, entity, Velocity{1, 1})
    }

    log.infof("Running query with component access benchmark...")
    
    // Test query performance with component access
    start_time := time.tick_now()
    for _ in 0..<UPDATE_FRAMES {
        it := ecs.query(&world, Position, Velocity)
        for {
            entity, ok := ecs.next(it)
            if !ok {
                ecs.destroy_iterator(it)
                break
            }
            
            // Test both ways of getting components
            if pos, pos_ok := ecs.get(&world, entity, Position); pos_ok {
                if vel, vel_ok := ecs.get(&world, entity, Velocity); vel_ok {
                    // Simulate work
                    pos.x += vel.dx * 0.016
                    pos.y += vel.dy * 0.016
                }
            }
        }
    }
    regular_time := time.tick_diff(start_time, time.tick_now())
    
    log.infof("Running query with get_from_query benchmark...")
    
    // Test query performance with get_from_query
    start_time = time.tick_now()
    for _ in 0..<UPDATE_FRAMES {
        it := ecs.query(&world, Position, Velocity)
        for {
            entity, ok := ecs.next(it)
            if !ok {
                ecs.destroy_iterator(it)
                break
            }
            
            // Use get_from_query for better performance
            if pos, pos_ok := ecs.get_from_query(it, entity, Position); pos_ok {
                if vel, vel_ok := ecs.get_from_query(it, entity, Velocity); vel_ok {
                    // Simulate work
                    pos.x += vel.dx * 0.016
                    pos.y += vel.dy * 0.016
                }
            }
        }
    }
    optimized_time := time.tick_diff(start_time, time.tick_now())
    
    regular_avg := time.duration_microseconds(regular_time) / f64(UPDATE_FRAMES) / 1000.0
    optimized_avg := time.duration_microseconds(optimized_time) / f64(UPDATE_FRAMES) / 1000.0
    
    log.infof("Regular get: %.4f ms per frame", regular_avg)
    log.infof("get_from_query: %.4f ms per frame", optimized_avg)
    log.infof("Performance ratio: %.2fx faster", regular_avg / optimized_avg)
    
    // Clean up
    ecs.destroy_world(&world)
} 