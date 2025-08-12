package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import ecs "../src/"

BENCH_N :: 20_000

Transform :: struct {
    x, y: f32
}

Color :: struct {
    r, g, b, a: u8
}

spawn_dots :: proc(world: ^ecs.World, n: int) {
    for _ in 0..<n {
        entity := ecs.make_entity(world)
        ecs.add(world, entity, Transform{f32(rl.GetRandomValue(0, 800)), f32(rl.GetRandomValue(0, 600))})
        ecs.add(world, entity, Color{u8(rl.GetRandomValue(0, 255)), u8(rl.GetRandomValue(0, 255)), u8(rl.GetRandomValue(0, 255)), 255})
    }
}

main :: proc() {
    rl.InitWindow(800, 600, "Raven ECS")

    world := ecs.World{}
    ecs.create_component_pool(&world, Transform)
    color_pool := ecs.create_component_pool(&world, Color)

    spawn_dots(&world, BENCH_N)

    for !rl.WindowShouldClose() {
        if rl.IsKeyPressed(.SPACE) {
            rl.TakeScreenshot("sprint1_bench.png")
        }
        if rl.IsMouseButtonPressed(.LEFT) {
            for i in 0 ..< len(color_pool.dense) {
                color, ok := ecs.get(&world, ecs.EntityID(i), Color)
                if !ok {
                    continue
                }
                color.r = u8(rl.GetRandomValue(0, 255))
                color.g = u8(rl.GetRandomValue(0, 255))
                color.b = u8(rl.GetRandomValue(0, 255))
            }
            fmt.println("Colors changed")
        }
        it := ecs.query(&world, Transform, Color)
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        for {
            entity, ok := ecs.next(it)
            if !ok {
                ecs.destroy_iterator(it)
                break
            }

            transform, ok_transform := ecs.get(&world, entity, Transform)
            color, ok_color := ecs.get(&world, entity, Color)
            if ok_transform && ok_color {
                rl.DrawCircle(i32(transform.x), i32(transform.y), 10, rl.Color{color.r, color.g, color.b, color.a})
            }
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
}