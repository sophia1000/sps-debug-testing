#ifndef SPS_DEBUG_DIRECT_SCAN_INCLUDED
#define SPS_DEBUG_DIRECT_SCAN_INCLUDED

#include "Packages/com.vrcfury.vrcfury/SPS/common/sps_cell_layout.cginc"

#define SPS_DEBUG_PRODUCT_ANY 0u
#define SPS_DEBUG_PRODUCT_SOCKET 1u
#define SPS_DEBUG_PRODUCT_PLUG 2u
#ifndef SPS_DEBUG_DIRECT_MAX_RESULTS
    #define SPS_DEBUG_DIRECT_MAX_RESULTS 128
#endif

struct SpsDebugDirectRecord {
    uint slot;
    uint product;
    uint distanceKey;
    float3 world;
};

bool sps_debug_direct_key_before(
    uint distanceKey,
    uint product,
    uint slot,
    SpsDebugDirectRecord other
) {
    if (distanceKey != other.distanceKey) return distanceKey < other.distanceKey;
    if (product != other.product) return product < other.product;
    return slot < other.slot;
}

bool sps_debug_direct_candidate(
    SpsTexture tex,
    uint slot,
    uint productFilter,
    float3 originWorld,
    out SpsDebugDirectRecord record
) {
    record.slot = slot;
    record.product = 0u;
    record.distanceKey = 0u;
    record.world = 0.0;

    SpsCell cell = sps_get_cell(tex, (int)slot);
    if (!sps_cell_check_magic(cell)) return false;
    if (cell.read_uint(SPS_HEADER_VENDOR_INDEX) != SPS_VENDOR_SPS) return false;

    record.product = cell.read_uint(SPS_HEADER_PRODUCT_INDEX);
    if (record.product != SPS_DEBUG_PRODUCT_SOCKET && record.product != SPS_DEBUG_PRODUCT_PLUG) return false;
    if (productFilter != SPS_DEBUG_PRODUCT_ANY && record.product != productFilter) return false;

    record.world = sps_cell_header_world(cell);
    if (!all(record.world == record.world) || any(abs(record.world) > 1000000.0)) return false;

    float3 delta = record.world - originWorld;
    float distanceSquared = max(dot(delta, delta), 0.0);
    record.distanceKey = asuint(distanceSquared);
    return true;
}

bool sps_debug_direct_duplicate(
    SpsDebugDirectRecord candidate,
    SpsDebugDirectRecord records[SPS_DEBUG_DIRECT_MAX_RESULTS],
    uint count
) {
    [loop]
    for (uint i = 0u; i < SPS_DEBUG_DIRECT_MAX_RESULTS; i++) {
        if (i >= count) break;
        if (records[i].product == candidate.product && records[i].distanceKey == candidate.distanceKey) return true;
    }
    return false;
}

uint sps_debug_direct_collect(
    SpsTexture tex,
    uint productFilter,
    float3 originWorld,
    uint resultLimit,
    out SpsDebugDirectRecord records[SPS_DEBUG_DIRECT_MAX_RESULTS]
) {
    resultLimit = min(max(resultLimit, 1u), (uint)SPS_DEBUG_DIRECT_MAX_RESULTS);
    uint count = 0u;
    uint slotCount = sps_socket_slot_count();

    [loop]
    for (uint clearIndex = 0u; clearIndex < SPS_DEBUG_DIRECT_MAX_RESULTS; clearIndex++) {
        records[clearIndex].slot = 0u;
        records[clearIndex].product = 0u;
        records[clearIndex].distanceKey = 0u;
        records[clearIndex].world = 0.0;
    }

    [loop]
    for (uint slot = 0u; slot < SPS_SOCKET_MAX_SLOTS; slot++) {
        if (slot >= slotCount) break;

        SpsDebugDirectRecord candidate;
        if (!sps_debug_direct_candidate(tex, slot, productFilter, originWorld, candidate)) continue;
        if (sps_debug_direct_duplicate(candidate, records, count)) continue;

        uint insertIndex = count;
        [loop]
        while (insertIndex > 0u) {
            uint previousIndex = insertIndex - 1u;
            if (!sps_debug_direct_key_before(
                candidate.distanceKey,
                candidate.product,
                candidate.slot,
                records[previousIndex]
            )) break;

            if (insertIndex < resultLimit) records[insertIndex] = records[previousIndex];
            insertIndex = previousIndex;
        }

        if (insertIndex < resultLimit) records[insertIndex] = candidate;
        if (count < resultLimit) count++;
    }

    return count;
}

#endif
