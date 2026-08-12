#ifndef AMITY_SPS_INC_DICTIONARY
#define AMITY_SPS_INC_DICTIONARY

#include "sps_id.cginc"
#include "sps_cell_hash.cginc"
#include "sps_cell_layout.cginc"

#define AMITY_SPS_DICTIONARY_INDEX (-1)

inline bool amity_sps_dictionary_group_used(uint group) {
    uint slotSeed = amity_sps_id_hash();
    [unroll]
    for (uint replica = 0u; replica < AMITY_SPS_CELL_REPLICA_COUNT; replica++) {
        uint cellIndex = amity_sps_hashed_screen_slot_index_from_id(slotSeed, replica);
        if (group == cellIndex / AMITY_SPS_CELL_DICTIONARY_GROUP_SIZE) {
            return true;
        }
    }
    return false;
}

inline bool amity_sps_dictionary_frag(
    int cellIndex,
    uint pixelIndex,
    out float4 rgba
) {
    rgba = 0;
    if (cellIndex != AMITY_SPS_DICTIONARY_INDEX) return false;
    uint group = pixelIndex;
    if (!amity_sps_dictionary_group_used(group)) clip(-1);
    rgba = AMITY_SPS_CELL_DICTIONARY_MAGIC;
    return true;
}

// Non-prefixed aliases for VRCFury compatibility
#define SPS_DICTIONARY_INDEX AMITY_SPS_DICTIONARY_INDEX
#define sps_dictionary_group_used amity_sps_dictionary_group_used
#define sps_dictionary_frag amity_sps_dictionary_frag

#endif
