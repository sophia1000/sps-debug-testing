Shader "Hidden/VRCFury/SpsDebugLines" {
    Properties {
        _SPS_DebugCacheRecords("Distance Scan Cap", Range(8, 256)) = 128
        _SPS_DebugMaxLines("Max Lines", Range(1, 28)) = 16
        _SPS_LineWorldWidth("Line Width (world units)", Float) = 0.02
        _SPS_LineOpacity("Line Opacity", Range(0, 1)) = 0.8
        _SPS_LineColor("Line Color", Color) = (1, 0.35, 0.15, 1)
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 7
        [Enum(Off,0, On,1)] _ZWrite("ZWrite", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 0
        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOp("Blend Op", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 10
    }

    SubShader {
        Tags {
            "Queue" = "Overlay+5100"
            "RenderType" = "Overlay"
            "IgnoreProjector" = "True"
            "VRCFallback" = "Hidden"
        }

        ZTest [_ZTest]
        ZWrite [_ZWrite]
        Cull [_Cull]
        BlendOp [_BlendOp]
        Blend [_SrcBlend] [_DstBlend]

        Pass {
            CGPROGRAM
            #pragma target 4.0
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma multi_compile _ UNITY_SINGLE_PASS_STEREO
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"
            #include "SpsDebugDirectScan.cginc"

            #define SPS_DEBUG_LINES_MAX 28
            float _SPS_DebugCacheRecords;
            float _SPS_DebugMaxLines;
            float _SPS_LineWorldWidth;
            float _SPS_LineOpacity;
            float4 _SPS_LineColor;

            SPS_INIT_TEX(_VFGridFinal)

            struct appdata {
                float4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2g {
                float4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            struct g2f {
                float4 pos : SV_POSITION;
                fixed4 col : COLOR0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2g vert(appdata v) {
                UNITY_SETUP_INSTANCE_ID(v);
                v2g o;
                UNITY_INITIALIZE_OUTPUT(v2g, o);
                o.vertex = v.vertex;
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                return o;
            }

            float3 GetCenterEyePos() {
            #if defined(UNITY_SINGLE_PASS_STEREO)
                return 0.5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]);
            #else
                return _WorldSpaceCameraPos.xyz;
            #endif
            }

            void GetCenterEyeBasis(float3 anchorWS, out float3 camPos, out float3 camRight, out float3 camUp) {
                camPos = GetCenterEyePos();
                float3 worldUp = float3(0, 1, 0);
                float3 viewDir = normalize(camPos - anchorWS);
                camRight = normalize(cross(worldUp, viewDir));
                camUp = worldUp;
                if (abs(camRight.x) + abs(camRight.y) + abs(camRight.z) < 0.0001) {
                    camRight = normalize(UNITY_MATRIX_I_V[0].xyz);
                }
            }

            fixed4 MakeLineColor(float3 rgb) {
                return fixed4(saturate(rgb), saturate(_SPS_LineOpacity));
            }

            void EmitWorldLine(float3 aWS, float3 bWS, float3 rgb, inout TriangleStream<g2f> ts) {
                float3 mid = 0.5 * (aWS + bWS);
                float3 camPos = GetCenterEyePos();

                float3 n = cross(mid - camPos, aWS - bWS);
                float nLen = max(length(n), 0.000001);
                float3 off = (n / nLen) * (max(_SPS_LineWorldWidth, 0.0001) * 0.5);

                float3 aL = aWS - off;
                float3 aR = aWS + off;
                float3 bL = bWS - off;
                float3 bR = bWS + off;

                g2f o;
                UNITY_INITIALIZE_OUTPUT(g2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.col = MakeLineColor(rgb);

                o.pos = UnityWorldToClipPos(aL); ts.Append(o);
                o.pos = UnityWorldToClipPos(aR); ts.Append(o);
                o.pos = UnityWorldToClipPos(bL); ts.Append(o);
                o.pos = UnityWorldToClipPos(bR); ts.Append(o);
                ts.RestartStrip();
            }

            void EmitDirectLines(inout TriangleStream<g2f> ts) {
                float3 rootWS = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                int maxLines = clamp((int)round(_SPS_DebugMaxLines), 1, SPS_DEBUG_LINES_MAX);
                maxLines = min(maxLines, (int)round(max(_SPS_DebugCacheRecords, 1.0)));
                SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                SpsDebugDirectCursor cursor;
                sps_debug_direct_reset(cursor);

                [loop]
                for (int resultIndex = 0; resultIndex < SPS_DEBUG_LINES_MAX; resultIndex++) {
                    if (resultIndex >= maxLines) break;
                    uint slot, product, distanceKey;
                    float3 targetWS;
                    if (!sps_debug_direct_next(tex, SPS_DEBUG_PRODUCT_ANY, rootWS, cursor, slot, product, targetWS, distanceKey)) break;
                    sps_debug_direct_advance(cursor, distanceKey, product);
                    if (dot(targetWS - rootWS, targetWS - rootWS) >= 0.000001) {
                        EmitWorldLine(rootWS, targetWS, _SPS_LineColor.rgb, ts);
                    }
                }
            }

            [maxvertexcount(112)]
            void geom(triangle v2g IN[3], uint primitiveId : SV_PrimitiveID, inout TriangleStream<g2f> ts) {
                UNITY_SETUP_INSTANCE_ID(IN[0]);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN[0]);
                if (primitiveId != 0u) return;
                if (_SPS_LineOpacity <= 0.001) return;

                EmitDirectLines(ts);
            }

            fixed4 frag(g2f i) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                return i.col;
            }
            ENDCG
        }
    }

    Fallback Off
}
