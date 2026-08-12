#ifndef AMITY_SPS_INC_CELL_FRAG
#define AMITY_SPS_INC_CELL_FRAG

#include "sps_dictionary.cginc"
#include "sps_utils.cginc"
#include "sps_types.cginc"

inline bool amity_sps_cell_frag(
    int cellIndex,
    float4 vertex,
    out uint pixelIndex,
    out float4 rgba
) {
    pixelIndex = 0u;
    rgba = 0;
    if (amity_sps_should_abort()) {
        clip(-1);
        return true;
    }

    int2 local = int2(
        floor(vertex.x),
        floor(_ScreenParams.y - vertex.y)
    ) - amity_sps_cell_origin_from_index(cellIndex);
    amity_sps_clip_rect(local, int2(AMITY_SPS_CELL_WIDTH, AMITY_SPS_CELL_HEIGHT));
    pixelIndex = (uint)local.x + (uint)local.y * (uint)AMITY_SPS_CELL_WIDTH;

    if (amity_sps_dictionary_frag(cellIndex, pixelIndex, rgba)) {
        return true;
    }

    return false;
}

#endif
