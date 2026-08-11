Shader "Hidden/VRCFury/SpsDebugAutoInspector" {
    Properties {
        _SPS_DebugFontAtlas("Font Atlas", 2D) = "white" {}
        _SPS_DebugCellLegendTex("Socket Bitmap Legend", 2D) = "black" {}
        _SPS_DebugResolverLegendTex("Plug Bitmap Legend", 2D) = "black" {}
        [Enum(Final _VFGridFinal,0,Raw _VFGrid56,1)] _SPS_DebugSource("Source", Float) = 1
        [Enum(Any,0,OrificeSocket,1,PlugResolver,2)] _SPS_DebugProduct("Product Filter", Float) = 0
        [Toggle] _SPS_DebugShowCellBitmap("Show Slot Bitmap", Float) = 1
        [Toggle] _SPS_DebugShowCellLegend("Show Slot Bitmap Legend", Float) = 1
        [Toggle] _SPS_DebugShowCellMap("Show Bitmap Zone Map Overlay", Float) = 0
        _SPS_DebugScroll("Scroll", Range(0, 1)) = 0
        _SPS_DebugCacheRecords("Distance Scan Cap", Range(8, 256)) = 128
        _SPS_DebugCellBitmapSize("Slot Bitmap Size", Range(0.1, 0.5)) = 0.28
        _SPS_DebugCellBitmapPadding("Slot Bitmap Padding", Range(0, 0.2)) = 0.02
        _SPS_DebugOpacity("Opacity", Range(0, 1)) = 1
        _SPS_DebugFontWeight("Font Weight", Range(0.25, 0.55)) = 0.5
        _SPS_DebugFontSoftness("Font Softness", Range(0.5, 4)) = 1.5
        _SPS_DebugTextColor("Text Color", Color) = (0.75, 1, 0.85, 1)
        _SPS_DebugBackColor("Back Color", Color) = (0.015, 0.02, 0.025, 1)
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 8
        [Enum(Off,0, On,1)] _ZWrite("ZWrite", Float) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 0
        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOp("Blend Op", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0
    }

    SubShader {
        Tags {
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True"
            "VRCFallback" = "Hidden"
        }

        Pass {
            Cull [_Cull]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            BlendOp [_BlendOp]
            Blend [_SrcBlend] [_DstBlend]

            CGPROGRAM
            #pragma target 4.0
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            #include "Packages/com.vrcfury.vrcfury/SPS/common/sps_cell_layout.cginc"
            #include "Packages/com.vrcfury.vrcfury/SPS/common/sps_types.cginc"
            #include "Packages/com.vrcfury.vrcfury/SPS/resolver/sps_resolver_payload.cginc"
            #include "SpsDebugDirectScan.cginc"

            #define PANEL_COLS 92
            #define PANEL_ROWS 32
            #define FONT_COLS 16.0
            #define FONT_ROWS 6.0
            #define UINT_W 10
            #define FLOAT_W 9
            sampler2D _SPS_DebugFontAtlas;
            sampler2D _SPS_DebugCellLegendTex;
            sampler2D _SPS_DebugResolverLegendTex;
            float _SPS_DebugSource;
            float _SPS_DebugProduct;
            float _SPS_DebugShowCellBitmap;
            float _SPS_DebugShowCellLegend;
            float _SPS_DebugShowCellMap;
            float _SPS_DebugScroll;
            float _SPS_DebugCacheRecords;
            float _SPS_DebugCellBitmapSize;
            float _SPS_DebugCellBitmapPadding;
            float _SPS_DebugOpacity;
            float _SPS_DebugFontWeight;
            float _SPS_DebugFontSoftness;
            float4 _SPS_DebugTextColor;
            float4 _SPS_DebugBackColor;

            SPS_INIT_TEX(_VFGridFinal)
            SPS_INIT_TEX(_VFGrid56)

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2g {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                nointerpolation int selectedSlot : TEXCOORD1;
                nointerpolation uint selectedCount : TEXCOORD2;
                nointerpolation uint selectedIndex : TEXCOORD3;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2g vert(appdata v) {
                UNITY_SETUP_INSTANCE_ID(v);
                v2g o;
                UNITY_INITIALIZE_OUTPUT(v2g, o);
                o.vertex = v.vertex;
                o.uv = v.uv;
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                return o;
            }

            void emit_auto_vertex(
                float2 local,
                float2 uv,
                int selectedSlot,
                uint selectedCount,
                uint selectedIndex,
                inout TriangleStream<v2f> stream
            ) {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(float4(local, 0.0, 1.0));
                o.uv = uv;
                o.selectedSlot = selectedSlot;
                o.selectedCount = selectedCount;
                o.selectedIndex = selectedIndex;
                stream.Append(o);
            }

            [maxvertexcount(4)]
            void geom(triangle v2g input[3], uint primitiveId : SV_PrimitiveID, inout TriangleStream<v2f> stream) {
                UNITY_SETUP_INSTANCE_ID(input[0]);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input[0]);
                if (primitiveId != 0u) return;

                SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                float3 panelWorld = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                uint filter = min((uint)round(_SPS_DebugProduct), SPS_DEBUG_PRODUCT_PLUG);
                uint limit = min(max((uint)round(_SPS_DebugCacheRecords), 1u), SPS_DEBUG_DIRECT_MAX_RESULTS);
                uint count = sps_debug_direct_count(tex, filter, panelWorld, limit);
                uint selectedIndex = count == 0u
                    ? 0u
                    : (uint)round(saturate(_SPS_DebugScroll) * (float)(count - 1u));

                uint selectedSlot = 0u;
                uint selectedProduct = 0u;
                uint selectedDistanceKey = 0u;
                float3 selectedWorld = 0.0;
                bool found = count > 0u && sps_debug_direct_select(
                    tex,
                    filter,
                    panelWorld,
                    selectedIndex,
                    limit,
                    selectedSlot,
                    selectedProduct,
                    selectedWorld,
                    selectedDistanceKey
                );
                int slot = found ? (int)selectedSlot : -1;

                emit_auto_vertex(float2(-0.5,  0.5), float2(0, 1), slot, count, selectedIndex, stream);
                emit_auto_vertex(float2( 0.5,  0.5), float2(1, 1), slot, count, selectedIndex, stream);
                emit_auto_vertex(float2(-0.5, -0.5), float2(0, 0), slot, count, selectedIndex, stream);
                emit_auto_vertex(float2( 0.5, -0.5), float2(1, 0), slot, count, selectedIndex, stream);
                stream.RestartStrip();
            }

            uint pow10u(int power) {
                if (power <= 0) return 1u;
                if (power == 1) return 10u;
                if (power == 2) return 100u;
                if (power == 3) return 1000u;
                if (power == 4) return 10000u;
                if (power == 5) return 100000u;
                if (power == 6) return 1000000u;
                if (power == 7) return 10000000u;
                if (power == 8) return 100000000u;
                return 1000000000u;
            }

            int digit_char(uint digit) {
                return 48 + (int)min(digit, 9u);
            }

            int uint_char(uint value, int pos, int width) {
                if (pos < 0 || pos >= width) return 32;
                uint div = pow10u(width - 1 - pos);
                return digit_char((value / div) % 10u);
            }

            int float_char(float value, int pos) {
                if (pos < 0 || pos >= FLOAT_W) return 32;
                bool neg = value < 0.0;
                float av = min(abs(value), 9999.999);
                uint scaled = (uint)round(av * 1000.0);
                if (pos == 0) return neg ? 45 : 32;
                if (pos == 5) return 46;
                int digitPos = pos < 5 ? pos - 1 : pos - 2;
                uint div = pow10u(6 - digitPos);
                return digit_char((scaled / div) % 10u);
            }

            int word_char(int word, int pos) {
                int ch = 32;
                if (pos < 0) return ch;
                if (word == 0) { if (pos == 0) ch = 83; if (pos == 1) ch = 80; if (pos == 2) ch = 83; }
                if (word == 1) { if (pos == 0) ch = 65; if (pos == 1) ch = 85; if (pos == 2) ch = 84; if (pos == 3) ch = 79; }
                if (word == 2) { if (pos == 0) ch = 73; if (pos == 1) ch = 78; if (pos == 2) ch = 83; if (pos == 3) ch = 80; if (pos == 4) ch = 69; if (pos == 5) ch = 67; if (pos == 6) ch = 84; }
                if (word == 3) { if (pos == 0) ch = 83; if (pos == 1) ch = 82; if (pos == 2) ch = 67; }
                if (word == 4) { if (pos == 0) ch = 70; if (pos == 1) ch = 73; if (pos == 2) ch = 78; if (pos == 3) ch = 65; if (pos == 4) ch = 76; }
                if (word == 5) { if (pos == 0) ch = 82; if (pos == 1) ch = 65; if (pos == 2) ch = 87; }
                if (word == 6) { if (pos == 0) ch = 83; if (pos == 1) ch = 67; if (pos == 2) ch = 82; if (pos == 3) ch = 79; if (pos == 4) ch = 76; if (pos == 5) ch = 76; }
                if (word == 7) { if (pos == 0) ch = 87; if (pos == 1) ch = 73; if (pos == 2) ch = 78; }
                if (word == 8) { if (pos == 0) ch = 83; if (pos == 1) ch = 76; if (pos == 2) ch = 79; if (pos == 3) ch = 84; }
                if (word == 9) { if (pos == 0) ch = 86; if (pos == 1) ch = 65; if (pos == 2) ch = 76; if (pos == 3) ch = 73; if (pos == 4) ch = 68; }
                if (word == 10) { if (pos == 0) ch = 77; if (pos == 1) ch = 73; if (pos == 2) ch = 83; if (pos == 3) ch = 83; }
                if (word == 11) { if (pos == 0) ch = 73; if (pos == 1) ch = 68; }
                if (word == 12) { if (pos == 0) ch = 80; if (pos == 1) ch = 76; if (pos == 2) ch = 65; if (pos == 3) ch = 89; }
                if (word == 13) { if (pos == 0) ch = 87; if (pos == 1) ch = 79; if (pos == 2) ch = 82; if (pos == 3) ch = 76; if (pos == 4) ch = 68; }
                if (word == 14) { if (pos == 0) ch = 70; if (pos == 1) ch = 87; if (pos == 2) ch = 68; }
                if (word == 15) { if (pos == 0) ch = 85; if (pos == 1) ch = 80; }
                if (word == 16) { if (pos == 0) ch = 83; if (pos == 1) ch = 67; if (pos == 2) ch = 65; if (pos == 3) ch = 76; if (pos == 4) ch = 69; }
                if (word == 17) { if (pos == 0) ch = 70; if (pos == 1) ch = 76; if (pos == 2) ch = 65; if (pos == 3) ch = 71; }
                if (word == 18) { if (pos == 0) ch = 78; if (pos == 1) ch = 69; if (pos == 2) ch = 88; if (pos == 3) ch = 84; }
                if (word == 19) { if (pos == 0) ch = 84; if (pos == 1) ch = 65; if (pos == 2) ch = 71; }
                if (word == 20) { if (pos == 0) ch = 82; if (pos == 1) ch = 69; if (pos == 2) ch = 80; if (pos == 3) ch = 76; }
                if (word == 21) { if (pos == 0) ch = 68; if (pos == 1) ch = 73; if (pos == 2) ch = 83; if (pos == 3) ch = 84; }
                if (word == 22) { if (pos == 0) ch = 68; if (pos == 1) ch = 69; if (pos == 2) ch = 68; if (pos == 3) ch = 85; if (pos == 4) ch = 80; }
                if (word == 23) { if (pos == 0) ch = 79; if (pos == 1) ch = 82; if (pos == 2) ch = 73; if (pos == 3) ch = 70; }
                if (word == 24) { if (pos == 0) ch = 80; if (pos == 1) ch = 76; if (pos == 2) ch = 85; if (pos == 3) ch = 71; }
                if (word == 25) { if (pos == 0) ch = 76; if (pos == 1) ch = 69; if (pos == 2) ch = 78; }
                if (word == 26) { if (pos == 0) ch = 87; if (pos == 1) ch = 73; if (pos == 2) ch = 68; }
                if (word == 27) { if (pos == 0) ch = 83; if (pos == 1) ch = 79; if (pos == 2) ch = 67; if (pos == 3) ch = 75; }
                if (word == 28) { if (pos == 0) ch = 70; if (pos == 1) ch = 82; if (pos == 2) ch = 65; if (pos == 3) ch = 67; }
                if (word == 29) { if (pos == 0) ch = 83; if (pos == 1) ch = 49; }
                if (word == 30) { if (pos == 0) ch = 83; if (pos == 1) ch = 50; }
                if (word == 31) { if (pos == 0) ch = 83; if (pos == 1) ch = 51; }
                if (word == 32) { if (pos == 0) ch = 83; if (pos == 1) ch = 52; }
                if (word == 33) { if (pos == 0) ch = 83; if (pos == 1) ch = 53; }
                if (word == 34) { if (pos == 0) ch = 67; if (pos == 1) ch = 78; if (pos == 2) ch = 84; }
                if (word == 35) { if (pos == 0) ch = 84; if (pos == 1) ch = 89; if (pos == 2) ch = 80; if (pos == 3) ch = 69; }
                if (word == 36) { if (pos == 0) ch = 84; if (pos == 1) ch = 71; if (pos == 2) ch = 84; }
                if (word == 37) { if (pos == 0) ch = 72; if (pos == 1) ch = 79; if (pos == 2) ch = 76; if (pos == 3) ch = 69; }
                if (word == 38) { if (pos == 0) ch = 82; if (pos == 1) ch = 73; if (pos == 2) ch = 78; if (pos == 3) ch = 71; }
                if (word == 39) { if (pos == 0) ch = 68; if (pos == 1) ch = 73; if (pos == 2) ch = 83; if (pos == 3) ch = 84; }
                return ch;
            }

            int word_at(int col, int start, int word) {
                return word_char(word, col - start);
            }

            int uint_at(int col, int start, uint value, int width) {
                return uint_char(value, col - start, width);
            }

            int float_at(int col, int start, float value) {
                return float_char(value, col - start);
            }

            int vec3_char(float3 value, int col, int start) {
                int ch = 32;
                if (col >= start && col < start + FLOAT_W) ch = float_at(col, start, value.x);
                if (col >= start + 10 && col < start + 10 + FLOAT_W) ch = float_at(col, start + 10, value.y);
                if (col >= start + 20 && col < start + 20 + FLOAT_W) ch = float_at(col, start + 20, value.z);
                return ch;
            }

            float world_distance(float3 world) {
                float3 panelWorld = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                return length(world - panelWorld);
            }

            bool cell_valid(SpsTexture tex, int cellIndex) {
                if (cellIndex < 0) return false;
                if ((uint)cellIndex >= sps_socket_slot_count()) return false;
                SpsCell cell = sps_get_cell(tex, cellIndex);
                return sps_cell_check_magic(cell) && cell.read_uint(SPS_HEADER_VENDOR_INDEX) == SPS_VENDOR_SPS;
            }

            uint selected_scroll_index(uint count) {
                if (count == 0u) return 0u;
                return (uint)round(saturate(_SPS_DebugScroll) * (float)(count - 1u));
            }

            int range_bar_char(int col, int start, int width, uint count, uint selectedIndex) {
                int p = col - start;
                if (p < 0 || p >= width) return 32;
                if (count <= 1u) return 61;
                float x = ((float)p + 0.5) / (float)max(width, 1);
                float target = (float)selectedIndex / (float)(count - 1u);
                float markerWidth = 1.0 / (float)max(width, 1);
                return abs(x - target) <= markerWidth ? 61 : 45;
            }

            int top_char(int row, int col, uint count, uint selectedIndex, int selectedSlot) {
                if (row == 0) {
                    if (col >= 1 && col < 4) return word_at(col, 1, 0);
                    if (col >= 5 && col < 9) return word_at(col, 5, 1);
                    if (col >= 10 && col < 17) return word_at(col, 10, 2);
                }
                if (row == 1) {
                    if (col >= 1 && col < 4) return word_at(col, 1, 3);
                    if (col == 4) return 58;
                    if (col >= 6 && col < 11) return _SPS_DebugSource > 0.5 ? word_at(col, 6, 5) : word_at(col, 6, 4);
                    if (col >= 14 && col < 20) return word_at(col, 14, 6);
                    if (col == 20) return 58;
                    if (col >= 22 && col < 31) return float_at(col, 22, saturate(_SPS_DebugScroll));
                }
                if (row == 2) {
                    if (col >= 1 && col < 4) return word_at(col, 1, 36);
                    if (col == 4) return 58;
                    if (col >= 6 && col < 11) return uint_at(col, 6, count > 0u ? selectedIndex + 1u : 0u, 5);
                    if (col == 11) return 47;
                    if (col >= 13 && col < 18) return uint_at(col, 13, count, 5);
                    if (col >= 20 && col < 24) return word_at(col, 20, 8);
                    if (col == 24) return 58;
                    if (col >= 26 && col < 31) return uint_at(col, 26, (uint)max(selectedSlot, 0), 5);
                    if (col == 33) return 91;
                    if (col >= 34 && col < 74) return range_bar_char(col, 34, 40, count, selectedIndex);
                    if (col == 74) return 93;
                }
                return 32;
            }

            bool inspect_text_may_use_column(int row, int col) {
                if (row == 3) return col < 40;
                if (row == 4) return col < 34;
                if (row == 5) return col < 37;
                if (row == 6) return col < 35;
                if (row == 7) return col < 39;
                if (row == 8) return col < 17;
                if (row == 9) return col < 50;
                if (row == 10 || row == 11) return col < 52;
                if (row == 12) return col < 37;
                if (row == 13) return col < 37;
                return false;
            }

            bool possible_panel_text_cell(int row, int col) {
                if (row == 0) return (col >= 1 && col < 4) || (col >= 5 && col < 9) || (col >= 10 && col < 17);
                if (row == 1) {
                    return (col >= 1 && col < 5) || (col >= 6 && col < 11) ||
                        (col >= 14 && col < 21) || (col >= 22 && col < 31);
                }
                if (row == 2) {
                    return (col >= 1 && col < 31) || col == 33 || (col >= 34 && col <= 74);
                }
                return row >= 3 && row <= 13 && inspect_text_may_use_column(row, col);
            }

            int plug_inspect_char(SpsCell cell, int row, int col) {
                if (row == 4) {
                    if (col >= 1 && col < 3) return word_at(col, 1, 11);
                    if (col == 3) return 58;
                    if (col >= 5 && col < 15) return uint_at(col, 5, cell.read_uint(SPS_HEADER_UNIQUE_ID_INDEX), UINT_W);
                    if (col >= 18 && col < 22) return word_at(col, 18, 12);
                    if (col == 22) return 58;
                    if (col >= 24 && col < 34) return uint_at(col, 24, cell.read_uint(SPS_HEADER_PLAYER_ID_INDEX), UINT_W);
                }
                if (row == 5) {
                    if (col >= 1 && col < 6) return word_at(col, 1, 13);
                    if (col == 6) return 58;
                    return vec3_char(sps_cell_header_world(cell), col, 8);
                }
                if (row == 6) {
                    if (col >= 1 && col < 4) return word_at(col, 1, 25);
                    if (col == 4) return 58;
                    if (col >= 6 && col < 15) return float_at(col, 6, cell.read_float(sps_cell_pixel_index_from_payload_index(SPS_RESOLVER_METADATA_LENGTH_INDEX)));
                    if (col >= 18 && col < 21) return word_at(col, 18, 26);
                    if (col == 21) return 58;
                    if (col >= 23 && col < 32) {
                        float radius = cell.read_float(sps_cell_pixel_index_from_payload_index(SPS_RESOLVER_METADATA_RADIUS_INDEX));
                        return float_at(col, 23, radius * 2.0);
                    }
                }
                if (row == 7) {
                    if (col >= 1 && col < 5) return word_at(col, 1, 27);
                    if (col >= 6 && col < 8) return word_at(col, 6, 11);
                    if (col == 8) return 58;
                    if (col >= 10 && col < 20) return uint_at(col, 10, cell.read_uint(sps_cell_pixel_index_from_payload_index(SPS_RESOLVER_METADATA_SOCKET_UNIQUE_ID_INDEX)), UINT_W);
                    if (col >= 22 && col < 26) return word_at(col, 22, 12);
                    if (col == 26) return 58;
                    if (col >= 28 && col < 38) return uint_at(col, 28, cell.read_uint(sps_cell_pixel_index_from_payload_index(SPS_RESOLVER_METADATA_SOCKET_PLAYER_ID_INDEX)), UINT_W);
                }
                if (row == 8) {
                    if (col >= 1 && col < 5) return word_at(col, 1, 28);
                    if (col == 5) return 58;
                    if (col >= 7 && col < 16) return float_at(col, 7, cell.read_float(sps_cell_pixel_index_from_payload_index(SPS_RESOLVER_METADATA_SOCKET_FRACTION_INDEX)));
                }
                if (row >= 9 && row <= 13) {
                    int seg = row - 8;
                    int word = 28 + seg;
                    if (col >= 1 && col < 3) return word_at(col, 1, word);
                    if (col == 3) return 58;
                    return vec3_char(sps_read_resolver_chain_world(cell, seg), col, 5);
                }
                return 32;
            }

            int inspect_char(SpsTexture tex, int row, int col, int slot, uint count, uint selectedIndex) {
                int ch = top_char(row, col, count, selectedIndex, slot);
                if (ch != 32) return ch;
                if (row < 3 || row > 13) return 32;
                if (!inspect_text_may_use_column(row, col)) return 32;

                bool valid = cell_valid(tex, slot);

                if (row == 3) {
                    if (col >= 1 && col < 5) return word_at(col, 1, 8);
                    if (col == 5) return 58;
                    uint shownSlot = (uint)max(slot, 0);
                    if (col >= 7 && col < 12) return uint_at(col, 7, shownSlot, 5);
                    if (col >= 15 && col < 20) return word_at(col, 15, 9);
                    if (col == 20) return 58;
                    if (col >= 22 && col < 27) return valid ? word_at(col, 22, 9) : word_at(col, 22, 10);
                    if (col >= 30 && col < 34) return word_at(col, 30, 35);
                    if (col == 34) return 58;
                    if (valid && col >= 36 && col < 40) {
                        SpsCell typeCell = sps_get_cell(tex, slot);
                        if (typeCell.read_uint(SPS_HEADER_PRODUCT_INDEX) == SPS_DEBUG_PRODUCT_PLUG) return word_at(col, 36, 24);
                        uint flags = typeCell.read_uint(sps_cell_pixel_index_from_payload_index(SPS_SOCKET_PAYLOAD_FLAGS));
                        return (flags & SPS_SOCKET_FLAG_HOLE) != 0u ? word_at(col, 36, 37) : word_at(col, 36, 38);
                    }
                }
                if (!valid) return 32;

                SpsCell cell = sps_get_cell(tex, slot);
                if (cell.read_uint(SPS_HEADER_PRODUCT_INDEX) == SPS_DEBUG_PRODUCT_PLUG) return plug_inspect_char(cell, row, col);
                if (row == 4) {
                    if (col >= 1 && col < 3) return word_at(col, 1, 11);
                    if (col == 3) return 58;
                    if (col >= 5 && col < 15) return uint_at(col, 5, cell.read_uint(SPS_HEADER_UNIQUE_ID_INDEX), UINT_W);
                    if (col >= 18 && col < 22) return word_at(col, 18, 12);
                    if (col == 22) return 58;
                    if (col >= 24 && col < 34) return uint_at(col, 24, cell.read_uint(SPS_HEADER_PLAYER_ID_INDEX), UINT_W);
                }
                if (row == 5) {
                    if (col >= 1 && col < 6) return word_at(col, 1, 13);
                    if (col == 6) return 58;
                    return vec3_char(sps_cell_header_world(cell), col, 8);
                }
                if (row == 6) {
                    if (col >= 1 && col < 4) return word_at(col, 1, 14);
                    if (col == 4) return 58;
                    return vec3_char(sps_cell_header_forward(cell), col, 6);
                }
                if (row == 7) {
                    if (col >= 1 && col < 3) return word_at(col, 1, 15);
                    if (col == 3) return 58;
                    return vec3_char(sps_cell_header_up(cell), col, 5);
                }
                if (row == 8) {
                    if (col >= 1 && col < 6) return word_at(col, 1, 16);
                    if (col == 6) return 58;
                    if (col >= 8 && col < 17) return float_at(col, 8, sps_cell_header_scale(cell));
                }
                if (row == 9) {
                    uint flags = cell.read_uint(sps_cell_pixel_index_from_payload_index(SPS_SOCKET_PAYLOAD_FLAGS));
                    uint nextId = cell.read_uint(sps_cell_pixel_index_from_payload_index(SPS_SOCKET_PAYLOAD_NEXT_ID));
                    if (col >= 1 && col < 5) return word_at(col, 1, 17);
                    if (col == 5) return 58;
                    if (col >= 7 && col < 17) return uint_at(col, 7, flags, UINT_W);
                    if (col >= 20 && col < 24) return word_at(col, 20, 18);
                    if (col == 24) return 58;
                    if (col >= 26 && col < 36) return uint_at(col, 26, nextId, UINT_W);
                    if (col >= 39 && col < 43) return word_at(col, 39, 35);
                    if (col == 43) return 58;
                    if (col >= 45 && col < 49) return (flags & SPS_SOCKET_FLAG_HOLE) != 0u ? word_at(col, 45, 37) : word_at(col, 45, 38);
                }
                if (row == 10 || row == 11) {
                    uint baseTag = row == 10 ? 0u : 4u;
                    if (col >= 1 && col < 4) return word_at(col, 1, 19);
                    if (col == 4) return 58;
                    for (uint i = 0u; i < 4u; i++) {
                        int start = 6 + (int)i * 12;
                        if (col >= start && col < start + 10) {
                            uint tag = cell.read_uint(sps_cell_pixel_index_from_payload_index(SPS_SOCKET_PAYLOAD_TAG_START + baseTag + i));
                            return uint_at(col, start, tag, UINT_W);
                        }
                    }
                }
                if (row == 13) {
                    if (col >= 1 && col < 5) return word_at(col, 1, 39);
                    if (col == 5) return 58;
                    if (col >= 7 && col < 16) return float_at(col, 7, world_distance(sps_cell_header_world(cell)));
                }
                return 32;
            }

            float font_alpha(int ascii, float2 local) {
                if (ascii < 33 || ascii > 126) return 0.0;
                int glyph = ascii - 32;
                float2 cell = float2(glyph & 15, glyph >> 4);
                float2 uv = float2((cell.x + local.x) / FONT_COLS, 1.0 - (cell.y + local.y) / FONT_ROWS);
                float sdf = tex2D(_SPS_DebugFontAtlas, uv).a;
                float width = max(fwidth(sdf) * max(_SPS_DebugFontSoftness, 0.01), 0.001);
                return smoothstep(_SPS_DebugFontWeight - width, _SPS_DebugFontWeight + width, sdf);
            }

            int zone_word_char(int word, int pos) {
                int ch = 32;
                if (pos < 0) return ch;
                if (word == 0) { if (pos == 0) ch = 72; if (pos == 1) ch = 68; if (pos == 2) ch = 82; }
                if (word == 1) { if (pos == 0) ch = 80; if (pos == 1) ch = 65; if (pos == 2) ch = 89; if (pos == 3) ch = 76; if (pos == 4) ch = 79; if (pos == 5) ch = 65; if (pos == 6) ch = 68; }
                if (word == 2) { if (pos == 0) ch = 84; if (pos == 1) ch = 73; if (pos == 2) ch = 78; }
                if (word == 3) { if (pos == 0) ch = 84; if (pos == 1) ch = 79; if (pos == 2) ch = 85; if (pos == 3) ch = 84; }
                return ch;
            }

            int zone_word_at(int col, int start, int word) {
                return zone_word_char(word, col - start);
            }

            int bitmap_label_char(int row, int col) {
                if (row == 0) {
                    if (col == 0 || col == 1 || col == 30 || col == 31) return 42;
                    if (col >= 8 && col < 11) return zone_word_at(col, 8, 0);
                }
                if (row == 1) {
                    if (col >= 0 && col < 4) return word_at(col, 0, 17);
                    if (col >= 5 && col < 9) return word_at(col, 5, 18);
                    if (col >= 10 && col < 13) return word_at(col, 10, 19);
                    if (col >= 20 && col < 23) return zone_word_at(col, 20, 2);
                    if (col >= 26 && col < 30) return zone_word_at(col, 26, 3);
                }
                if (row == 7) {
                    if (col >= 12 && col < 19) return zone_word_at(col, 12, 1);
                }
                if (row == 15) {
                    if (col == 0 || col == 1 || col == 30 || col == 31) return 42;
                    if (col >= 3 && col < 8) return word_at(col, 3, 13);
                    if (col >= 10 && col < 13) return word_at(col, 10, 14);
                    if (col >= 15 && col < 17) return word_at(col, 15, 15);
                    if (col >= 20 && col < 25) return word_at(col, 20, 16);
                }
                return 32;
            }

            float3 bitmap_zone_color(uint px, uint py) {
                bool magic = (px == 0u && py == 0u) || (px == 15u && py == 0u) || (px == 0u && py == 15u) || (px == 15u && py == 15u);
                if (magic) return float3(1.0, 1.0, 1.0);
                if (py == 0u) return float3(1.0, 0.72, 0.22);
                if (py == 15u) return float3(0.35, 0.85, 1.0);
                if (py == 1u && px <= 1u) return float3(1.0, 0.35, 0.35);
                if (py == 1u && px >= 2u && px <= 9u) return float3(0.7, 0.95, 0.35);
                if (py == 1u && px >= 10u) return float3(0.95, 0.55, 1.0);
                return float3(0.22, 0.44, 1.0);
            }

            bool cell_box_uv(float2 panelUv, float yOffset, out float2 cellUv, out float edge) {
                float size = clamp(_SPS_DebugCellBitmapSize, 0.1, 0.5);
                float pad = saturate(_SPS_DebugCellBitmapPadding);
                float2 minUv = float2(1.0 - pad - size, yOffset);
                float2 maxUv = float2(1.0 - pad, yOffset + size);
                cellUv = float2(0.0, 0.0);
                edge = 0.0;
                if (panelUv.x < minUv.x || panelUv.y < minUv.y || panelUv.x > maxUv.x || panelUv.y > maxUv.y) return false;
                cellUv = saturate((panelUv - minUv) / max(maxUv - minUv, float2(0.0001, 0.0001)));
                float2 edgeDist = min(cellUv, 1.0 - cellUv);
                edge = min(edgeDist.x, edgeDist.y);
                return true;
            }

            bool cell_bitmap_uv(float2 panelUv, out float2 cellUv, out float edge) {
                float pad = saturate(_SPS_DebugCellBitmapPadding);
                return cell_box_uv(panelUv, pad, cellUv, edge);
            }

            bool cell_legend_uv(float2 panelUv, out float2 cellUv, out float edge) {
                float size = clamp(_SPS_DebugCellBitmapSize, 0.1, 0.5);
                float pad = saturate(_SPS_DebugCellBitmapPadding);
                return cell_box_uv(panelUv, pad + size + pad, cellUv, edge);
            }

            bool selected_cell_is_plug(SpsTexture tex, int slot) {
                uint filter = (uint)round(_SPS_DebugProduct);
                if (filter == SPS_DEBUG_PRODUCT_PLUG) return true;
                if (filter == SPS_DEBUG_PRODUCT_SOCKET) return false;
                if (!cell_valid(tex, slot)) return false;
                return sps_get_cell(tex, slot).read_uint(SPS_HEADER_PRODUCT_INDEX) == SPS_DEBUG_PRODUCT_PLUG;
            }

            float4 cell_legend_color(SpsTexture tex, int slot, float2 cellUv, float edge) {
                if (edge < 0.025) {
                    float4 border = _SPS_DebugTextColor;
                    border.a *= _SPS_DebugOpacity;
                    return border;
                }
                float2 innerUv = saturate((cellUv - 0.035) / 0.93);
                float4 color = tex2D(_SPS_DebugCellLegendTex, innerUv);
                if (selected_cell_is_plug(tex, slot)) color = tex2D(_SPS_DebugResolverLegendTex, innerUv);
                color.a *= _SPS_DebugOpacity;
                return color;
            }

            float4 cell_bitmap_color(SpsTexture tex, int slot, float2 cellUv, float edge) {
                if (edge < 0.025) {
                    float4 border = _SPS_DebugTextColor;
                    border.a *= _SPS_DebugOpacity;
                    return border;
                }

                if (!cell_valid(tex, slot)) {
                    float4 empty = _SPS_DebugBackColor;
                    empty.a *= _SPS_DebugOpacity;
                    return empty;
                }

                float2 innerUv = saturate((cellUv - 0.035) / 0.93);
                uint px = min((uint)floor(innerUv.x * (float)SPS_CELL_WIDTH), (uint)(SPS_CELL_WIDTH - 1));
                uint py = min((uint)floor((1.0 - innerUv.y) * (float)SPS_CELL_HEIGHT), (uint)(SPS_CELL_HEIGHT - 1));
                SpsCell cell = sps_get_cell(tex, slot);
                float4 color = cell.read_rgba_raw(uint2(px, py));
                if (_SPS_DebugShowCellMap > 0.5) {
                    float cellLine = min(frac(innerUv.x * (float)SPS_CELL_WIDTH), frac((1.0 - innerUv.y) * (float)SPS_CELL_HEIGHT));
                    float gridLine = cellLine < 0.055 ? 0.18 : 0.0;
                    float overlay = max(0.28, gridLine);
                    color.rgb = lerp(color.rgb, bitmap_zone_color(px, py), overlay);

                    float2 labelGrid = float2(cellUv.x * 32.0, (1.0 - cellUv.y) * 16.0);
                    int labelCol = (int)floor(labelGrid.x);
                    int labelRow = (int)floor(labelGrid.y);
                    float labelA = font_alpha(bitmap_label_char(labelRow, labelCol), frac(labelGrid));
                    color.rgb = lerp(color.rgb, _SPS_DebugTextColor.rgb, labelA);
                }
                color.a = _SPS_DebugOpacity;
                return color;
            }

            float4 draw_panel(SpsTexture tex, float2 panelUv, int selectedSlot, uint selectedCount, uint selectedIndex) {
                if (_SPS_DebugOpacity <= 0.001) return float4(0, 0, 0, 0);

                float2 cellUv = float2(0.0, 0.0);
                float cellEdge = 0.0;
                if (_SPS_DebugShowCellLegend > 0.5) {
                    if (cell_legend_uv(panelUv, cellUv, cellEdge)) {
                        return cell_legend_color(tex, selectedSlot, cellUv, cellEdge);
                    }
                }
                if (_SPS_DebugShowCellBitmap > 0.5) {
                    if (cell_bitmap_uv(panelUv, cellUv, cellEdge)) {
                        return cell_bitmap_color(tex, selectedSlot, cellUv, cellEdge);
                    }
                }

                float2 grid = float2(panelUv.x * PANEL_COLS, (1.0 - panelUv.y) * PANEL_ROWS);
                int col = (int)floor(grid.x);
                int row = (int)floor(grid.y);
                if (!possible_panel_text_cell(row, col)) {
                    float4 bg = _SPS_DebugBackColor;
                    bg.a *= _SPS_DebugOpacity;
                    return bg;
                }
                int ascii = inspect_char(tex, row, col, selectedSlot, selectedCount, selectedIndex);
                float a = font_alpha(ascii, frac(grid));
                float4 color = lerp(_SPS_DebugBackColor, _SPS_DebugTextColor, a);
                color.a *= _SPS_DebugOpacity;
                return color;
            }

            float4 frag(v2f i, fixed facing : VFACE) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float2 panelUv = i.uv;
                if (facing < 0.0) panelUv.x = 1.0 - panelUv.x;
                if (_SPS_DebugSource > 0.5) {
                    SpsTexture tex = SPS_GET_TEX(_VFGrid56);
                    return draw_panel(tex, panelUv, i.selectedSlot, i.selectedCount, i.selectedIndex);
                } else {
                    SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                    return draw_panel(tex, panelUv, i.selectedSlot, i.selectedCount, i.selectedIndex);
                }
            }
            ENDCG
        }
    }

    Fallback Off
}
