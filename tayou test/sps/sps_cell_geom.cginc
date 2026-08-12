#ifndef AMITY_SPS_INC_CELL_GEOM
#define AMITY_SPS_INC_CELL_GEOM

#include "sps_cell_layout.cginc"
#include "sps_dictionary.cginc"

#define AMITY_SPS_CELL_VERTEX_STREAM(value, stream) \
    [unroll] \
    for (int amitySpsCellVertexIndex = 0; amitySpsCellVertexIndex < 3; amitySpsCellVertexIndex++) { \
        value.vertex = amity_sps_cell_geom_vertex(value.cellIndex, amitySpsCellVertexIndex); \
        stream.Append(value); \
    } \
    stream.RestartStrip();

#define AMITY_SPS_CELL_GEOM(value, stream) \
    uint amityResolverSlotSeed = amity_sps_id_hash(); \
    for (int amityReplica = 0; amityReplica < AMITY_SPS_CELL_REPLICA_COUNT; amityReplica++) { \
        uint amityCellIndex = amity_sps_hashed_screen_slot_index_from_id(amityResolverSlotSeed, (uint)amityReplica); \
        value.cellIndex = (int)amityCellIndex; \
        AMITY_SPS_CELL_VERTEX_STREAM(value, stream) \
    } \
    value.cellIndex = AMITY_SPS_DICTIONARY_INDEX; \
    AMITY_SPS_CELL_VERTEX_STREAM(value, stream)

inline float2 amity_sps_cell_geom_uv(int vertexIndex) {
    const float overdraw = 0.01;
    return vertexIndex == 0
        ? float2(-overdraw, -overdraw)
        : vertexIndex == 1 ? float2(2 + overdraw, -overdraw) : float2(-overdraw, 2 + overdraw);
}

inline float4 amity_sps_cell_geom_vertex(int index, int vertexIndex) {
    float2 pixel =
        float2(amity_sps_cell_origin_from_index(index))
        + amity_sps_cell_geom_uv(vertexIndex) * float2(AMITY_SPS_CELL_WIDTH, AMITY_SPS_CELL_HEIGHT);
    float2 ndc = pixel / _ScreenParams.xy * 2 - 1;
    return float4(ndc, 0, 1);
}

// Non-prefixed aliases for VRCFury compatibility
#define SPS_CELL_VERTEX_STREAM AMITY_SPS_CELL_VERTEX_STREAM
#define SPS_CELL_GEOM AMITY_SPS_CELL_GEOM
#define sps_cell_geom_uv amity_sps_cell_geom_uv
#define sps_cell_geom_vertex amity_sps_cell_geom_vertex

#endif
