#ifndef AMITY_SPS_INC_RESOLVER_FRAG
#define AMITY_SPS_INC_RESOLVER_FRAG

#include "sps_cell_frag.cginc"
#include "sps_cell_layout.cginc"
#include "sps_dictionary.cginc"
#include "sps_id.cginc"
#include "sps_resolver_geom.cginc"
#include "sps_resolver_shader_types.cginc"
#include "sps_resolver_types.cginc"
#include "sps_utils.cginc"

// Return true when the socket cell's tags satisfy this plug's include/exclude rules.
bool sps_resolver_tag_match(
    SpsCell socketCell,
    uint playerId
) {
    uint socketTags[SPS_SOCKET_PAYLOAD_TAG_COUNT];
    [unroll]
    for (uint i = 0u; i < SPS_SOCKET_PAYLOAD_TAG_COUNT; i++) {
        socketTags[i] = socketCell.read_uint(
            sps_cell_pixel_index_from_payload_index(SPS_SOCKET_PAYLOAD_TAG_START + i));
    }

    float includeValues[4] = {
        _SPS_TagInclude1, _SPS_TagInclude2, _SPS_TagInclude3, _SPS_TagInclude4
    };
    float includeSelfValues[4] = {
        _SPS_TagInclude1Self, _SPS_TagInclude2Self, _SPS_TagInclude3Self, _SPS_TagInclude4Self
    };
    float includeOthersValues[4] = {
        _SPS_TagInclude1Others, _SPS_TagInclude2Others, _SPS_TagInclude3Others, _SPS_TagInclude4Others
    };
    float excludeValues[4] = {
        _SPS_TagExclude1, _SPS_TagExclude2, _SPS_TagExclude3, _SPS_TagExclude4
    };
    float excludeSelfValues[4] = {
        _SPS_TagExclude1Self, _SPS_TagExclude2Self, _SPS_TagExclude3Self, _SPS_TagExclude4Self
    };
    float excludeOthersValues[4] = {
        _SPS_TagExclude1Others, _SPS_TagExclude2Others, _SPS_TagExclude3Others, _SPS_TagExclude4Others
    };

    uint myPlayerId = sps_player_id();

    for (uint ti = 0u; ti < 4u; ti++) {
        uint tagHash = sps_to_uint(includeValues[ti]);
        if (tagHash == 0u) continue;

        bool found = false;
        [unroll]
        for (uint si = 0u; si < SPS_SOCKET_PAYLOAD_TAG_COUNT; si++) {
            if (socketTags[si] == tagHash) { found = true; break; }
        }
        if (!found) return false;

        bool selfOk = sps_to_bool(includeSelfValues[ti]);
        bool othersOk = sps_to_bool(includeOthersValues[ti]);
        bool isSelf = (playerId == myPlayerId);
        if (isSelf && !selfOk) return false;
        if (!isSelf && !othersOk) return false;
    }

    for (uint ei = 0u; ei < 4u; ei++) {
        uint tagHash = sps_to_uint(excludeValues[ei]);
        if (tagHash == 0u) continue;

        bool found = false;
        [unroll]
        for (uint sj = 0u; sj < SPS_SOCKET_PAYLOAD_TAG_COUNT; sj++) {
            if (socketTags[sj] == tagHash) { found = true; break; }
        }
        if (!found) continue;

        bool selfOk = sps_to_bool(excludeSelfValues[ei]);
        bool othersOk = sps_to_bool(excludeOthersValues[ei]);
        bool isSelf = (playerId == myPlayerId);
        if (isSelf && selfOk) return false;
        if (!isSelf && othersOk) return false;
    }

    return true;
}

// Is `slotIndex` the primary (first valid) replica slot for the given cell?
bool sps_resolver_is_primary(SpsTexture tex, uint slotIndex, uint uniqueId, uint playerId) {
    uint seed = sps_hash_id(uniqueId, playerId);
    [unroll]
    for (uint replica = 0u; replica < SPS_CELL_REPLICA_COUNT; replica++) {
        int candidate = (int)sps_hashed_screen_slot_index_from_id(seed, replica);
        if (candidate < 0 || candidate >= (int)sps_socket_slot_count()) continue;
        SpsCell c = sps_get_cell(tex, candidate);
        if (!sps_cell_check_magic(c)) continue;
        return candidate == (int)slotIndex;
    }
    return false;
}

// Does the dictionary cell advertise the given group as in-use?
bool sps_resolver_dictionary_group_present(SpsTexture tex, uint group) {
    SpsCell dict = sps_get_cell(tex, SPS_DICTIONARY_INDEX);
    if (!sps_cell_check_magic(dict)) return true; // no dictionary -> assume present
    float4 magic = dict.read_rgba_raw(group);
    return all(magic == SPS_CELL_DICTIONARY_MAGIC);
}

// Find the best socket cell for this plug and return its slot index (or -1).
// Strategy: (1) same player+id fast path, then (2) dictionary-guided tag scan
// so sockets with a different uniqueId are still discoverable.
int sps_resolver_find_socket(
    SpsTexture gridTex,
    uint myUniqueId,
    uint myPlayerId
) {
    int slotCount = (int)sps_socket_slot_count();

    // (1) Direct same-id lookup across the plug's own replica slots.
    uint ownSeed = sps_hash_id(myUniqueId, myPlayerId);
    [unroll]
    for (uint r = 0u; r < SPS_CELL_REPLICA_COUNT; r++) {
        int idx = (int)sps_hashed_screen_slot_index_from_id(ownSeed, r);
        if (idx < 0 || idx >= slotCount) continue;
        SpsCell cell = sps_get_cell(gridTex, idx);
        if (!sps_cell_check_magic(cell)) continue;
        if (cell.read_uint(SPS_HEADER_PRODUCT_INDEX) != SPS_PRODUCT_SOCKET) continue;
        if (sps_cell_header_player_id(cell) != myPlayerId) continue;
        if (sps_cell_header_unique_id(cell) == myUniqueId) return idx;
    }

    // (2) Dictionary-guided tag scan: walk slots in the dictionary groups this
    // plug occupies, looking for sockets whose tags match our rules.
    uint groupCount = min((uint)SPS_CELL_DICTIONARY_GROUP_COUNT,
        (slotCount + (int)SPS_CELL_DICTIONARY_GROUP_SIZE - 1) / (int)SPS_CELL_DICTIONARY_GROUP_SIZE);
    int bestIndex = -1;
    bool foundAny = false;

    for (uint slot = 0u; slot < (uint)slotCount; slot++) {
        uint group = slot / SPS_CELL_DICTIONARY_GROUP_SIZE;
        if (group >= groupCount) break;
        if (!sps_resolver_dictionary_group_present(gridTex, group)) continue;

        SpsCell cell = sps_get_cell(gridTex, (int)slot);
        if (!sps_cell_check_magic(cell)) continue;
        if (cell.read_uint(SPS_HEADER_PRODUCT_INDEX) != SPS_PRODUCT_SOCKET) continue;

        uint cellPlayerId = sps_cell_header_player_id(cell);
        if (!sps_resolver_tag_match(cell, cellPlayerId)) continue;
        if (!sps_resolver_is_primary(gridTex, slot, sps_cell_header_unique_id(cell), cellPlayerId)) continue;

        // First matching socket wins (VRCFury uses proximity scoring; first-hit
        // keeps this simple and deterministic).
        bestIndex = (int)slot;
        foundAny = true;
    }

    return foundAny ? bestIndex : -1;
}

// Write one plug payload pixel. Entry data (the resolved socket S1) is passed
// in; zeros mean "no target resolved". The slot header is written separately
// in sps_resolver_frag and always carries the plug's own transform.
bool sps_resolver_try_write_plug_pixel(
    uint pixelIndex,
    float3 s1Pos,
    float3 s1Fwd,
    float3 s1Up,
    uint s1Flags,
    out float4 rgba
) {
    rgba = 0;

    // Plug metadata row (R14): baked length/radius + metadata color.
    if (pixelIndex == SPS_PLUG_META_R_INDEX) { rgba = sps_encode_float(_SPS_MetadataColor.r); return true; }
    if (pixelIndex == SPS_PLUG_META_G_INDEX) { rgba = sps_encode_float(_SPS_MetadataColor.g); return true; }
    if (pixelIndex == SPS_PLUG_META_B_INDEX) { rgba = sps_encode_float(_SPS_MetadataColor.b); return true; }
    if (pixelIndex == SPS_PLUG_LENGTH_INDEX) { rgba = sps_encode_float(_SPS_BakedLength); return true; }
    if (pixelIndex == SPS_PLUG_RADIUS_INDEX) { rgba = sps_encode_float(_SPS_BakedRadius); return true; }

    // Radius samples row (R15): 16 samples from the baked set.
    if (pixelIndex >= SPS_PLUG_RADIUS_SAMPLES_START
        && pixelIndex < SPS_PLUG_RADIUS_SAMPLES_START + SPS_PLUG_RADIUS_SAMPLE_COUNT) {
        uint sampleIndex = pixelIndex - SPS_PLUG_RADIUS_SAMPLES_START;
        float4 samples[4] = {
            _SPS_BakedRadiusSamples0, _SPS_BakedRadiusSamples1,
            _SPS_BakedRadiusSamples2, _SPS_BakedRadiusSamples3
        };
        float4 packed = samples[sampleIndex / 4u];
        float value = packed[sampleIndex % 4u];
        rgba = sps_encode_float(value);
        return true;
    }

    // Entry S1 (resolved socket target). Other entries stay zero.
    uint entryBase = SPS_PLUG_ENTRY_BASE(0);
    uint entryOffset = pixelIndex - entryBase;
    if (entryOffset < SPS_PLUG_ENTRY_STRIDE) {
        if (entryOffset < 3u) {
            rgba = sps_encode_float(s1Pos[entryOffset]);
            return true;
        }
        if (entryOffset < 6u) {
            rgba = sps_encode_float(s1Fwd[entryOffset - 3u]);
            return true;
        }
        if (entryOffset < 9u) {
            rgba = sps_encode_float(s1Up[entryOffset - 6u]);
            return true;
        }
        if (entryOffset == SPS_PLUG_ENTRY_FLAGS) {
            rgba = sps_encode_uint(s1Flags);
            return true;
        }
        if (entryOffset == SPS_PLUG_ENTRY_GUIDE) {
            rgba = sps_encode_uint(0u);
            return true;
        }
        // TIN / TOUT not authored yet -> zero.
        rgba = sps_encode_float(0.0);
        return true;
    }

    // Everything else (zero gaps, unused entries) -> zero.
    rgba = sps_encode_uint(0u);
    return true;
}

float4 sps_resolver_frag(SpsTexture tex, g2f input) {
    uint pixelIndex;
    float4 rgba = 0;
    if (sps_cell_frag(input.cellIndex, input.vertex, pixelIndex, rgba)) return rgba;

    uint uniqueId = sps_id();
    if (uniqueId == 0u) uniqueId = sps_hash_world(sps_object_origin_world(), 0u);
    uint playerId = sps_player_id();

    // The slot header always carries the plug's OWN transform (matching
    // VRCFury). The resolved socket target lives in the S1 entry payload, not
    // the header, so consumers reading the header see where the plug actually
    // is (e.g. the debug overlay) rather than where its target is.
    if (sps_try_get_slot_header_rgba(
        pixelIndex,
        uniqueId,
        playerId,
        SPS_PRODUCT_PLUG,
        sps_object_origin_world(),
        sps_object_forward_world(),
        sps_object_up_world(),
        sps_object_scale_world(),
        0,
        rgba
    )) return rgba;

    int socketIndex = sps_resolver_find_socket(tex, uniqueId, playerId);

    // When no socket resolves, still write the metadata payload (baked
    // length/radius) so consumers can always read the plug's size; the S1
    // entry stays zero, which sps_plug.cginc treats as "no target".
    float3 s1Pos = 0;
    float3 s1Fwd = 0;
    float3 s1Up = 0;
    uint s1Flags = 0;
    if (socketIndex >= 0) {
        SpsCell socketCell = sps_get_cell(tex, socketIndex);
        s1Pos = sps_cell_header_world(socketCell);
        s1Fwd = sps_cell_header_forward(socketCell);
        s1Up = sps_cell_header_up(socketCell);
        s1Flags = socketCell.read_uint(
            sps_cell_pixel_index_from_payload_index(SPS_SOCKET_PAYLOAD_FLAGS));
    }

    if (sps_resolver_try_write_plug_pixel(
        pixelIndex,
        s1Pos,
        s1Fwd,
        s1Up,
        s1Flags,
        rgba
    )) return rgba;

    return 0;
}

#endif
