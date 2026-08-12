Shader "Hidden/VRCFury/SpsDebugTargetPlanes" {
    Properties {
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
            #define SPS_DEBUG_DIRECT_MAX_RESULTS 24
            #include "SpsDebugDirectScan.cginc"

            #define SPS_DEBUG_PLANES_MAX SPS_DEBUG_DIRECT_MAX_RESULTS
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

            void GetCenterEyeBasis(float3 anchorWS, float3 camPos, out float3 camRight, out float3 camUp) {
                float3 worldUp = float3(0, 1, 0);
                float3 viewDir = normalize(camPos - anchorWS);
                camRight = cross(worldUp, viewDir);
                float rightLength = length(camRight);
                camRight = rightLength > 0.0001 ? camRight / rightLength : normalize(UNITY_MATRIX_I_V[0].xyz);
                camUp = worldUp;
            }

            bool QuadOutsideView(float4 tl, float4 bl, float4 tr, float4 br) {
                float4 w = float4(tl.w, bl.w, tr.w, br.w);
                if (all(w <= 0.00001)) return true;
                if (any(w <= 0.00001)) return false;
                float4 x = float4(tl.x, bl.x, tr.x, br.x);
                float4 y = float4(tl.y, bl.y, tr.y, br.y);
                return all(x < -w) || all(x > w) || all(y < -w) || all(y > w);
            }

            void AppendMarkerVertex(
                v2g stereoInput,
                float4 clipPos,
                float2 uv,
                inout TriangleStream<g2f> ts
            ) {
                g2f o = (g2f)0;
                o.pos = clipPos;
                if (_VRChatMirrorMode > 0.5) uv.x = 1.0 - uv.x;
                o.uv = TRANSFORM_TEX(uv, _SPS_MarkerTexture);
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(stereoInput, o);
                ts.Append(o);
            }

            void EmitMarkerQuad(
                v2g stereoInput,
                float3 camPos,
                float halfSize,
                float3 targetWS,
                inout TriangleStream<g2f> ts
            ) {
                float3 anchorWS = targetWS + float3(0, _SPS_MarkerOffset, 0);
                float3 camRight = float3(1, 0, 0);
                float3 camUp = float3(0, 1, 0);
                GetCenterEyeBasis(anchorWS, camPos, camRight, camUp);

                float3 tlWS = anchorWS + (-halfSize) * camRight + ( halfSize) * camUp;
                float3 blWS = anchorWS + (-halfSize) * camRight + (-halfSize) * camUp;
                float3 trWS = anchorWS + ( halfSize) * camRight + ( halfSize) * camUp;
                float3 brWS = anchorWS + ( halfSize) * camRight + (-halfSize) * camUp;

                float4 tlClip = UnityWorldToClipPos(tlWS);
                float4 blClip = UnityWorldToClipPos(blWS);
                float4 trClip = UnityWorldToClipPos(trWS);
                float4 brClip = UnityWorldToClipPos(brWS);
                if (QuadOutsideView(tlClip, blClip, trClip, brClip)) return;

                AppendMarkerVertex(stereoInput, tlClip, float2(1, 1), ts);
                AppendMarkerVertex(stereoInput, blClip, float2(1, 0), ts);
                AppendMarkerVertex(stereoInput, trClip, float2(0, 1), ts);
                AppendMarkerVertex(stereoInput, brClip, float2(0, 0), ts);

                ts.RestartStrip();
            }

            void EmitDirectMarkers(v2g stereoInput, inout TriangleStream<g2f> ts) {
                int maxPlanes = clamp((int)round(_SPS_DebugMaxPlanes), 1, SPS_DEBUG_PLANES_MAX);
                float3 originWS = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                SpsDebugDirectRecord records[SPS_DEBUG_DIRECT_MAX_RESULTS] = {
                    SPS_DEBUG_DIRECT_ZERO_16,
                    SPS_DEBUG_DIRECT_ZERO_8
                };
                uint count = sps_debug_direct_collect(tex, SPS_DEBUG_PRODUCT_ANY, originWS, (uint)maxPlanes, records);
                float3 camPos = GetCenterEyePos();
                float halfSize = max(_SPS_MarkerSize, 0.001) * 0.5;

                [unroll]
                for (int resultIndex = 0; resultIndex < SPS_DEBUG_PLANES_MAX; resultIndex++) {
                    if ((uint)resultIndex >= count) break;
                    EmitMarkerQuad(stereoInput, camPos, halfSize, records[resultIndex].world, ts);
                }
            }

            [maxvertexcount(96)]
            void geom(triangle v2g IN[3], uint primitiveId : SV_PrimitiveID, inout TriangleStream<g2f> ts) {
                UNITY_SETUP_INSTANCE_ID(IN[0]);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN[0]);
                if (primitiveId != 0u) return;
                if (_SPS_MarkerOpacity <= 0.001 || _SPS_MarkerTint.a <= 0.001) return;
                if (_SPS_MarkerTint.a * _SPS_MarkerOpacity < _SPS_MarkerCutoff) return;

                EmitDirectMarkers(IN[0], ts);
            }

            fixed4 frag(g2f i) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                fixed4 texCol = tex2D(_SPS_MarkerTexture, i.uv);
                fixed4 color = texCol * fixed4(
                    _SPS_MarkerTint.rgb,
                    saturate(_SPS_MarkerTint.a * _SPS_MarkerOpacity)
                );
                clip(color.a - _SPS_MarkerCutoff);
                color.a = 1.0;
                return color;
            }
            ENDCG
        }
    }

    Fallback Off
}
