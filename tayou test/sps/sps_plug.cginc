#ifndef AMITY_SPS_INC_PLUG
#define AMITY_SPS_INC_PLUG

// Reads SPS plug data from _VFGridFinal (captured by DataGrabPass after the
// resolver runs). Included in the main Selore deform shader.

#include "sps_cell_layout.cginc"
#include "sps_id.cginc"
#include "sps_resolver_types.cginc"

// Read the plug cell's primary target (entry S1) for deformation. Returns false
// when SPS is off or no matching plug cell / target is present.
bool selore_sps_read_plug(
    float useSps,
    SpsTexture gridTex,
    uint uniqueId,
    uint playerId,
    out float3 outWorld,
    out float3 outForward,
    out float3 outUp,
    out float outScale
) {
    outWorld = 0;
    outForward = 0;
    outUp = 0;
    outScale = 1;

    if (!sps_to_bool(useSps)) return false;

    uint slotCount = sps_socket_slot_count();
    uint slotSeed = sps_hash_id(uniqueId, playerId);

    [unroll]
    for (uint r = 0u; r < SPS_CELL_REPLICA_COUNT; r++) {
        uint candidateIdx = sps_hashed_screen_slot_index_from_id(slotSeed, r);
        if (candidateIdx >= slotCount) continue;

        SpsCell cell = sps_get_cell(gridTex, (int)candidateIdx);
        if (!sps_cell_check_magic(cell)) continue;
        if (cell.read_uint(SPS_HEADER_PRODUCT_INDEX) != SPS_PRODUCT_PLUG) continue;
        if (sps_cell_header_player_id(cell) != playerId) continue;
        if (sps_cell_header_unique_id(cell) != uniqueId) continue;

        // Read the resolved target directly from entry S1.
        float3 targetPos = cell.read_float3(SPS_PLUG_ENTRY_BASE(0) + SPS_PLUG_ENTRY_POS);
        float3 targetFwd = cell.read_float3(SPS_PLUG_ENTRY_BASE(0) + SPS_PLUG_ENTRY_FWD);
        float3 targetUp = cell.read_float3(SPS_PLUG_ENTRY_BASE(0) + SPS_PLUG_ENTRY_UP);
        uint targetFlags = cell.read_uint(SPS_PLUG_ENTRY_BASE(0) + SPS_PLUG_ENTRY_FLAGS);

        // A zero position means the resolver found no target.
        if (all(targetPos == 0.0) && all(targetFwd == 0.0)) return false;

        outWorld = targetPos;
        outForward = targetFwd;
        outUp = targetUp;
        outScale = sps_cell_header_scale(cell);
        return true;
    }

    return false;
}

#endif
