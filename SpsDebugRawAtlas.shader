Shader "Hidden/VRCFury/SpsDebugRawAtlas" {
    Properties {
        [Enum(Final _VFGridFinal,0,Raw _VFGrid56,1)] _SPS_DebugSource("Source", Float) = 0
        _SPS_DebugOpacity("Opacity", Range(0, 1)) = 1
        [Toggle] _SPS_DebugFlipX("Flip X", Float) = 0
        [Toggle] _SPS_DebugFlipY("Flip Y", Float) = 1
        [Toggle] _SPS_DebugLeftEyeOnly("Left Eye Only", Float) = 1
        [Enum(None,0,Clockwise 90,1,180,2,Counterclockwise 90,3)] _SPS_DebugRotation("Rotation", Float) = 0
        [Toggle] _SPS_DebugSolidBack("Solid Background", Float) = 0
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
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ UNITY_SINGLE_PASS_STEREO
            #include "UnityCG.cginc"
            #include "Packages/com.vrcfury.vrcfury/SPS/common/sps_cell_layout.cginc"

            float _SPS_DebugSource;
            float _SPS_DebugOpacity;
            float _SPS_DebugFlipX;
            float _SPS_DebugFlipY;
            float _SPS_DebugLeftEyeOnly;
            float _SPS_DebugRotation;
            float _SPS_DebugSolidBack;
            float4 _SPS_DebugBackColor;

            SPS_INIT_TEX(_VFGridFinal)
            SPS_INIT_TEX(_VFGrid56)

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 raw_atlas_color(SpsTexture tex, float2 uv) {
                // Unity supplies dimensions in texelSize.zw; avoid two per-pixel divides.
                uint width = max(1u, (uint)round(abs(tex.texelSize.z)));
                uint height = max(1u, (uint)round(abs(tex.texelSize.w)));
                uint2 pixel = uint2(saturate(uv) * float2((float)(width - 1u), (float)(height - 1u)));
                return SPS_READ_TEX(tex, pixel);
            }

            float2 transform_atlas_uv(float2 uv) {
                if (_SPS_DebugFlipX > 0.5) uv.x = 1.0 - uv.x;
                if (_SPS_DebugFlipY > 0.5) uv.y = 1.0 - uv.y;

                int rot = (int)round(_SPS_DebugRotation);
                if (rot == 1) return float2(uv.y, 1.0 - uv.x);
                if (rot == 2) return 1.0 - uv;
                if (rot == 3) return float2(1.0 - uv.y, uv.x);
                return uv;
            }

            float4 draw_raw(SpsTexture tex, float2 uv) {
                if (_SPS_DebugOpacity <= 0.001) return float4(0, 0, 0, 0);

                float2 atlasUv = transform_atlas_uv(uv);
            #if defined(UNITY_SINGLE_PASS_STEREO)
                if (_SPS_DebugLeftEyeOnly > 0.5) atlasUv.x *= 0.5;
            #endif
                float4 color = raw_atlas_color(tex, atlasUv);
                if (_SPS_DebugSolidBack > 0.5) {
                    float ink = saturate(max(max(color.r, color.g), max(color.b, color.a)) * 16.0);
                    color.rgb = lerp(_SPS_DebugBackColor.rgb, color.rgb, ink);
                }
                color.a = _SPS_DebugOpacity;
                return color;
            }

            float4 frag(v2f i) : SV_Target {
                if (_SPS_DebugSource > 0.5) {
                    SpsTexture tex = SPS_GET_TEX(_VFGrid56);
                    return draw_raw(tex, i.uv);
                } else {
                    SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                    return draw_raw(tex, i.uv);
                }
            }
            ENDCG
        }
    }

    Fallback Off
}
