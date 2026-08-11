Shader "Hidden/VRCFury/SpsDebugCachedSlotTable" {
    Properties {
        _SPS_DebugFontAtlas("Font Atlas", 2D) = "white" {}
        _SPS_DebugCacheRecords("Target Cap", Range(8, 128)) = 128
        _SPS_DebugScroll("Scroll", Range(0, 1)) = 0
        _SPS_DebugMaxRows("Max Visible Rows", Range(1, 28)) = 16
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

            #define PANEL_COLS 97
            #define PANEL_ROWS 32
            #define FONT_COLS 16.0
            #define FONT_ROWS 6.0
            #define UINT_W 10
            #define FLOAT_W 9
            #define TABLE_FIRST_ROW 4
            sampler2D _SPS_DebugFontAtlas;
            float _SPS_DebugCacheRecords;
            float _SPS_DebugScroll;
            float _SPS_DebugMaxRows;
            float _SPS_DebugOpacity;
            float _SPS_DebugFontWeight;
            float _SPS_DebugFontSoftness;
            float4 _SPS_DebugTextColor;
            float4 _SPS_DebugBackColor;

            SPS_INIT_TEX(_VFGridFinal)

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
                nointerpolation int layerRow : TEXCOORD1;
                nointerpolation int selectedSlot : TEXCOORD2;
                nointerpolation uint displayCount : TEXCOORD3;
                nointerpolation uint displayStart : TEXCOORD4;
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
                if (word == 1) { if (pos == 0) ch = 67; if (pos == 1) ch = 65; if (pos == 2) ch = 67; if (pos == 3) ch = 72; if (pos == 4) ch = 69; }
                if (word == 2) { if (pos == 0) ch = 82; if (pos == 1) ch = 69; if (pos == 2) ch = 67; if (pos == 3) ch = 79; if (pos == 4) ch = 82; if (pos == 5) ch = 68; }
                if (word == 3) { if (pos == 0) ch = 84; if (pos == 1) ch = 65; if (pos == 2) ch = 66; if (pos == 3) ch = 76; if (pos == 4) ch = 69; }
                if (word == 4) { if (pos == 0) ch = 85; if (pos == 1) ch = 83; if (pos == 2) ch = 69; if (pos == 3) ch = 68; }
                if (word == 5) { if (pos == 0) ch = 67; if (pos == 1) ch = 65; if (pos == 2) ch = 80; }
                if (word == 6) { if (pos == 0) ch = 87; if (pos == 1) ch = 73; if (pos == 2) ch = 78; }
                if (word == 7) { if (pos == 0) ch = 83; if (pos == 1) ch = 76; if (pos == 2) ch = 79; if (pos == 3) ch = 84; }
                if (word == 8) { if (pos == 0) ch = 73; if (pos == 1) ch = 68; }
                if (word == 9) { if (pos == 0) ch = 80; if (pos == 1) ch = 76; if (pos == 2) ch = 65; if (pos == 3) ch = 89; }
                if (word == 10) { if (pos == 0) ch = 87; if (pos == 1) ch = 79; if (pos == 2) ch = 82; if (pos == 3) ch = 76; if (pos == 4) ch = 68; }
                if (word == 11) { if (pos == 0) ch = 86; if (pos == 1) ch = 65; if (pos == 2) ch = 76; }
                if (word == 12) { if (pos == 0) ch = 68; if (pos == 1) ch = 85; if (pos == 2) ch = 80; }
                if (word == 13) { if (pos == 0) ch = 84; if (pos == 1) ch = 89; if (pos == 2) ch = 80; if (pos == 3) ch = 69; }
                if (word == 14) { if (pos == 0) ch = 82; if (pos == 1) ch = 73; if (pos == 2) ch = 78; if (pos == 3) ch = 71; }
                if (word == 15) { if (pos == 0) ch = 80; if (pos == 1) ch = 76; if (pos == 2) ch = 85; if (pos == 3) ch = 71; }
                if (word == 16) { if (pos == 0) ch = 77; if (pos == 1) ch = 79; if (pos == 2) ch = 68; if (pos == 3) ch = 69; }
                if (word == 17) { if (pos == 0) ch = 69; if (pos == 1) ch = 88; if (pos == 2) ch = 65; if (pos == 3) ch = 67; if (pos == 4) ch = 84; }
                if (word == 18) { if (pos == 0) ch = 70; if (pos == 1) ch = 65; if (pos == 2) ch = 83; if (pos == 3) ch = 84; }
                if (word == 19) { if (pos == 0) ch = 86; if (pos == 1) ch = 73; if (pos == 2) ch = 69; if (pos == 3) ch = 87; }
                if (word == 20) { if (pos == 0) ch = 72; if (pos == 1) ch = 79; if (pos == 2) ch = 76; if (pos == 3) ch = 69; }
                if (word == 21) { if (pos == 0) ch = 82; if (pos == 1) ch = 73; if (pos == 2) ch = 78; if (pos == 3) ch = 71; }
                if (word == 22) { if (pos == 0) ch = 75; if (pos == 1) ch = 73; if (pos == 2) ch = 78; if (pos == 3) ch = 68; }
                if (word == 23) { if (pos == 0) ch = 68; if (pos == 1) ch = 73; if (pos == 2) ch = 83; if (pos == 3) ch = 84; }
                if (word == 24) { if (pos == 0) ch = 87; if (pos == 1) ch = 73; if (pos == 2) ch = 68; }
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
                if (col >= start && col < start + FLOAT_W) return float_at(col, start, value.x);
                if (col >= start + 10 && col < start + 10 + FLOAT_W) return float_at(col, start + 10, value.y);
                if (col >= start + 20 && col < start + 20 + FLOAT_W) return float_at(col, start + 20, value.z);
                return 32;
            }

            uint scan_result_limit() {
                return min(max((uint)round(_SPS_DebugCacheRecords), 1u), SPS_DEBUG_DIRECT_MAX_RESULTS);
            }

            bool table_cell_valid(SpsTexture tex, int slot) {
                if (slot < 0 || (uint)slot >= sps_socket_slot_count()) return false;
                SpsCell cell = sps_get_cell(tex, slot);
                if (!sps_cell_check_magic(cell)) return false;
                if (cell.read_uint(SPS_HEADER_VENDOR_INDEX) != SPS_VENDOR_SPS) return false;
                uint product = cell.read_uint(SPS_HEADER_PRODUCT_INDEX);
                return product == SPS_DEBUG_PRODUCT_SOCKET || product == SPS_DEBUG_PRODUCT_PLUG;
            }

            float cell_distance(SpsCell cell) {
                float3 panelWorld = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                return length(sps_cell_header_world(cell) - panelWorld);
            }

            uint visible_row_count() {
                return min(max(1u, (uint)round(max(_SPS_DebugMaxRows, 1.0))), 28u);
            }

            uint display_start_index(uint count, uint rows) {
                if (count <= rows) return 0u;
                return (uint)round(saturate(_SPS_DebugScroll) * (float)(count - rows));
            }

            uint display_last_index(uint count, uint start, uint rows) {
                if (count == 0u) return 0u;
                return min(start + rows - 1u, count - 1u);
            }

            int range_bar_char(int col, int barStart, int width, uint count, uint rows, uint first, uint last) {
                int p = col - barStart;
                if (p < 0 || p >= width) return 32;
                if (count <= rows) return 61;

                float x = ((float)p + 0.5) / (float)max(width, 1);
                float a = (float)first / (float)max(count, 1u);
                float b = (float)(last + 1u) / (float)max(count, 1u);
                return (x >= a && x <= b) ? 61 : 45;
            }

            int top_char(int row, int col, uint count, uint first, uint last, uint rows) {
                if (row == 0) {
                    if (col >= 1 && col < 4) return word_at(col, 1, 0);
                    if (col >= 5 && col < 10) return word_at(col, 5, 1);
                    if (col >= 11 && col < 17) return word_at(col, 11, 2);
                    if (col >= 18 && col < 23) return word_at(col, 18, 3);
                }
                if (row == 1) {
                    if (col >= 1 && col < 5) return word_at(col, 1, 4);
                    if (col == 5) return 58;
                    if (col >= 7 && col < 17) return uint_at(col, 7, count, UINT_W);
                    if (col >= 20 && col < 23) return word_at(col, 20, 5);
                    if (col == 23) return 58;
                    if (col >= 25 && col < 35) return uint_at(col, 25, scan_result_limit(), UINT_W);
                    if (col >= 38 && col < 42) return word_at(col, 38, 16);
                    if (col == 42) return 58;
                    if (col >= 44 && col < 49) return word_at(col, 44, 17);
                }
                if (row == 2) {
                    if (col >= 1 && col < 5) return word_at(col, 1, 19);
                    if (col == 5) return 58;
                    if (col >= 6 && col < 16) return uint_at(col, 6, first, UINT_W);
                    if (col == 16) return 45;
                    if (col >= 17 && col < 27) return uint_at(col, 17, last, UINT_W);
                    if (col == 27) return 47;
                    if (col >= 29 && col < 39) return uint_at(col, 29, count, UINT_W);
                    if (col == 41) return 91;
                    if (col >= 42 && col < 82) return range_bar_char(col, 42, 40, count, rows, first, last);
                    if (col == 82) return 93;
                }
                return 32;
            }

            int table_char(
                SpsTexture tex,
                int row,
                int col,
                int selectedSlot,
                uint count,
                uint first,
                uint last,
                uint rows
            ) {
                int ch = top_char(row, col, count, first, last, rows);
                if (ch != 32) return ch;

                if (row == 3) {
                    if (col >= 1 && col < 5) return word_at(col, 1, 7);
                    if (col >= 8 && col < 10) return word_at(col, 8, 8);
                    if (col >= 19 && col < 23) return word_at(col, 19, 9);
                    if (col >= 32 && col < 37) return word_at(col, 32, 10);
                    if (col >= 61 && col < 64) return word_at(col, 61, 11);
                    if (col >= 72 && col < 75) return word_at(col, 72, 24);
                    if (col >= 82 && col < 86) return word_at(col, 82, 13);
                    if (col >= 87 && col < 91) return word_at(col, 87, 23);
                    return 32;
                }

                if (row < TABLE_FIRST_ROW) return 32;
                if (row >= TABLE_FIRST_ROW + (int)rows) return 32;
                if (
                    !(col >= 1 && col < 6) &&
                    !(col >= 8 && col < 18) &&
                    !(col >= 19 && col < 29) &&
                    !(col >= 31 && col < 60) &&
                    !(col >= 61 && col < 71) &&
                    !(col >= 72 && col < 81) &&
                    !(col >= 82 && col < 86) &&
                    !(col >= 87 && col < 96)
                ) return 32;

                if (!table_cell_valid(tex, selectedSlot)) return 32;
                SpsCell cell = sps_get_cell(tex, selectedSlot);
                uint product = cell.read_uint(SPS_HEADER_PRODUCT_INDEX);
                if (col >= 1 && col < 6) return uint_at(col, 1, (uint)selectedSlot, 5);
                if (col >= 8 && col < 18) return uint_at(col, 8, cell.read_uint(SPS_HEADER_UNIQUE_ID_INDEX), UINT_W);
                if (col >= 19 && col < 29) return uint_at(col, 19, cell.read_uint(SPS_HEADER_PLAYER_ID_INDEX), UINT_W);
                if (col >= 31 && col < 60) return vec3_char(sps_cell_header_world(cell), col, 31);
                if (col >= 61 && col < 71) {
                    if (product == SPS_DEBUG_PRODUCT_PLUG) {
                        return float_at(col, 61, cell.read_float(sps_cell_pixel_index_from_payload_index(SPS_RESOLVER_METADATA_LENGTH_INDEX)));
                    }
                    return uint_at(col, 61, cell.read_uint(sps_cell_pixel_index_from_payload_index(SPS_SOCKET_PAYLOAD_FLAGS)), UINT_W);
                }
                if (product == SPS_DEBUG_PRODUCT_PLUG && col >= 72 && col < 81) {
                    float radius = cell.read_float(sps_cell_pixel_index_from_payload_index(SPS_RESOLVER_METADATA_RADIUS_INDEX));
                    return float_at(col, 72, radius * 2.0);
                }
                if (col >= 82 && col < 86) {
                    if (product == SPS_DEBUG_PRODUCT_PLUG) return word_at(col, 82, 15);
                    uint flags = cell.read_uint(sps_cell_pixel_index_from_payload_index(SPS_SOCKET_PAYLOAD_FLAGS));
                    return (flags & SPS_SOCKET_FLAG_HOLE) != 0u ? word_at(col, 82, 20) : word_at(col, 82, 21);
                }
                if (col >= 87 && col < 96) return float_at(col, 87, cell_distance(cell));
                return 32;
            }

            bool possible_text_cell(int row, int col) {
                if (row == 0) return (col >= 1 && col < 23);
                if (row == 1) return (col >= 1 && col < 49);
                if (row == 2) return (col >= 1 && col < 39) || col == 41 || (col >= 42 && col <= 82);
                if (row == 3) {
                    return (col >= 1 && col < 5) || (col >= 8 && col < 10) ||
                        (col >= 19 && col < 23) || (col >= 32 && col < 37) ||
                        (col >= 61 && col < 64) || (col >= 72 && col < 75) ||
                        (col >= 82 && col < 86) || (col >= 87 && col < 91);
                }
                if (row < TABLE_FIRST_ROW) return false;
                if (row >= TABLE_FIRST_ROW + (int)round(max(_SPS_DebugMaxRows, 1.0))) return false;
                return (col >= 1 && col < 6) || (col >= 8 && col < 18) ||
                    (col >= 19 && col < 29) || (col >= 31 && col < 60) ||
                    (col >= 61 && col < 71) || (col >= 72 && col < 81) ||
                    (col >= 82 && col < 86) || (col >= 87 && col < 96);
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

            void emit_table_vertex(
                float2 local,
                float2 uv,
                int layerRow,
                int selectedSlot,
                uint count,
                uint first,
                inout TriangleStream<v2f> stream
            ) {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(float4(local, 0.0, 1.0));
                o.uv = uv;
                o.layerRow = layerRow;
                o.selectedSlot = selectedSlot;
                o.displayCount = count;
                o.displayStart = first;
                stream.Append(o);
            }

            void emit_table_band(
                uint firstRow,
                uint rowCount,
                int layerRow,
                int selectedSlot,
                uint count,
                uint first,
                inout TriangleStream<v2f> stream
            ) {
                if (rowCount == 0u) return;
                float topUv = 1.0 - (float)firstRow / (float)PANEL_ROWS;
                float bottomUv = 1.0 - (float)(firstRow + rowCount) / (float)PANEL_ROWS;
                float extendedBottomUv = topUv - 2.0 * (topUv - bottomUv);

                emit_table_vertex(float2( 0.5, topUv - 0.5), float2(0, topUv), layerRow, selectedSlot, count, first, stream);
                emit_table_vertex(float2(-1.5, topUv - 0.5), float2(2, topUv), layerRow, selectedSlot, count, first, stream);
                emit_table_vertex(float2( 0.5, extendedBottomUv - 0.5), float2(0, extendedBottomUv), layerRow, selectedSlot, count, first, stream);
                stream.RestartStrip();
            }

            [maxvertexcount(90)]
            void geom(triangle v2g input[3], uint primitiveId : SV_PrimitiveID, inout TriangleStream<v2f> stream) {
                UNITY_SETUP_INSTANCE_ID(input[0]);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input[0]);
                if (primitiveId != 0u) return;

                SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                float3 panelWorld = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                uint limit = scan_result_limit();
                uint rows = visible_row_count();
                SpsDebugDirectRecord records[SPS_DEBUG_DIRECT_MAX_RESULTS];
                uint count = sps_debug_direct_collect(tex, SPS_DEBUG_PRODUCT_ANY, panelWorld, limit, records);
                uint first = display_start_index(count, rows);

                emit_table_band(0u, TABLE_FIRST_ROW, -1, -1, count, first, stream);

                [loop]
                for (uint visibleIndex = 0u; visibleIndex < 28u; visibleIndex++) {
                    if (visibleIndex >= rows) break;
                    int slot = -1;
                    uint recordIndex = first + visibleIndex;
                    if (recordIndex < count) slot = (int)records[recordIndex].slot;
                    emit_table_band(
                        TABLE_FIRST_ROW + visibleIndex,
                        1u,
                        (int)(TABLE_FIRST_ROW + visibleIndex),
                        slot,
                        count,
                        first,
                        stream
                    );
                }

                uint bottomFirstRow = TABLE_FIRST_ROW + rows;
                if (bottomFirstRow < PANEL_ROWS) {
                    emit_table_band(bottomFirstRow, PANEL_ROWS - bottomFirstRow, -2, -1, count, first, stream);
                }
            }

            float4 draw_panel(SpsTexture tex, float2 panelUv, v2f input) {
                if (_SPS_DebugOpacity <= 0.001) return float4(0, 0, 0, 0);

                float2 grid = float2(panelUv.x * PANEL_COLS, (1.0 - panelUv.y) * PANEL_ROWS);
                int col = (int)floor(grid.x);
                int row = (int)floor(grid.y);
                uint rows = visible_row_count();
                if (panelUv.x < 0.0 || panelUv.x > 1.0 || panelUv.y < 0.0 || panelUv.y > 1.0) clip(-1);
                if (input.layerRow >= 0 && row != input.layerRow) clip(-1);
                if (input.layerRow == -1 && row >= TABLE_FIRST_ROW) clip(-1);
                if (input.layerRow == -2 && row < TABLE_FIRST_ROW + (int)rows) clip(-1);
                if (!possible_text_cell(row, col)) {
                    float4 bg = _SPS_DebugBackColor;
                    bg.a *= _SPS_DebugOpacity;
                    return bg;
                }
                int ascii = table_char(
                    tex,
                    row,
                    col,
                    input.selectedSlot,
                    input.displayCount,
                    input.displayStart,
                    display_last_index(input.displayCount, input.displayStart, rows),
                    rows
                );
                float a = font_alpha(ascii, frac(grid));
                float4 color = lerp(_SPS_DebugBackColor, _SPS_DebugTextColor, a);
                color.a *= _SPS_DebugOpacity;
                return color;
            }

            float4 frag(v2f i, fixed facing : VFACE) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float2 panelUv = i.uv;
                if (facing < 0.0) panelUv.x = 1.0 - panelUv.x;
                SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                return draw_panel(tex, panelUv, i);
            }
            ENDCG
        }
    }

    Fallback Off
}
