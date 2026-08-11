Shader "Hidden/VRCFury/SpsDebugTargetPlanes" {
    Properties {
        _SPS_DebugCacheRecords("Distance Scan Cap", Range(8, 256)) = 128
        _SPS_DebugMaxPlanes("Max Planes", Range(1, 24)) = 16
        _SPS_MarkerTexture("Marker Texture", 2D) = "white" {}
        _SPS_MarkerSize("Plane Size (meters)", Float) = 0.25
        _SPS_MarkerOffset("Up Offset (meters)", Float) = 0.25
        _SPS_MarkerOpacity("Opacity", Range(0, 1)) = 1
        _SPS_MarkerTint("Tint", Color) = (1, 1, 1, 1)
        _SPS_MarkerCutoff("Alpha Cutoff", Range(0, 1)) = 0.5
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 8
        [Enum(Off,0, On,1)] _ZWrite("ZWrite", Float) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 0
        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOp("Blend Op", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0
    }

    SubShader {
        Tags {
            "Queue" = "AlphaTest"
            "RenderType" = "TransparentCutout"
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

            #define SPS_DEBUG_PLANES_MAX 24
            float _SPS_DebugCacheRecords;
            float _SPS_DebugMaxPlanes;
            sampler2D _SPS_MarkerTexture;
            float4 _SPS_MarkerTexture_ST;
            float _SPS_MarkerSize;
            float _SPS_MarkerOffset;
            float _SPS_MarkerOpacity;
            float4 _SPS_MarkerTint;
            float _SPS_MarkerCutoff;
            float _VRChatMirrorMode;

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
                float2 uv : TEXCOORD0;
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

            void EmitMarkerQuad(float3 targetWS, inout TriangleStream<g2f> ts) {
                float3 anchorWS = targetWS + float3(0, _SPS_MarkerOffset, 0);
                float3 camPos, camRight, camUp;
                GetCenterEyeBasis(anchorWS, camPos, camRight, camUp);

                float halfSize = max(_SPS_MarkerSize, 0.001) * 0.5;
                float3 tlWS = anchorWS + (-halfSize) * camRight + ( halfSize) * camUp;
                float3 blWS = anchorWS + (-halfSize) * camRight + (-halfSize) * camUp;
                float3 trWS = anchorWS + ( halfSize) * camRight + ( halfSize) * camUp;
                float3 brWS = anchorWS + ( halfSize) * camRight + (-halfSize) * camUp;

                g2f o;
                UNITY_INITIALIZE_OUTPUT(g2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.col = fixed4(_SPS_MarkerTint.rgb, saturate(_SPS_MarkerTint.a * _SPS_MarkerOpacity));

                o.uv = float2(1, 1);
                o.pos = UnityWorldToClipPos(tlWS);
                ts.Append(o);

                o.uv = float2(1, 0);
                o.pos = UnityWorldToClipPos(blWS);
                ts.Append(o);

                o.uv = float2(0, 1);
                o.pos = UnityWorldToClipPos(trWS);
                ts.Append(o);

                o.uv = float2(0, 0);
                o.pos = UnityWorldToClipPos(brWS);
                ts.Append(o);

                ts.RestartStrip();
            }

            void EmitDirectMarkers(inout TriangleStream<g2f> ts) {
                if (_SPS_MarkerOpacity <= 0.001 || _SPS_MarkerTint.a <= 0.001) return;

                int maxPlanes = clamp((int)round(_SPS_DebugMaxPlanes), 1, SPS_DEBUG_PLANES_MAX);
                maxPlanes = min(maxPlanes, (int)round(max(_SPS_DebugCacheRecords, 1.0)));
                float3 originWS = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                SpsDebugDirectCursor cursor;
                sps_debug_direct_reset(cursor);

                [loop]
                for (int resultIndex = 0; resultIndex < SPS_DEBUG_PLANES_MAX; resultIndex++) {
                    if (resultIndex >= maxPlanes) break;
                    uint slot, product, distanceKey;
                    float3 targetWS;
                    if (!sps_debug_direct_next(tex, SPS_DEBUG_PRODUCT_ANY, originWS, cursor, slot, product, targetWS, distanceKey)) break;
                    sps_debug_direct_advance(cursor, distanceKey, product);
                    EmitMarkerQuad(targetWS, ts);
                }
            }

            [maxvertexcount(96)]
            void geom(triangle v2g IN[3], uint primitiveId : SV_PrimitiveID, inout TriangleStream<g2f> ts) {
                UNITY_SETUP_INSTANCE_ID(IN[0]);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN[0]);
                if (primitiveId != 0u) return;
                if (_SPS_MarkerOpacity <= 0.001 || _SPS_MarkerTint.a <= 0.001) return;

                EmitDirectMarkers(ts);
            }

            fixed4 frag(g2f i) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float2 uv = i.uv;
                if (_VRChatMirrorMode > 0.5) uv.x = 1.0 - uv.x;
                uv = TRANSFORM_TEX(uv, _SPS_MarkerTexture);
                fixed4 texCol = tex2D(_SPS_MarkerTexture, uv);
                fixed4 color = texCol * i.col;
                clip(color.a - _SPS_MarkerCutoff);
                color.a = 1.0;
                return color;
            }
            ENDCG
        }
    }

    Fallback Off
}
