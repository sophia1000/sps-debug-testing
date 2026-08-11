Shader "Hidden/VRCFury/SpsDebugCacheWriter" {
    Properties {
        [Enum(Final _VFGridFinal,0,Raw _VFGrid56,1)] _SPS_DebugSource("Source", Float) = 1
        _SPS_DebugCacheRecords("Cache Records", Range(8, 256)) = 128
    }

    SubShader {
        Tags { "VRCFallback" = "Hidden" }

        Pass {
            Cull Off
            ZWrite Off
            ZTest Always

            CGPROGRAM
            #pragma target 4.0
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma multi_compile_instancing
            #include "UnityCustomRenderTexture.cginc"
            #include "Packages/com.vrcfury.vrcfury/SPS/common/sps_cell_layout.cginc"
            #include "Packages/com.vrcfury.vrcfury/SPS/resolver/sps_resolver_payload.cginc"

            #define SPS_DEBUG_CACHE_RECORD_WIDTH 10u

            float _SPS_DebugSource;
            float _SPS_DebugCacheRecords;

            SPS_INIT_TEX(_VFGridFinal)
            SPS_INIT_TEX(_VFGrid56)

            float2 debug_source_size(SpsTexture tex) {
                float2 size = abs(tex.texelSize.zw);
                #if defined(UNITY_SINGLE_PASS_STEREO) && !defined(UNITY_STEREO_INSTANCING_ENABLED) && !defined(UNITY_STEREO_MULTIVIEW_ENABLED)
                    size *= unity_StereoScaleOffset[0].xy;
                #endif
                return size;
            }

            uint debug_grid_columns(SpsTexture tex) {
                return max(1u, (uint)floor(debug_source_size(tex).x / (float)SPS_CELL_WIDTH));
            }

            uint debug_slot_count(SpsTexture tex) {
                uint columns = debug_grid_columns(tex);
                uint rows = max(1u, (uint)floor(debug_source_size(tex).y / (float)SPS_CELL_HEIGHT));
                return max(1u, min(columns * rows - 1u, (uint)SPS_SOCKET_MAX_SLOTS));
            }

            inline uint2 debug_cell_origin(uint columns, uint cellIndex) {
                uint screenIndex = cellIndex + 1u;
                return uint2(
                    (screenIndex % columns) * (uint)SPS_CELL_WIDTH,
                    (screenIndex / columns) * (uint)SPS_CELL_HEIGHT
                );
            }

            bool cell_used(SpsTexture tex, uint columns, uint slotCount, int cellIndex) {
                if (cellIndex < 0 || (uint)cellIndex >= slotCount) return false;
                SpsCell cell = sps_get_cell_raw(tex, debug_cell_origin(columns, (uint)cellIndex));
                if (!sps_cell_check_magic(cell) || cell.read_uint(SPS_HEADER_VENDOR_INDEX) != SPS_VENDOR_SPS) return false;
                uint product = cell.read_uint(SPS_HEADER_PRODUCT_INDEX);
                return product == SPS_PRODUCT_SOCKET || product == SPS_PRODUCT_PLUG;
            }

            uint active_count(SpsTexture tex, uint columns, uint slotCount) {
                uint count = 0u;

                [loop]
                for (uint slot = 0u; slot < SPS_SOCKET_MAX_SLOTS; slot++) {
                    if (slot >= slotCount) break;
                    if (cell_used(tex, columns, slotCount, (int)slot)) count++;
                }
                return count;
            }

            int nth_used_slot(SpsTexture tex, uint columns, uint slotCount, uint nth) {
                uint seen = 0u;

                [loop]
                for (uint slot = 0u; slot < SPS_SOCKET_MAX_SLOTS; slot++) {
                    if (slot >= slotCount) break;
                    if (!cell_used(tex, columns, slotCount, (int)slot)) continue;
                    if (seen == nth) return (int)slot;
                    seen++;
                }
                return -1;
            }

            int record_slot(SpsTexture tex, uint columns, uint slotCount, uint recordIndex) {
                return nth_used_slot(tex, columns, slotCount, recordIndex);
            }

            float4 cache_encode_uint(uint value) {
                uint4 shifts = uint4(0, 8, 16, 24);
                return float4((value >> shifts) & 255u) / 255.0;
            }

            float4 cache_encode_float(float value) {
                return cache_encode_uint(asuint(value));
            }

            uint record_meta(uint slot, uint product) {
                return ((product & 15u) << 16) | ((slot + 1u) & 65535u);
            }

            float4 write_record(SpsTexture tex, uint columns, uint slotCount, uint recordIndex, uint field) {
                int slot = record_slot(tex, columns, slotCount, recordIndex);
                if (slot < 0) return cache_encode_uint(0u);

                SpsCell cell = sps_get_cell_raw(tex, debug_cell_origin(columns, (uint)slot));
                if (field == 1u) return cache_encode_uint(cell.read_uint(SPS_HEADER_UNIQUE_ID_INDEX));
                if (field == 2u) return cache_encode_uint(cell.read_uint(SPS_HEADER_PLAYER_ID_INDEX));
                if (field >= 3u && field <= 5u) {
                    float3 world = sps_cell_header_world(cell);
                    if (field == 3u) return cache_encode_float(world.x);
                    if (field == 4u) return cache_encode_float(world.y);
                    return cache_encode_float(world.z);
                }

                uint product = cell.read_uint(SPS_HEADER_PRODUCT_INDEX);
                if (field == 0u) return cache_encode_uint(record_meta((uint)slot, product));
                if (field == 6u) {
                    if (product == SPS_PRODUCT_PLUG) {
                        return cache_encode_float(cell.read_float(sps_cell_pixel_index_from_payload_index(SPS_RESOLVER_METADATA_LENGTH_INDEX)));
                    }
                    return cache_encode_uint(cell.read_uint(sps_cell_pixel_index_from_payload_index(SPS_SOCKET_PAYLOAD_FLAGS)));
                }
                if (field == 7u) return cache_encode_uint(product);
                if (field == 8u && product == SPS_PRODUCT_PLUG) {
                    return cache_encode_float(cell.read_float(sps_cell_pixel_index_from_payload_index(SPS_RESOLVER_METADATA_LENGTH_INDEX)));
                }
                if (field == 9u && product == SPS_PRODUCT_PLUG) {
                    float radius = cell.read_float(sps_cell_pixel_index_from_payload_index(SPS_RESOLVER_METADATA_RADIUS_INDEX));
                    return cache_encode_float(radius * 2.0);
                }
                return cache_encode_uint(0u);
            }

            float4 write_header(SpsTexture tex, uint columns, uint slotCount, uint field) {
                if (field == 0u) return cache_encode_uint(active_count(tex, columns, slotCount));
                if (field == 1u) return cache_encode_uint((uint)round(max(_SPS_DebugCacheRecords, 1.0)));
                if (field == 2u) return cache_encode_uint(0u);
                if (field == 3u) return cache_encode_uint(slotCount);
                if (field == 4u) return cache_encode_uint(0u);
                if (field == 5u) return cache_encode_uint(1u);
                return cache_encode_uint(0u);
            }

            float4 write_cache(SpsTexture tex, uint pixelX, uint pixelY) {
                uint columns = debug_grid_columns(tex);
                uint slotCount = debug_slot_count(tex);
                if (pixelX >= SPS_DEBUG_CACHE_RECORD_WIDTH) return cache_encode_uint(0u);
                if (pixelY == 0u) return write_header(tex, columns, slotCount, pixelX);

                uint recordIndex = pixelY - 1u;
                uint capacity = max(1u, (uint)round(_SPS_DebugCacheRecords));
                if (recordIndex >= capacity) return cache_encode_uint(0u);
                return write_record(tex, columns, slotCount, recordIndex, pixelX);
            }

            float4 frag(v2f_customrendertexture i) : SV_Target {
                uint width = SPS_DEBUG_CACHE_RECORD_WIDTH;
                uint height = max(2u, (uint)round(max(_SPS_DebugCacheRecords, 1.0)) + 1u);
                uint pixelX = min((uint)floor(saturate(i.globalTexcoord.x) * (float)width), width - 1u);
                uint pixelY = min((uint)floor(saturate(i.globalTexcoord.y) * (float)height), height - 1u);

                if (_SPS_DebugSource > 0.5) {
                    SpsTexture tex = SPS_GET_TEX(_VFGrid56);
                    return write_cache(tex, pixelX, pixelY);
                } else {
                    SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                    return write_cache(tex, pixelX, pixelY);
                }
            }
            ENDCG
        }
    }

    Fallback Off
}
