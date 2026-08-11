Shader "Hidden/VRCFury/SpsDebugCacheCompactor" {
    Properties {
        _SPS_DebugRawCacheTex("Raw Slot Cache CRT", 2D) = "black" {}
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
            #include "UnityCustomRenderTexture.cginc"

            #define SPS_DEBUG_CACHE_RECORD_WIDTH 10u
            #define SPS_DEBUG_CACHE_MAX_RECORDS 128u
            #define SPS_DEBUG_PRODUCT_SOCKET 1u
            #define SPS_DEBUG_PRODUCT_PLUG 2u

            Texture2D _SPS_DebugRawCacheTex;
            float _SPS_DebugCacheRecords;

            float4 cache_zero() {
                return float4(0.0, 0.0, 0.0, 0.0);
            }

            float4 raw_load(uint field, uint row) {
                return _SPS_DebugRawCacheTex.Load(int3((int)field, (int)row, 0));
            }

            uint cache_decode_uint(float4 value) {
                uint4 bytes = (uint4)round(saturate(value) * 255.0);
                return bytes.x | (bytes.y << 8u) | (bytes.z << 16u) | (bytes.w << 24u);
            }

            float4 cache_encode_uint(uint value) {
                uint4 shifts = uint4(0, 8, 16, 24);
                return float4((value >> shifts) & 255u) / 255.0;
            }

            uint raw_read_uint(uint field, uint row) {
                return cache_decode_uint(raw_load(field, row));
            }

            uint raw_record_limit() {
                uint count = raw_read_uint(0u, 0u);
                uint capacity = raw_read_uint(1u, 0u);
                return min(min(count, capacity), SPS_DEBUG_CACHE_MAX_RECORDS);
            }

            uint raw_record_product(uint recordIndex) {
                uint row = recordIndex + 1u;
                uint product = raw_read_uint(7u, row);
                if (product != 0u) return product;
                return (raw_read_uint(0u, row) >> 16u) & 15u;
            }

            bool raw_record_valid(uint recordIndex) {
                uint row = recordIndex + 1u;
                if ((raw_read_uint(0u, row) & 65535u) == 0u) return false;
                uint product = raw_record_product(recordIndex);
                return product == SPS_DEBUG_PRODUCT_SOCKET || product == SPS_DEBUG_PRODUCT_PLUG;
            }

            bool raw_record_duplicate_before(uint recordIndex) {
                if (!raw_record_valid(recordIndex)) return false;

                uint row = recordIndex + 1u;
                uint product = raw_record_product(recordIndex);
                uint id = raw_read_uint(1u, row);
                uint player = raw_read_uint(2u, row);

                [loop]
                for (uint previous = 0u; previous < SPS_DEBUG_CACHE_MAX_RECORDS; previous++) {
                    if (previous >= recordIndex) break;
                    if (!raw_record_valid(previous)) continue;
                    uint previousRow = previous + 1u;
                    if (raw_record_product(previous) != product) continue;
                    if (raw_read_uint(1u, previousRow) != id) continue;
                    if (raw_read_uint(2u, previousRow) != player) continue;
                    return true;
                }
                return false;
            }

            uint kept_record_count() {
                uint limit = raw_record_limit();
                uint count = 0u;

                [loop]
                for (uint recordIndex = 0u; recordIndex < SPS_DEBUG_CACHE_MAX_RECORDS; recordIndex++) {
                    if (recordIndex >= limit) break;
                    if (raw_record_valid(recordIndex) && !raw_record_duplicate_before(recordIndex)) count++;
                }
                return count;
            }

            float4 write_header(uint field) {
                uint outputCapacity = min(max(1u, (uint)round(_SPS_DebugCacheRecords)), SPS_DEBUG_CACHE_MAX_RECORDS);
                if (field == 0u) return cache_encode_uint(kept_record_count());
                if (field == 1u) return cache_encode_uint(outputCapacity);
                if (field == 2u) return cache_encode_uint(raw_record_limit());
                if (field == 3u) return cache_encode_uint(raw_read_uint(1u, 0u));
                // Mode 0 means valid records may be sparse. Readers use field 0
                // of each row as the authoritative validity marker.
                if (field == 5u) return cache_encode_uint(0u);
                return cache_zero();
            }

            float4 write_record(uint recordIndex, uint field) {
                uint limit = raw_record_limit();
                if (recordIndex >= limit) return cache_zero();

                // Only metadata needs clearing. The other fields can be copied
                // untouched because every reader checks metadata before use.
                if (field == 0u && raw_record_duplicate_before(recordIndex)) return cache_zero();
                return raw_load(field, recordIndex + 1u);
            }

            float4 frag(v2f_customrendertexture i) : SV_Target {
                uint width = SPS_DEBUG_CACHE_RECORD_WIDTH;
                uint capacity = min(max(1u, (uint)round(_SPS_DebugCacheRecords)), SPS_DEBUG_CACHE_MAX_RECORDS);
                uint height = capacity + 1u;
                uint pixelX = min((uint)floor(saturate(i.globalTexcoord.x) * (float)width), width - 1u);
                uint pixelY = min((uint)floor(saturate(i.globalTexcoord.y) * (float)height), height - 1u);

                if (pixelY == 0u) return write_header(pixelX);
                return write_record(pixelY - 1u, pixelX);
            }
            ENDCG
        }
    }

    Fallback Off
}
