#ifndef SPS_DEBUG_DIRECT_SCAN_INCLUDED
#define SPS_DEBUG_DIRECT_SCAN_INCLUDED

#include "Packages/com.vrcfury.vrcfury/SPS/common/sps_cell_layout.cginc"

#define SPS_DEBUG_PRODUCT_ANY 0u
#define SPS_DEBUG_PRODUCT_SOCKET 1u
#define SPS_DEBUG_PRODUCT_PLUG 2u
#define SPS_DEBUG_DIRECT_MAX_RESULTS 256u

struct SpsDebugDirectCursor {
    uint valid;
    uint distanceKey;
    uint product;
};

void sps_debug_direct_reset(out SpsDebugDirectCursor cursor) {
    cursor.valid = 0u;
    cursor.distanceKey = 0u;
    cursor.product = 0u;
}

bool sps_debug_direct_key_after(uint distanceKey, uint product, SpsDebugDirectCursor cursor) {
    if (cursor.valid == 0u) return true;
    if (distanceKey != cursor.distanceKey) return distanceKey > cursor.distanceKey;
    return product > cursor.product;
}

bool sps_debug_direct_key_before(
    uint distanceKey,
    uint product,
    uint slot,
    uint bestDistanceKey,
    uint bestProduct,
    uint bestSlot
) {
    if (distanceKey != bestDistanceKey) return distanceKey < bestDistanceKey;
    if (product != bestProduct) return product < bestProduct;
    return slot < bestSlot;
}

bool sps_debug_direct_candidate(
    SpsTexture tex,
    uint slot,
    uint productFilter,
    float3 originWorld,
    out uint product,
    out float3 world,
    out uint distanceKey
) {
    product = 0u;
    world = 0.0;
    distanceKey = 0u;

    SpsCell cell = sps_get_cell(tex, (int)slot);
    if (!sps_cell_check_magic(cell)) return false;
    if (cell.read_uint(SPS_HEADER_VENDOR_INDEX) != SPS_VENDOR_SPS) return false;

    product = cell.read_uint(SPS_HEADER_PRODUCT_INDEX);
    if (product != SPS_DEBUG_PRODUCT_SOCKET && product != SPS_DEBUG_PRODUCT_PLUG) return false;
    if (productFilter != SPS_DEBUG_PRODUCT_ANY && product != productFilter) return false;

    world = sps_cell_header_world(cell);
    if (!all(world == world) || any(abs(world) > 1000000.0)) return false;

    float3 delta = world - originWorld;
    float distanceSquared = max(dot(delta, delta), 0.0);
    distanceKey = asuint(distanceSquared);
    return true;
}

bool sps_debug_direct_next(
    SpsTexture tex,
    uint productFilter,
    float3 originWorld,
    SpsDebugDirectCursor cursor,
    out uint selectedSlot,
    out uint selectedProduct,
    out float3 selectedWorld,
    out uint selectedDistanceKey
) {
    selectedSlot = 0u;
    selectedProduct = 0u;
    selectedWorld = 0.0;
    selectedDistanceKey = 0u;

    bool found = false;
    uint slotCount = sps_socket_slot_count();
    [loop]
    for (uint slot = 0u; slot < SPS_SOCKET_MAX_SLOTS; slot++) {
        if (slot >= slotCount) break;

        uint product;
        float3 world;
        uint distanceKey;
        if (!sps_debug_direct_candidate(tex, slot, productFilter, originWorld, product, world, distanceKey)) continue;
        if (!sps_debug_direct_key_after(distanceKey, product, cursor)) continue;
        if (found && !sps_debug_direct_key_before(
            distanceKey,
            product,
            slot,
            selectedDistanceKey,
            selectedProduct,
            selectedSlot
        )) continue;

        found = true;
        selectedSlot = slot;
        selectedProduct = product;
        selectedWorld = world;
        selectedDistanceKey = distanceKey;
    }
    return found;
}

void sps_debug_direct_advance(
    inout SpsDebugDirectCursor cursor,
    uint distanceKey,
    uint product
) {
    cursor.valid = 1u;
    cursor.distanceKey = distanceKey;
    cursor.product = product;
}

uint sps_debug_direct_count(
    SpsTexture tex,
    uint productFilter,
    float3 originWorld,
    uint resultLimit
) {
    resultLimit = min(max(resultLimit, 1u), SPS_DEBUG_DIRECT_MAX_RESULTS);
    SpsDebugDirectCursor cursor;
    sps_debug_direct_reset(cursor);

    uint count = 0u;
    [loop]
    for (uint resultIndex = 0u; resultIndex < SPS_DEBUG_DIRECT_MAX_RESULTS; resultIndex++) {
        if (resultIndex >= resultLimit) break;

        uint slot;
        uint product;
        float3 world;
        uint distanceKey;
        if (!sps_debug_direct_next(tex, productFilter, originWorld, cursor, slot, product, world, distanceKey)) break;
        sps_debug_direct_advance(cursor, distanceKey, product);
        count++;
    }
    return count;
}

bool sps_debug_direct_select(
    SpsTexture tex,
    uint productFilter,
    float3 originWorld,
    uint wantedIndex,
    uint resultLimit,
    out uint selectedSlot,
    out uint selectedProduct,
    out float3 selectedWorld,
    out uint selectedDistanceKey
) {
    selectedSlot = 0u;
    selectedProduct = 0u;
    selectedWorld = 0.0;
    selectedDistanceKey = 0u;
    resultLimit = min(max(resultLimit, 1u), SPS_DEBUG_DIRECT_MAX_RESULTS);
    if (wantedIndex >= resultLimit) return false;

    SpsDebugDirectCursor cursor;
    sps_debug_direct_reset(cursor);
    [loop]
    for (uint resultIndex = 0u; resultIndex < SPS_DEBUG_DIRECT_MAX_RESULTS; resultIndex++) {
        if (resultIndex >= resultLimit || resultIndex > wantedIndex) break;
        if (!sps_debug_direct_next(
            tex,
            productFilter,
            originWorld,
            cursor,
            selectedSlot,
            selectedProduct,
            selectedWorld,
            selectedDistanceKey
        )) return false;
        sps_debug_direct_advance(cursor, selectedDistanceKey, selectedProduct);
        if (resultIndex == wantedIndex) return true;
    }
    return false;
}

#endif
