package ecs


EntityID :: distinct u64

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

ComponentPool :: struct($T: typeid) {
    dense: [dynamic]T, // packed data
    owners: [dynamic]EntityID, // mirrors dense
    sparse: [dynamic]i64, // size == max_entities; -1 == empty
}

add :: proc(cp: ^ComponentPool($T), world: ^World, entity: EntityID, component: T) {
    idx := len(cp.dense)
    append(&cp.dense, component)
    append(&cp.owners, entity)
    if i64(entity) >= i64(len(cp.sparse)) {
        old_len := len(cp.sparse)
        new_len := int(i64(entity) + 1)
        resize(&cp.sparse, new_len)
        for i in old_len..<new_len {
            cp.sparse[i] = -1
        }
    }
    cp.sparse[i64(entity)] = i64(idx)
}

has :: proc(cp: ^ComponentPool($T), entity: EntityID) -> bool {
    idx: i64 = -1
    if i64(entity) < i64(len(cp.sparse)) {
        idx = cp.sparse[i64(entity)]
    }
    return idx >= 0
}

get :: proc(cp: ^ComponentPool($T), entity: EntityID) -> ^T {
    idx := cp.sparse[i64(entity)]
    return &cp.dense[idx]
}

remove :: proc(cp: ^ComponentPool($T), entity: EntityID) {
    idx := cp.sparse[i64(entity)]
    last := len(cp.dense)-1
    cp.dense[idx] = cp.dense[last]
    cp.owners[idx] = cp.owners[last]
    cp.sparse[i64(cp.owners[last])] = idx
    resize(&cp.dense, last)
    resize(&cp.owners, last)
    cp.sparse[i64(entity)] = -1
}

destroy_component_pool :: proc(cp: ^ComponentPool($T)) {
    delete(cp.dense)
    delete(cp.owners)
    delete(cp.sparse)
}

