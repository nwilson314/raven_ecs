package ecs


EntityID :: distinct u64

MAX_ENTITIES :: 100_000

World :: struct {
    free_list: [dynamic]u64,
    next: u64,
    pools: map[typeid]^BaseComponentPool,
}

destroy_world :: proc(world: ^World) {
    for _, pool in world.pools {
        pool.destroyer(pool)
    }
    delete(world.pools)
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
    destroyer: proc(cp: ^BaseComponentPool),
}

ComponentPool :: struct($T: typeid) {
    using base: BaseComponentPool,
    dense:      [dynamic]T,
}

create_component_pool :: proc(world: ^World, $T: typeid) -> ^ComponentPool(T) {
    sparse := make([dynamic]i64, MAX_ENTITIES)
    for i in 0..<MAX_ENTITIES {
        sparse[i] = -1
    }

    destroyer := proc(cp: ^BaseComponentPool) {
        pool := cast(^ComponentPool(T))cp
        delete(pool.dense)
        delete(pool.base.owners)
        delete(pool.base.sparse)
        free(pool)
    }
    component_pool := new(ComponentPool(T))
    component_pool.base = BaseComponentPool{
        owners = {},
        sparse = sparse,
        destroyer = destroyer,
    }

    register_component_pool(world, component_pool)

    return component_pool
}

register_component_pool :: proc(world: ^World, cp: ^ComponentPool($T)) {
    world.pools[T] = &cp.base
}

add :: proc(world: ^World, entity: EntityID, component: $T) {
    base_pool_ptr := world.pools[T]
    cp := cast(^ComponentPool(T))base_pool_ptr
    idx := len(cp.dense)
    append(&cp.dense, component)
    append(&cp.base.owners, entity)
    cp.base.sparse[i64(entity)] = i64(idx)
}

has :: proc(world: ^World, entity: EntityID, $T: typeid) -> bool {
    base_pool_ptr, ok := world.pools[T]
    if !ok {
        return false
    }
    cp := cast(^ComponentPool(T))base_pool_ptr
    idx: i64 = -1
    if i64(entity) < i64(len(cp.base.sparse)) {
        idx = cp.base.sparse[i64(entity)]
    }
    return idx >= 0
}

get :: proc(world: ^World, entity: EntityID, $T: typeid) -> ^T {
    base_pool_ptr := world.pools[T]
    cp := cast(^ComponentPool(T))base_pool_ptr
    idx := cp.base.sparse[i64(entity)]
    return &cp.dense[idx]
}

remove :: proc(world: ^World, entity: EntityID, $T: typeid) {
    base_pool_ptr := world.pools[T]
    cp := cast(^ComponentPool(T))base_pool_ptr
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
    pools:             [dynamic]^BaseComponentPool,
    source_pool_index: int,
    current_index:     int,
}

destroy_iterator :: proc(it: ^QueryIterator) {
    if it == nil {
        return
    }

    delete(it.pools)
    free(it)
}

base_has :: #force_inline proc(pool: ^BaseComponentPool, entity: EntityID) -> bool {
    idx: i64 = -1
    if i64(entity) < i64(len(pool.sparse)) {
        idx = pool.sparse[i64(entity)]
    }
    return idx >= 0
}

query :: proc(world: ^World, components: ..typeid) -> ^QueryIterator {
    it := new(QueryIterator)
    it.current_index = -1
    it.pools = make([dynamic]^BaseComponentPool)
    it.source_pool_index = -1

    min_len := MAX_ENTITIES + 1
    
    for component_type, i in components {
        pool, ok := world.pools[component_type]

        if !ok {
            return it
        }

        append(&it.pools, pool)

        pool_len := len(pool.owners) 
        if pool_len < min_len {
            min_len = pool_len
            it.source_pool_index = i
        }
    }

    return it
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