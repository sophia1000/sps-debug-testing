#ifndef AMITY_SPS_INC_CELL_HASH
#define AMITY_SPS_INC_CELL_HASH

uint amity_sps_hash_mix(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352du;
    x ^= x >> 15;
    x *= 0x846ca68bu;
    x ^= x >> 16;
    return x;
}

uint amity_sps_hash_world(float3 worldPos, uint salt) {
    uint h = 2166136261u;
    h = (h ^ asuint(worldPos.x)) * 16777619u;
    h = (h ^ asuint(worldPos.y)) * 16777619u;
    h = (h ^ asuint(worldPos.z)) * 16777619u;
    h ^= salt * 2246822519u;
    return amity_sps_hash_mix(h);
}

uint amity_sps_hashed_index_from_uint(uint seed, uint replica, uint slotCount) {
    return amity_sps_hash_mix(seed ^ amity_sps_hash_mix(replica)) % max(slotCount, 1);
}

// Non-prefixed aliases for VRCFury compatibility
#define sps_hash_mix amity_sps_hash_mix
#define sps_hash_world amity_sps_hash_world
#define sps_hashed_index_from_uint amity_sps_hashed_index_from_uint

#endif
