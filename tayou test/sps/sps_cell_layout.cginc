#ifndef AMITY_SPS_INC_CELL_LAYOUT
#define AMITY_SPS_INC_CELL_LAYOUT

#include "sps_cell_hash.cginc"
#include "sps_texture.cginc"
#include "sps_encode.cginc"

#define AMITY_SPS_SOCKET_MAX_SLOTS 4096
#define AMITY_SPS_CELL_WIDTH 16
#define AMITY_SPS_CELL_HEIGHT 16
#define AMITY_SPS_CELL_ROW_SHIFT 4
#define AMITY_SPS_CELL_COL_MASK ((uint)AMITY_SPS_CELL_WIDTH - 1)
#define AMITY_SPS_CELL_HEADER_TOP_ROW_COUNT 1
#define AMITY_SPS_CELL_HEADER_BOTTOM_ROW_COUNT 1
#define AMITY_SPS_CELL_PAYLOAD_START AMITY_SPS_CELL_WIDTH
#define AMITY_SPS_CELL_DICTIONARY_GROUP_SIZE 16
#define AMITY_SPS_CELL_DICTIONARY_GROUP_COUNT 256
#define AMITY_SPS_CELL_DICTIONARY_MAGIC float4(1, 0, 1, 1)
#define AMITY_SPS_CELL_REPLICA_COUNT 5
#define AMITY_SPS_CHAIN_MAX_SOCKETS 5
#define AMITY_SPS_RESOLVER_CANDIDATE_COUNT 10
#define AMITY_SPS_MAGIC_COUNT 4
#define AMITY_SPS_CELL_MAGIC_0 float4(1, 0, 0, 1)
#define AMITY_SPS_CELL_MAGIC_1 float4(0, 1, 0, 1)
#define AMITY_SPS_CELL_MAGIC_2 float4(0, 0, 1, 1)
#define AMITY_SPS_CELL_MAGIC_3 float4(1, 1, 0, 1)
#define AMITY_SPS_CELL_MAGIC_INDEX_0 0
#define AMITY_SPS_CELL_MAGIC_INDEX_1 (uint)AMITY_SPS_CELL_WIDTH - 1
#define AMITY_SPS_CELL_MAGIC_INDEX_2 ((uint)AMITY_SPS_CELL_HEIGHT - 1) * (uint)AMITY_SPS_CELL_WIDTH
#define AMITY_SPS_CELL_MAGIC_INDEX_3 (uint)AMITY_SPS_CELL_HEIGHT * (uint)AMITY_SPS_CELL_WIDTH - 1
#define AMITY_SPS_PRODUCT_SOCKET 1
#define AMITY_SPS_PRODUCT_PLUG 2
#define AMITY_SPS_VENDOR_SPS 1
#define AMITY_SPS_VERSION_SPS 1
#define AMITY_SPS_HEADER_VENDOR_INDEX 1
#define AMITY_SPS_HEADER_PRODUCT_INDEX 2
#define AMITY_SPS_HEADER_VERSION_INDEX 3
#define AMITY_SPS_HEADER_UNIQUE_ID_INDEX 4
#define AMITY_SPS_HEADER_PLAYER_ID_INDEX 5
#define AMITY_SPS_HEADER_DEBUG_INDEX 6
#define AMITY_SPS_HEADER_BOTTOM_ROW_BASE (((AMITY_SPS_CELL_HEIGHT - 1) * AMITY_SPS_CELL_WIDTH))
#define AMITY_SPS_HEADER_BOTTOM_ROW_START (AMITY_SPS_HEADER_BOTTOM_ROW_BASE + 1)
#define AMITY_SPS_HEADER_WORLD_INDEX (AMITY_SPS_HEADER_BOTTOM_ROW_START + 0)
#define AMITY_SPS_HEADER_FORWARD_INDEX (AMITY_SPS_HEADER_BOTTOM_ROW_START + 3)
#define AMITY_SPS_HEADER_UP_INDEX (AMITY_SPS_HEADER_BOTTOM_ROW_START + 6)
#define AMITY_SPS_HEADER_SCALE_INDEX (AMITY_SPS_HEADER_BOTTOM_ROW_START + 9)
#define AMITY_SPS_SOCKET_PAYLOAD_FLAGS 0
#define AMITY_SPS_SOCKET_PAYLOAD_NEXT_ID 1
#define AMITY_SPS_SOCKET_PAYLOAD_TAG_START 2
#define AMITY_SPS_SOCKET_PAYLOAD_TAG_COUNT 8
#define AMITY_SPS_SOCKET_PAYLOAD_TAG_1 (AMITY_SPS_SOCKET_PAYLOAD_TAG_START + 0)
#define AMITY_SPS_SOCKET_PAYLOAD_TAG_2 (AMITY_SPS_SOCKET_PAYLOAD_TAG_START + 1)
#define AMITY_SPS_SOCKET_PAYLOAD_TAG_3 (AMITY_SPS_SOCKET_PAYLOAD_TAG_START + 2)
#define AMITY_SPS_SOCKET_PAYLOAD_TAG_4 (AMITY_SPS_SOCKET_PAYLOAD_TAG_START + 3)
#define AMITY_SPS_SOCKET_PAYLOAD_TAG_5 (AMITY_SPS_SOCKET_PAYLOAD_TAG_START + 4)
#define AMITY_SPS_SOCKET_PAYLOAD_TAG_6 (AMITY_SPS_SOCKET_PAYLOAD_TAG_START + 5)
#define AMITY_SPS_SOCKET_PAYLOAD_TAG_7 (AMITY_SPS_SOCKET_PAYLOAD_TAG_START + 6)
#define AMITY_SPS_SOCKET_PAYLOAD_TAG_8 (AMITY_SPS_SOCKET_PAYLOAD_TAG_START + 7)
#define AMITY_SPS_SOCKET_PAYLOAD_TANGENT_IN_START 10
#define AMITY_SPS_SOCKET_PAYLOAD_TANGENT_OUT_START 13

struct AmitySpsCell {
    AmitySpsTexture raw;
    uint2 offset;
    uint2 size;

    uint2 get_pixel(uint index) {
        return uint2(index % size.x, index / size.x);
    }

    float4 read_rgba_raw(uint2 pixel) {
        return AMITY_SPS_READ_TEX(raw, offset + pixel);
    }

    float4 read_rgba_raw(uint index) {
        return read_rgba_raw(get_pixel(index));
    }

    uint read_uint(uint index) {
        return amity_sps_decode_uint(read_rgba_raw(index));
    }

    float read_float(uint index) {
        return asfloat(read_uint(index));
    }

    float3 read_float3(uint index) {
        return float3(
            read_float(index),
            read_float(index + 1),
            read_float(index + 2)
        );
    }
};

inline int amity_sps_cell_grid_columns() {
    return max(1, (int)floor(_ScreenParams.x / AMITY_SPS_CELL_WIDTH));
}

inline int amity_sps_socket_slot_count() {
    int cols = amity_sps_cell_grid_columns();
    int rows = max(1, (int)floor(_ScreenParams.y / AMITY_SPS_CELL_HEIGHT));
    return max(1, min(cols * rows - 1, (int)AMITY_SPS_SOCKET_MAX_SLOTS));
}

inline uint amity_sps_hashed_screen_slot_index_from_id(uint id, uint replica) {
    return amity_sps_hashed_index_from_uint(id, replica, amity_sps_socket_slot_count());
}

inline int2 amity_sps_cell_grid_size_for_slot_count(uint slotCount) {
    int cols = amity_sps_cell_grid_columns();
    uint safeCols = (uint)max(cols, 1);
    int rowsUsed = max(1, (int)((slotCount + safeCols - 1) / safeCols));
    return int2(cols, rowsUsed);
}

inline int2 amity_sps_get_cell_origin(int index) {
    int columns = amity_sps_cell_grid_columns();
    uint screenIndex = index + 1;
    return int2(
        (screenIndex % columns) * AMITY_SPS_CELL_WIDTH,
        (screenIndex / columns) * AMITY_SPS_CELL_HEIGHT
    );
}

inline int2 amity_sps_cell_origin_from_index(int index) {
    return index < 0 ? int2(0, 0) : amity_sps_get_cell_origin(index);
}

inline AmitySpsCell amity_sps_get_cell_raw(AmitySpsTexture tex, uint2 origin) {
    AmitySpsCell cell;
    cell.raw = tex;
    cell.offset = origin;
    cell.size = uint2(AMITY_SPS_CELL_WIDTH, AMITY_SPS_CELL_HEIGHT);
    return cell;
}

inline AmitySpsCell amity_sps_get_cell(AmitySpsTexture tex, int index) {
    return amity_sps_get_cell_raw(tex, uint2(amity_sps_cell_origin_from_index(index)));
}

inline uint amity_sps_cell_pixel_index_from_payload_index(uint payloadIndex) {
    return payloadIndex + AMITY_SPS_CELL_PAYLOAD_START;
}

inline bool amity_sps_cell_payload_index_from_pixel_index(uint index, out uint payloadIndex) {
    payloadIndex = 0u;
    if (index < AMITY_SPS_CELL_PAYLOAD_START) return false;
    payloadIndex = index - AMITY_SPS_CELL_PAYLOAD_START;
    return true;
}

bool amity_sps_try_get_slot_header_rgba(
    uint index,
    uint uniqueId,
    uint playerId,
    uint product,
    float3 world,
    float3 forward,
    float3 up,
    float scale,
    float4 debug,
    out float4 rgba
) {
    rgba = 0;
    if (index == AMITY_SPS_CELL_MAGIC_INDEX_0) { rgba = AMITY_SPS_CELL_MAGIC_0; return true; }
    if (index == AMITY_SPS_CELL_MAGIC_INDEX_1) { rgba = AMITY_SPS_CELL_MAGIC_1; return true; }
    if (index == AMITY_SPS_CELL_MAGIC_INDEX_2) { rgba = AMITY_SPS_CELL_MAGIC_2; return true; }
    if (index == AMITY_SPS_CELL_MAGIC_INDEX_3) { rgba = AMITY_SPS_CELL_MAGIC_3; return true; }
    float value = 0;
    switch (index) {
        case AMITY_SPS_HEADER_VENDOR_INDEX:
            rgba = amity_sps_encode_uint(AMITY_SPS_VENDOR_SPS);
            return true;
        case AMITY_SPS_HEADER_PRODUCT_INDEX:
            rgba = amity_sps_encode_uint(product);
            return true;
        case AMITY_SPS_HEADER_VERSION_INDEX:
            rgba = amity_sps_encode_uint(AMITY_SPS_VERSION_SPS);
            return true;
        case AMITY_SPS_HEADER_UNIQUE_ID_INDEX:
            rgba = amity_sps_encode_uint(uniqueId);
            return true;
        case AMITY_SPS_HEADER_PLAYER_ID_INDEX:
            rgba = amity_sps_encode_uint(playerId);
            return true;
        case AMITY_SPS_HEADER_WORLD_INDEX + 0:
            value = world.x;
            break;
        case AMITY_SPS_HEADER_WORLD_INDEX + 1:
            value = world.y;
            break;
        case AMITY_SPS_HEADER_WORLD_INDEX + 2:
            value = world.z;
            break;
        case AMITY_SPS_HEADER_FORWARD_INDEX + 0:
            value = forward.x;
            break;
        case AMITY_SPS_HEADER_FORWARD_INDEX + 1:
            value = forward.y;
            break;
        case AMITY_SPS_HEADER_FORWARD_INDEX + 2:
            value = forward.z;
            break;
        case AMITY_SPS_HEADER_UP_INDEX + 0:
            value = up.x;
            break;
        case AMITY_SPS_HEADER_UP_INDEX + 1:
            value = up.y;
            break;
        case AMITY_SPS_HEADER_UP_INDEX + 2:
            value = up.z;
            break;
        case AMITY_SPS_HEADER_SCALE_INDEX:
            value = scale;
            break;
        case AMITY_SPS_HEADER_DEBUG_INDEX:
            rgba = debug;
            return true;
        default:
            return false;
    }
    rgba = amity_sps_encode_float(value);
    return true;
}

inline float3 amity_sps_cell_header_world(AmitySpsCell cell) {
    return cell.read_float3(AMITY_SPS_HEADER_WORLD_INDEX);
}

inline float3 amity_sps_cell_header_forward(AmitySpsCell cell) {
    return cell.read_float3(AMITY_SPS_HEADER_FORWARD_INDEX);
}

inline float3 amity_sps_cell_header_up(AmitySpsCell cell) {
    return cell.read_float3(AMITY_SPS_HEADER_UP_INDEX);
}

inline float amity_sps_cell_header_scale(AmitySpsCell cell) {
    return cell.read_float(AMITY_SPS_HEADER_SCALE_INDEX);
}

inline uint amity_sps_cell_header_unique_id(AmitySpsCell cell) {
    return cell.read_uint(AMITY_SPS_HEADER_UNIQUE_ID_INDEX);
}

inline uint amity_sps_cell_header_player_id(AmitySpsCell cell) {
    return cell.read_uint(AMITY_SPS_HEADER_PLAYER_ID_INDEX);
}

inline bool amity_sps_cell_check_magic(AmitySpsTexture tex, uint2 cellOffset) {
    if (any(AMITY_SPS_READ_TEX(tex, cellOffset + uint2(0, 0)) != AMITY_SPS_CELL_MAGIC_0)) return false;
    if (any(AMITY_SPS_READ_TEX(tex, cellOffset + uint2(AMITY_SPS_CELL_WIDTH - 1, 0)) != AMITY_SPS_CELL_MAGIC_1)) return false;
    if (any(AMITY_SPS_READ_TEX(tex, cellOffset + uint2(0, AMITY_SPS_CELL_HEIGHT - 1)) != AMITY_SPS_CELL_MAGIC_2)) return false;
    if (any(AMITY_SPS_READ_TEX(tex, cellOffset + uint2(AMITY_SPS_CELL_WIDTH - 1, AMITY_SPS_CELL_HEIGHT - 1)) != AMITY_SPS_CELL_MAGIC_3)) return false;
    return true;
}

inline bool amity_sps_cell_check_magic(AmitySpsCell cell) {
    return amity_sps_cell_check_magic(cell.raw, cell.offset);
}

// Cheap corner-0-only pre-filter for the "empty slot" path. Reads a single
// texel and bails, letting the common empty-slot case skip straight past the
// full 4-corner validation. Callers that need certainty must still follow up
// with amity_sps_cell_check_magic.
inline bool amity_sps_cell_check_magic_corner0(AmitySpsTexture tex, uint2 cellOffset) {
    return !any(AMITY_SPS_READ_TEX(tex, cellOffset + uint2(0, 0)) != AMITY_SPS_CELL_MAGIC_0);
}

inline bool amity_sps_cell_check_magic_corner0(AmitySpsCell cell) {
    return amity_sps_cell_check_magic_corner0(cell.raw, cell.offset);
}

// Non-prefixed aliases for VRCFury compatibility
#define SPS_SOCKET_MAX_SLOTS AMITY_SPS_SOCKET_MAX_SLOTS
#define SPS_CELL_WIDTH AMITY_SPS_CELL_WIDTH
#define SPS_CELL_HEIGHT AMITY_SPS_CELL_HEIGHT
#define SPS_CELL_ROW_SHIFT AMITY_SPS_CELL_ROW_SHIFT
#define SPS_CELL_COL_MASK AMITY_SPS_CELL_COL_MASK
#define SPS_CELL_HEADER_TOP_ROW_COUNT AMITY_SPS_CELL_HEADER_TOP_ROW_COUNT
#define SPS_CELL_HEADER_BOTTOM_ROW_COUNT AMITY_SPS_CELL_HEADER_BOTTOM_ROW_COUNT
#define SPS_CELL_PAYLOAD_START AMITY_SPS_CELL_PAYLOAD_START
#define SPS_CELL_DICTIONARY_GROUP_SIZE AMITY_SPS_CELL_DICTIONARY_GROUP_SIZE
#define SPS_CELL_DICTIONARY_GROUP_COUNT AMITY_SPS_CELL_DICTIONARY_GROUP_COUNT
#define SPS_CELL_DICTIONARY_MAGIC AMITY_SPS_CELL_DICTIONARY_MAGIC
#define SPS_CELL_REPLICA_COUNT AMITY_SPS_CELL_REPLICA_COUNT
#define SPS_CHAIN_MAX_SOCKETS AMITY_SPS_CHAIN_MAX_SOCKETS
#define SPS_RESOLVER_CANDIDATE_COUNT AMITY_SPS_RESOLVER_CANDIDATE_COUNT
#define SPS_MAGIC_COUNT AMITY_SPS_MAGIC_COUNT
#define SPS_CELL_MAGIC_0 AMITY_SPS_CELL_MAGIC_0
#define SPS_CELL_MAGIC_1 AMITY_SPS_CELL_MAGIC_1
#define SPS_CELL_MAGIC_2 AMITY_SPS_CELL_MAGIC_2
#define SPS_CELL_MAGIC_3 AMITY_SPS_CELL_MAGIC_3
#define SPS_CELL_MAGIC_INDEX_0 AMITY_SPS_CELL_MAGIC_INDEX_0
#define SPS_CELL_MAGIC_INDEX_1 AMITY_SPS_CELL_MAGIC_INDEX_1
#define SPS_CELL_MAGIC_INDEX_2 AMITY_SPS_CELL_MAGIC_INDEX_2
#define SPS_CELL_MAGIC_INDEX_3 AMITY_SPS_CELL_MAGIC_INDEX_3
#define SPS_PRODUCT_SOCKET AMITY_SPS_PRODUCT_SOCKET
#define SPS_PRODUCT_PLUG AMITY_SPS_PRODUCT_PLUG
#define SPS_VENDOR_SPS AMITY_SPS_VENDOR_SPS
#define SPS_VERSION_SPS AMITY_SPS_VERSION_SPS
#define SPS_HEADER_VENDOR_INDEX AMITY_SPS_HEADER_VENDOR_INDEX
#define SPS_HEADER_PRODUCT_INDEX AMITY_SPS_HEADER_PRODUCT_INDEX
#define SPS_HEADER_VERSION_INDEX AMITY_SPS_HEADER_VERSION_INDEX
#define SPS_HEADER_UNIQUE_ID_INDEX AMITY_SPS_HEADER_UNIQUE_ID_INDEX
#define SPS_HEADER_PLAYER_ID_INDEX AMITY_SPS_HEADER_PLAYER_ID_INDEX
#define SPS_HEADER_DEBUG_INDEX AMITY_SPS_HEADER_DEBUG_INDEX
#define SPS_HEADER_BOTTOM_ROW_BASE AMITY_SPS_HEADER_BOTTOM_ROW_BASE
#define SPS_HEADER_BOTTOM_ROW_START AMITY_SPS_HEADER_BOTTOM_ROW_START
#define SPS_HEADER_WORLD_INDEX AMITY_SPS_HEADER_WORLD_INDEX
#define SPS_HEADER_FORWARD_INDEX AMITY_SPS_HEADER_FORWARD_INDEX
#define SPS_HEADER_UP_INDEX AMITY_SPS_HEADER_UP_INDEX
#define SPS_HEADER_SCALE_INDEX AMITY_SPS_HEADER_SCALE_INDEX
#define SPS_SOCKET_PAYLOAD_FLAGS AMITY_SPS_SOCKET_PAYLOAD_FLAGS
#define SPS_SOCKET_PAYLOAD_NEXT_ID AMITY_SPS_SOCKET_PAYLOAD_NEXT_ID
#define SPS_SOCKET_PAYLOAD_TAG_START AMITY_SPS_SOCKET_PAYLOAD_TAG_START
#define SPS_SOCKET_PAYLOAD_TAG_COUNT AMITY_SPS_SOCKET_PAYLOAD_TAG_COUNT
#define SPS_SOCKET_PAYLOAD_TAG_1 AMITY_SPS_SOCKET_PAYLOAD_TAG_1
#define SPS_SOCKET_PAYLOAD_TAG_2 AMITY_SPS_SOCKET_PAYLOAD_TAG_2
#define SPS_SOCKET_PAYLOAD_TAG_3 AMITY_SPS_SOCKET_PAYLOAD_TAG_3
#define SPS_SOCKET_PAYLOAD_TAG_4 AMITY_SPS_SOCKET_PAYLOAD_TAG_4
#define SPS_SOCKET_PAYLOAD_TAG_5 AMITY_SPS_SOCKET_PAYLOAD_TAG_5
#define SPS_SOCKET_PAYLOAD_TAG_6 AMITY_SPS_SOCKET_PAYLOAD_TAG_6
#define SPS_SOCKET_PAYLOAD_TAG_7 AMITY_SPS_SOCKET_PAYLOAD_TAG_7
#define SPS_SOCKET_PAYLOAD_TAG_8 AMITY_SPS_SOCKET_PAYLOAD_TAG_8
#define SPS_SOCKET_PAYLOAD_TANGENT_IN_START AMITY_SPS_SOCKET_PAYLOAD_TANGENT_IN_START
#define SPS_SOCKET_PAYLOAD_TANGENT_OUT_START AMITY_SPS_SOCKET_PAYLOAD_TANGENT_OUT_START
#define SpsCell AmitySpsCell
#define sps_cell_grid_columns amity_sps_cell_grid_columns
#define sps_socket_slot_count amity_sps_socket_slot_count
#define sps_hashed_screen_slot_index_from_id amity_sps_hashed_screen_slot_index_from_id
#define sps_cell_grid_size_for_slot_count amity_sps_cell_grid_size_for_slot_count
#define sps_get_cell_origin amity_sps_get_cell_origin
#define sps_cell_origin_from_index amity_sps_cell_origin_from_index
#define sps_get_cell_raw amity_sps_get_cell_raw
#define sps_get_cell amity_sps_get_cell
#define sps_cell_pixel_index_from_payload_index amity_sps_cell_pixel_index_from_payload_index
#define sps_cell_payload_index_from_pixel_index amity_sps_cell_payload_index_from_pixel_index
#define sps_try_get_slot_header_rgba amity_sps_try_get_slot_header_rgba
#define sps_cell_header_world amity_sps_cell_header_world
#define sps_cell_header_forward amity_sps_cell_header_forward
#define sps_cell_header_up amity_sps_cell_header_up
#define sps_cell_header_scale amity_sps_cell_header_scale
#define sps_cell_header_unique_id amity_sps_cell_header_unique_id
#define sps_cell_header_player_id amity_sps_cell_header_player_id
#define sps_cell_check_magic amity_sps_cell_check_magic
#define sps_cell_frag amity_sps_cell_frag
#define sps_cell_geom_uv amity_sps_cell_geom_uv
#define sps_cell_geom_vertex amity_sps_cell_geom_vertex

#endif
