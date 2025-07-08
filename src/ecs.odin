package ecs


EntityID :: distinct u64

MAX_ENTITIES :: 10_000

World :: struct {
    free_list: [dynamic]u64,
    next: u64,
}

destroy_world :: proc(world: ^World) {
    delete(world.free_list)
}

make_entity :: proc(world: ^World) -> EntityID {
    if len(world.free_list) > 0 {
        id := world.free_list[len(world.free_list) - 1]
        resize(&world.free_list, len(world.free_list) - 1)
        return EntityID(id)
    }
    world.next += 1
    return EntityID(world.next-1)
}

destroy_entity :: proc(world: ^World, entity: EntityID) {
    append(&world.free_list, u64(entity))
}

BaseComponentPool :: struct {
    owners: [dynamic]EntityID,
    sparse: [dynamic]i64,
}

ComponentPool :: struct($T: typeid) {
    using base: BaseComponentPool,
    dense:      [dynamic]T,
}

create_component_pool :: proc($T: typeid) -> ComponentPool(T) {
    sparse := make([dynamic]i64, MAX_ENTITIES)
    for i in 0..<MAX_ENTITIES {
        sparse[i] = -1
    }
    return ComponentPool(T){
        base = BaseComponentPool{
            owners = {},
            sparse = sparse,
        },
        dense = {},
    }
}

add :: proc(cp: ^ComponentPool($T), world: ^World, entity: EntityID, component: T) {
    idx := len(cp.dense)
    append(&cp.dense, component)
    append(&cp.base.owners, entity)
    cp.base.sparse[i64(entity)] = i64(idx)
}

has :: proc(cp: ^ComponentPool($T), entity: EntityID) -> bool {
    idx: i64 = -1
    if i64(entity) < i64(len(cp.base.sparse)) {
        idx = cp.base.sparse[i64(entity)]
    }
    return idx >= 0
}

get :: proc(cp: ^ComponentPool($T), entity: EntityID) -> ^T {
    idx := cp.base.sparse[i64(entity)]
    return &cp.dense[idx]
}

remove :: proc(cp: ^ComponentPool($T), entity: EntityID) {
    idx := cp.base.sparse[i64(entity)]
    last_idx := len(cp.dense) - 1

        if idx != i64(last_idx) {
        // Move the last element into the place of the one being removed
        moved_entity := cp.base.owners[last_idx]
        cp.dense[idx] = cp.dense[last_idx]
        cp.base.owners[idx] = moved_entity
        // Update the sparse array for the moved entity
        cp.base.sparse[i64(moved_entity)] = idx
    }

    // Shrink the arrays
    resize(&cp.dense, last_idx)
    resize(&cp.base.owners, last_idx)
    cp.base.sparse[i64(entity)] = -1
}

destroy_component_pool :: proc(cp: ^ComponentPool($T)) {
    delete(cp.dense)
    delete(cp.base.owners)
    delete(cp.base.sparse)
}

// --- Query System ---

QueryIterator :: struct {
    pools:             []^BaseComponentPool,
    source_pool_index: int,
    current_index:     int,
}

base_has :: proc(pool: ^BaseComponentPool, entity: EntityID) -> bool {
    idx: i64 = -1
    if i64(entity) < i64(len(pool.sparse)) {
        idx = pool.sparse[i64(entity)]
    }
    return idx >= 0
}

query :: proc "contextless" (world: ^World, pools: ..^BaseComponentPool) -> QueryIterator {
    source_pool_index := -1
    min_len := MAX_ENTITIES + 1

    for pool, i in pools {
        pool_len := len(pool.owners)
        if pool_len < min_len {
            min_len = pool_len
            source_pool_index = i
        }
    }

    return QueryIterator{
        pools             = pools,
        source_pool_index = source_pool_index,
        current_index     = -1,
    }
}

next :: proc(it: ^QueryIterator) -> (entity: EntityID, ok: bool) {
    if it.source_pool_index < 0 {
        return EntityID(~u64(0)), false
    }

    source_pool := it.pools[it.source_pool_index]

    for {
        it.current_index += 1
        if it.current_index >= len(source_pool.owners) {
            return EntityID(~u64(0)), false
        }

        entity_to_check := source_pool.owners[it.current_index]

        is_match := true
        for other_pool, j in it.pools {
            if j == it.source_pool_index {
                continue
            }
            if !base_has(other_pool, entity_to_check) {
                is_match = false
                break
            }
        }

        if is_match {
            return entity_to_check, true
        }
    }
}