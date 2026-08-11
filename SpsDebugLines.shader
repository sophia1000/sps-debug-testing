Shader "Hidden/VRCFury/SpsDebugLines" {
    Properties {
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
            #define SPS_DEBUG_DIRECT_MAX_RESULTS 28
            #include "SpsDebugDirectScan.cginc"

            #define SPS_DEBUG_LINES_MAX SPS_DEBUG_DIRECT_MAX_RESULTS
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

            void AppendLineVertex(v2g stereoInput, float3 worldPos, inout TriangleStream<g2f> ts) {
                g2f o = (g2f)0;
                o.pos = UnityWorldToClipPos(worldPos);
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(stereoInput, o);
                ts.Append(o);
            }

            void EmitWorldLine(v2g stereoInput, float3 aWS, float3 bWS, inout TriangleStream<g2f> ts) {
                float3 mid = 0.5 * (aWS + bWS);
                float3 camPos = GetCenterEyePos();

                float3 n = cross(mid - camPos, aWS - bWS);
                float nLen = max(length(n), 0.000001);
                float3 off = (n / nLen) * (max(_SPS_LineWorldWidth, 0.0001) * 0.5);

                float3 aL = aWS - off;
                float3 aR = aWS + off;
                float3 bL = bWS - off;
                float3 bR = bWS + off;

                AppendLineVertex(stereoInput, aL, ts);
                AppendLineVertex(stereoInput, aR, ts);
                AppendLineVertex(stereoInput, bL, ts);
                AppendLineVertex(stereoInput, bR, ts);
                ts.RestartStrip();
            }

            void EmitDirectLines(v2g stereoInput, inout TriangleStream<g2f> ts) {
                float3 rootWS = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                int maxLines = clamp((int)round(_SPS_DebugMaxLines), 1, SPS_DEBUG_LINES_MAX);
                SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                SpsDebugDirectRecord records[SPS_DEBUG_DIRECT_MAX_RESULTS] = {
                    SPS_DEBUG_DIRECT_ZERO_16,
                    SPS_DEBUG_DIRECT_ZERO_8,
                    SPS_DEBUG_DIRECT_ZERO_4
                };
                uint count = sps_debug_direct_collect(tex, SPS_DEBUG_PRODUCT_ANY, rootWS, (uint)maxLines, records);

                [unroll]
                for (int resultIndex = 0; resultIndex < SPS_DEBUG_LINES_MAX; resultIndex++) {
                    if ((uint)resultIndex >= count) break;
                    float3 targetWS = records[resultIndex].world;
                    if (dot(targetWS - rootWS, targetWS - rootWS) >= 0.000001) {
                        EmitWorldLine(stereoInput, rootWS, targetWS, ts);
                    }
                }
            }

            [maxvertexcount(112)]
            void geom(triangle v2g IN[3], uint primitiveId : SV_PrimitiveID, inout TriangleStream<g2f> ts) {
                UNITY_SETUP_INSTANCE_ID(IN[0]);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN[0]);
                if (primitiveId != 0u) return;
                if (_SPS_LineOpacity <= 0.001) return;

                EmitDirectLines(IN[0], ts);
            }

            fixed4 frag(g2f i) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                return fixed4(saturate(_SPS_LineColor.rgb), saturate(_SPS_LineOpacity));
            }
            ENDCG
        }
    }

    Fallback Off
}
