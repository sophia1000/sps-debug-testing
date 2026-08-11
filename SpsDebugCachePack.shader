Shader "Hidden/VRCFury/SpsDebugCachePack" {
    Properties {
        _SPS_DebugSparseCacheTex("Sparse Deduped Cache CRT", 2D) = "black" {}
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

            Texture2D _SPS_DebugSparseCacheTex;
            float _SPS_DebugCacheRecords;

            float4 cache_zero() {
                return float4(0.0, 0.0, 0.0, 0.0);
            }

            float4 sparse_load(uint field, uint row) {
                return _SPS_DebugSparseCacheTex.Load(int3((int)field, (int)row, 0));
            }

            uint cache_decode_uint(float4 value) {
                uint4 bytes = (uint4)round(saturate(value) * 255.0);
                return bytes.x | (bytes.y << 8u) | (bytes.z << 16u) | (bytes.w << 24u);
            }

            float4 cache_encode_uint(uint value) {
                uint4 shifts = uint4(0, 8, 16, 24);
                return float4((value >> shifts) & 255u) / 255.0;
            }

            uint sparse_read_uint(uint field, uint row) {
                return cache_decode_uint(sparse_load(field, row));
            }

            uint sparse_capacity() {
                return min(sparse_read_uint(1u, 0u), SPS_DEBUG_CACHE_MAX_RECORDS);
            }

            uint sparse_count() {
                return min(sparse_read_uint(0u, 0u), sparse_capacity());
            }

            bool sparse_record_valid(uint recordIndex) {
                return (sparse_read_uint(0u, recordIndex + 1u) & 65535u) != 0u;
            }

            int nth_sparse_record(uint nth) {
                uint capacity = sparse_capacity();
                uint seen = 0u;

                [loop]
                for (uint recordIndex = 0u; recordIndex < SPS_DEBUG_CACHE_MAX_RECORDS; recordIndex++) {
                    if (recordIndex >= capacity) break;
                    if (!sparse_record_valid(recordIndex)) continue;
                    if (seen == nth) return (int)recordIndex;
                    seen++;
                }
                return -1;
            }

            float4 write_header(uint field) {
                uint outputCapacity = min(max(1u, (uint)round(_SPS_DebugCacheRecords)), SPS_DEBUG_CACHE_MAX_RECORDS);
                if (field == 0u) return cache_encode_uint(min(sparse_count(), outputCapacity));
                if (field == 1u) return cache_encode_uint(outputCapacity);
                if (field == 2u) return sparse_load(2u, 0u);
                if (field == 3u) return sparse_load(3u, 0u);
                if (field == 5u) return cache_encode_uint(1u);
                return cache_zero();
            }

            float4 write_record(uint recordIndex, uint field) {
                if (recordIndex >= sparse_count()) return cache_zero();
                int sourceRecord = nth_sparse_record(recordIndex);
                if (sourceRecord < 0) return cache_zero();
                return sparse_load(field, (uint)sourceRecord + 1u);
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
