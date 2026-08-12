#ifndef AMITY_SPS_INC_RESOLVER_GEOM
#define AMITY_SPS_INC_RESOLVER_GEOM
#include <UnityInstancing.cginc>

struct appdata {
    float4 vertex : POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2g {
    float4 vertex : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct g2f {
    float4 vertex : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
    nointerpolation int cellIndex : TEXCOORD0;
};

#define SPS_RESOLVER_CELL_GEOM(value, stream) \
    uint amityResolverSlotSeed = sps_id_hash(); \
    for (int amityReplica = 0; amityReplica < SPS_CELL_REPLICA_COUNT; amityReplica++) { \
        uint amityCellIndex = sps_hashed_screen_slot_index_from_id(amityResolverSlotSeed, (uint)amityReplica); \
        value.cellIndex = (int)amityCellIndex; \
        SPS_CELL_VERTEX_STREAM(value, stream) \
    } \
    value.cellIndex = SPS_DICTIONARY_INDEX; \
    SPS_CELL_VERTEX_STREAM(value, stream)

#endif
