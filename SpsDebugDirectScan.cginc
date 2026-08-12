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

#define SPS_DEBUG_DIRECT_ZERO_RECORD (SpsDebugDirectRecord)0
#define SPS_DEBUG_DIRECT_ZERO_2 SPS_DEBUG_DIRECT_ZERO_RECORD, SPS_DEBUG_DIRECT_ZERO_RECORD
#define SPS_DEBUG_DIRECT_ZERO_4 SPS_DEBUG_DIRECT_ZERO_2, SPS_DEBUG_DIRECT_ZERO_2
#define SPS_DEBUG_DIRECT_ZERO_8 SPS_DEBUG_DIRECT_ZERO_4, SPS_DEBUG_DIRECT_ZERO_4
#define SPS_DEBUG_DIRECT_ZERO_16 SPS_DEBUG_DIRECT_ZERO_8, SPS_DEBUG_DIRECT_ZERO_8
#define SPS_DEBUG_DIRECT_ZERO_32 SPS_DEBUG_DIRECT_ZERO_16, SPS_DEBUG_DIRECT_ZERO_16
#define SPS_DEBUG_DIRECT_ZERO_64 SPS_DEBUG_DIRECT_ZERO_32, SPS_DEBUG_DIRECT_ZERO_32
#define SPS_DEBUG_DIRECT_ZERO_128 SPS_DEBUG_DIRECT_ZERO_64, SPS_DEBUG_DIRECT_ZERO_64

bool sps_debug_direct_candidate(
    SpsCell cell,
    uint slot,
    uint productFilter,
    float3 originWorld,
    out SpsDebugDirectRecord record
) {
    record.slot = slot;
    record.product = 0u;
    record.distanceKey = 0u;
    record.world = 0.0;

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

uint sps_debug_direct_collect(
    SpsTexture tex,
    uint productFilter,
    float3 originWorld,
    uint resultLimit,
    inout SpsDebugDirectRecord records[SPS_DEBUG_DIRECT_MAX_RESULTS]
) {
    resultLimit = min(max(resultLimit, 1u), (uint)SPS_DEBUG_DIRECT_MAX_RESULTS);
    uint count = 0u;
    uint slotCount = sps_socket_slot_count();
    uint columns = (uint)sps_cell_grid_columns();
    uint groupCount = min(
        (uint)SPS_CELL_DICTIONARY_GROUP_COUNT,
        (slotCount + SPS_CELL_DICTIONARY_GROUP_SIZE - 1u) / SPS_CELL_DICTIONARY_GROUP_SIZE
    );

    [loop]
    for (uint group = 0u; group < groupCount; group++) {
        bool groupUsed = all(SPS_READ_TEX(
            tex,
            uint2(group % SPS_CELL_DICTIONARY_GROUP_SIZE, group / SPS_CELL_DICTIONARY_GROUP_SIZE)
        ) == SPS_CELL_DICTIONARY_MAGIC);
        if (!groupUsed) continue;

        uint groupStart = group * SPS_CELL_DICTIONARY_GROUP_SIZE;
        [loop]
        for (uint groupMember = 0u; groupMember < SPS_CELL_DICTIONARY_GROUP_SIZE; groupMember++) {
            uint slot = groupStart + groupMember;
            if (slot >= slotCount) break;

            uint physicalIndex = slot + 1u;
            uint2 physicalCell = uint2(physicalIndex % columns, physicalIndex / columns);
            SpsCell cell = sps_get_cell_raw(tex, physicalCell * uint2(SPS_CELL_WIDTH, SPS_CELL_HEIGHT));

            SpsDebugDirectRecord candidate;
            if (!sps_debug_direct_candidate(cell, slot, productFilter, originWorld, candidate)) continue;

            uint low = 0u;
            uint high = count;
            [unroll]
            for (uint searchStep = 0u; searchStep < 8u; searchStep++) {
                if (low >= high) break;
                uint middle = (low + high) >> 1u;
                SpsDebugDirectRecord existing = records[middle];
                bool existingBefore = existing.distanceKey < candidate.distanceKey ||
                    (existing.distanceKey == candidate.distanceKey && existing.product < candidate.product);
                if (existingBefore) low = middle + 1u;
                else high = middle;
            }

            uint insertIndex = low;
            if (insertIndex < count &&
                records[insertIndex].distanceKey == candidate.distanceKey &&
                records[insertIndex].product == candidate.product) continue;
            if (insertIndex >= resultLimit) continue;

            uint moveIndex = count < resultLimit ? count : resultLimit - 1u;
            [loop]
            for (uint shiftStep = 0u; shiftStep < SPS_DEBUG_DIRECT_MAX_RESULTS; shiftStep++) {
                if (moveIndex <= insertIndex) break;
                records[moveIndex] = records[moveIndex - 1u];
                moveIndex--;
            }

            records[insertIndex] = candidate;
            if (count < resultLimit) count++;
        }
    }

    return count;
}

#endif
