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
    for _, pool in world.pools {
        if base_has(pool, entity) {
            // shrink dense array
            pool.remover(pool, entity)
            // shrink owners and sparse array
            base_remove(pool, entity)
        }
    }
    append(&world.free_list, u64(entity))
}

BaseComponentPool :: struct {
    owners: [dynamic]EntityID,
    sparse: [dynamic]i64,
    component_type: typeid,  // Store the component type for identification
    destroyer: proc(cp: ^BaseComponentPool),
    remover:   proc(pool: ^BaseComponentPool, entity: EntityID),
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
    remover := proc(pool: ^BaseComponentPool, entity: EntityID) {
        // shrink dense array
        cp := cast(^ComponentPool(T))pool
        
        idx := cp.base.sparse[i64(entity)]
        last_idx := len(cp.dense) - 1

        if idx != i64(last_idx) {
            cp.dense[idx] = cp.dense[last_idx]
        }
        resize(&cp.dense, last_idx)
    }

    component_pool := new(ComponentPool(T))
    component_pool.base = BaseComponentPool{
        owners = {},
        sparse = sparse,
        component_type = T,  // Set the component type
        destroyer = destroyer,
        remover = remover,
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

get :: #force_inline proc(world: ^World, entity: EntityID, $T: typeid) -> (component: ^T, ok: bool) {
    base_pool_ptr := world.pools[T]
    cp := cast(^ComponentPool(T))base_pool_ptr
    idx := cp.base.sparse[i64(entity)]
    
    // Minimal bounds check - faster than calling has()
    if idx < 0 || idx >= i64(len(cp.dense)) {
        return nil, false
    }
    
    return &cp.dense[idx], true
}

remove :: #force_inline proc(world: ^World, entity: EntityID, $T: typeid) {
    base_pool_ptr := world.pools[T]
    cp := cast(^ComponentPool(T))base_pool_ptr
    idx := cp.base.sparse[i64(entity)]
    
    // Minimal bounds check - faster than calling has()
    if idx < 0 || idx >= i64(len(cp.dense)) {
        return
    }
    
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

base_has :: #force_inline proc(pool: ^BaseComponentPool, entity: EntityID) -> bool {
    idx: i64 = -1
    if i64(entity) < i64(len(pool.sparse)) {
        idx = pool.sparse[i64(entity)]
    }
    return idx >= 0
}

base_remove :: proc(pool: ^BaseComponentPool, entity: EntityID) {
    idx := pool.sparse[i64(entity)]
    last_idx := len(pool.owners) - 1

    if idx != i64(last_idx) {
        // Move the last element into the place of the one being removed
        moved_entity := pool.owners[last_idx]
        pool.owners[idx] = moved_entity
        // Update the sparse array for the moved entity
        pool.sparse[i64(moved_entity)] = idx
    }

    // Shrink the arrays
    resize(&pool.owners, last_idx)
    pool.sparse[i64(entity)] = -1
}

// --- Unified Query System ---

QueryIterator :: struct {
    pools:             [dynamic]^BaseComponentPool,
    source_pool_index: int,
    current_index:     int,
}

// Create a query iterator for entities with specific components
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

// Iterate through entities in the query
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
            // Optimized: Since entity_to_check exists in source_pool, 
            // we know it's within bounds, so we can skip bounds checking
            idx := other_pool.sparse[i64(entity_to_check)]
            if idx < 0 {
                is_match = false
                break
            }
        }

        if is_match {
            return entity_to_check, true
        }
    }
}

// Helper function to find which pool index a component type is in
find_pool_index :: proc(it: ^QueryIterator, $T: typeid) -> int {
    for i in 0..<len(it.pools) {
        // Check if this pool matches the component type
        if it.pools[i].component_type == T {
            return i
        }
    }
    return -1
}

// Get component directly from a query iterator (no map lookups - much faster!)
get_from_query :: proc(it: ^QueryIterator, entity: EntityID, $T: typeid) -> (component: ^T, ok: bool) {
    pool_index := find_pool_index(it, T)
    if pool_index < 0 {
        return nil, false
    }
    
    // Cast the pool to the right type
    pool := cast(^ComponentPool(T))it.pools[pool_index]
    
    // Get the component using fast access (no bounds checking needed since we're iterating)
    idx := pool.base.sparse[i64(entity)]
    if idx < 0 || idx >= i64(len(pool.dense)) {
        return nil, false
    }
    
    return &pool.dense[idx], true
}

// Clean up query iterator
destroy_iterator :: proc(it: ^QueryIterator) {
    if it == nil {
        return
    }
    delete(it.pools)
    free(it)
}

// Collect all entities with specific components
query_collect :: proc(world: ^World, components: ..typeid) -> [dynamic]EntityID {
    it := query(world, ..components)
    entities := make([dynamic]EntityID)
    for {
        entity, ok := next(it)
        if !ok {
            break
        }
        append(&entities, entity)
    }
    destroy_iterator(it)
    return entities
}