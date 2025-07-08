package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import ecs "../src/"

BENCH_N :: 10_000

Transform :: struct {
    x, y: f32
}

Color :: struct {
    r, g, b, a: u8
}

spawn_dots :: proc(world: ^ecs.World, transform_pool: ^ecs.ComponentPool(Transform), color_pool: ^ecs.ComponentPool(Color), n: int) {
    for i in 0..<n {
        entity := ecs.make_entity(world)
        ecs.add(transform_pool, world, entity, Transform{f32(rl.GetRandomValue(0, 800)), f32(rl.GetRandomValue(0, 600))})
        ecs.add(color_pool, world, entity, Color{u8(rl.GetRandomValue(0, 255)), u8(rl.GetRandomValue(0, 255)), u8(rl.GetRandomValue(0, 255)), 255})
    }
}

main :: proc() {
    rl.InitWindow(800, 600, "Raven ECS")

    world := ecs.World{}
    transform_pool := ecs.create_component_pool(Transform)
    color_pool := ecs.create_component_pool(Color)

    spawn_dots(&world, &transform_pool, &color_pool, BENCH_N)

    for !rl.WindowShouldClose() {
        if rl.IsKeyPressed(.SPACE) {
            rl.TakeScreenshot("sprint1_bench.png")
        }
        if rl.IsMouseButtonPressed(.LEFT) {
            for i in 0 ..< len(color_pool.dense) {
                color := &color_pool.dense[i]
                color.r = u8(rl.GetRandomValue(0, 255))
                color.g = u8(rl.GetRandomValue(0, 255))
                color.b = u8(rl.GetRandomValue(0, 255))
            }
            fmt.println("Colors changed")
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        it := ecs.query(&world, &transform_pool.base, &color_pool.base)
        for {
            entity, ok := ecs.next(&it)
            if !ok {
                break
            }

            transform := ecs.get(&transform_pool, entity)
            color := ecs.get(&color_pool, entity)
            rl.DrawCircle(i32(transform.x), i32(transform.y), 10, rl.Color{color.r, color.g, color.b, color.a})
        }
        fps := rl.GetFPS()
        fps_text := strings.clone_to_cstring(fmt.tprintf("FPS: %d", fps))
        text_size := rl.MeasureText(fps_text, 20)
        rl.DrawRectangle(5, 5, text_size + 10, 30, rl.WHITE)
        rl.DrawText(fps_text, 10, 10, 20, rl.BLACK)
        rl.EndDrawing()
    }
    rl.CloseWindow()
    ecs.destroy_world(&world)
    ecs.destroy_component_pool(&transform_pool)
    ecs.destroy_component_pool(&color_pool)
}