Shader "Hidden/VRCFury/SpsDebugCensorTargets" {
    Properties {
        _SPS_DebugMaxCensors("Max Censor Targets", Range(1, 20)) = 16

        [KeywordEnum(Solid, Pixelate, BoxBlur, GaussianBlur)] _SPS_CensorMode("Effect", Float) = 0
        [Enum(Rectangle,0, Rounded Rectangle,1, Ellipse,2)] _SPS_CensorShape("Shape", Float) = 1
        _SPS_CensorWidth("Width (meters)", Float) = 0.35
        _SPS_CensorHeight("Height (meters)", Float) = 0.12
        _SPS_CensorOffset("Offset Right / Up / Toward Camera", Vector) = (0, 0, 0.02, 0)
        _SPS_CensorRotation("Screen Rotation (degrees)", Range(-180, 180)) = 0
        _SPS_CensorCornerRadius("Rounded Corner Size", Range(0, 1)) = 0.35
        _SPS_CensorEdgeFeather("Edge Feather", Range(0, 0.25)) = 0.01
        _SPS_CensorSolidColor("Solid Color", Color) = (0, 0, 0, 1)
        _SPS_CensorEffectTint("Blur / Pixel Tint", Color) = (1, 1, 1, 1)
        _SPS_CensorOpacity("Opacity", Range(0, 1)) = 1
        _SPS_CensorPixelSize("Pixel Block Size", Range(1, 64)) = 18
        _SPS_CensorBlurRadius("Blur Radius (pixels)", Range(0.5, 24)) = 5
        [IntRange] _SPS_CensorBoxSamples("Box Samples Per Axis", Range(1, 8)) = 3
        _SPS_CensorBoxRadiusScale("Box Radius Multiplier", Range(0.1, 2)) = 1
        [IntRange] _SPS_CensorGaussianSamples("Gaussian Samples Per Axis", Range(1, 8)) = 3
        _SPS_CensorGaussianRadiusScale("Gaussian Radius Multiplier", Range(0.1, 2)) = 1
        _SPS_CensorGaussianSigma("Gaussian Sigma", Range(0.1, 2)) = 0.8493218

        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 0
    }

    SubShader {
        Tags {
            "Queue" = "Transparent+1000"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
            "VRCFallback" = "Hidden"
        }

        // Named GrabPasses are captured once and shared. This reuses Poiyomi's
        // capture when it already exists, or creates _PoiGrab2 when it does not.
        GrabPass { "_PoiGrab2" }

        Pass {
            ZTest [_ZTest]
            ZWrite Off
            Cull [_Cull]
            Blend SrcAlpha OneMinusSrcAlpha
            ColorMask RGBA

            CGPROGRAM
            #pragma target 4.0
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma multi_compile _ UNITY_SINGLE_PASS_STEREO
            #pragma multi_compile_instancing
            #pragma shader_feature_local _SPS_CENSORMODE_SOLID _SPS_CENSORMODE_PIXELATE _SPS_CENSORMODE_BOXBLUR _SPS_CENSORMODE_GAUSSIANBLUR

            #include "UnityCG.cginc"
            #define SPS_DEBUG_DIRECT_MAX_RESULTS 20
            #include "SpsDebugDirectScan.cginc"

            #define SPS_DEBUG_CENSOR_MAX SPS_DEBUG_DIRECT_MAX_RESULTS
            #define SPS_DEBUG_BLUR_SAMPLES_MAX 8

            float _SPS_DebugMaxCensors;
            float _SPS_CensorShape;
            float _SPS_CensorWidth;
            float _SPS_CensorHeight;
            float4 _SPS_CensorOffset;
            float _SPS_CensorRotation;
            float _SPS_CensorCornerRadius;
            float _SPS_CensorEdgeFeather;
            float4 _SPS_CensorSolidColor;
            float4 _SPS_CensorEffectTint;
            float _SPS_CensorOpacity;
            float _SPS_CensorPixelSize;
            float _SPS_CensorBlurRadius;
            float _SPS_CensorBoxSamples;
            float _SPS_CensorBoxRadiusScale;
            float _SPS_CensorGaussianSamples;
            float _SPS_CensorGaussianRadiusScale;
            float _SPS_CensorGaussianSigma;

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_PoiGrab2);
            float4 _PoiGrab2_TexelSize;
            SPS_INIT_TEX(_VFGridFinal)

            struct appdata {
                float4 vertex : POSITION;
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2g {
                float4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            struct g2f {
                float4 pos : SV_POSITION;
                float4 grabPos : TEXCOORD0;
                float2 localUV : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2g vert(appdata v) {
                v2g o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2g, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = v.vertex;
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                return o;
            }

            float3 GetCenterEyePos() {
            #if defined(UNITY_SINGLE_PASS_STEREO)
                return 0.5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]);
            #else
                return _WorldSpaceCameraPos.xyz;
            #endif
            }

            void GetCenterEyeBasis(
                float3 targetWS,
                float3 camPos,
                out float3 camRight,
                out float3 camUp,
                out float3 towardCamera
            ) {
                towardCamera = normalize(camPos - targetWS);
                camRight = cross(float3(0, 1, 0), towardCamera);
                float rightLength = length(camRight);
                camRight = rightLength > 0.0001 ? camRight / rightLength : normalize(UNITY_MATRIX_I_V[0].xyz);
                camUp = normalize(cross(towardCamera, camRight));
            }

            bool QuadOutsideView(float4 tl, float4 bl, float4 tr, float4 br) {
                float4 w = float4(tl.w, bl.w, tr.w, br.w);
                if (all(w <= 0.00001)) return true;
                if (any(w <= 0.00001)) return false;
                float4 x = float4(tl.x, bl.x, tr.x, br.x);
                float4 y = float4(tl.y, bl.y, tr.y, br.y);
                return all(x < -w) || all(x > w) || all(y < -w) || all(y > w);
            }

            void AppendCensorVertex(
                v2g stereoInput,
                float4 clipPos,
                float2 localUV,
                inout TriangleStream<g2f> stream
            ) {
                g2f o = (g2f)0;
                o.localUV = localUV;
                o.pos = clipPos;
                o.grabPos = ComputeGrabScreenPos(o.pos);
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(stereoInput, o);
                stream.Append(o);
            }

            void EmitCensorQuad(
                v2g stereoInput,
                float3 camPos,
                float sineValue,
                float cosineValue,
                float halfWidth,
                float halfHeight,
                float3 targetWS,
                inout TriangleStream<g2f> stream
            ) {
                float3 camRight = float3(1, 0, 0);
                float3 camUp = float3(0, 1, 0);
                float3 towardCamera = float3(0, 0, 1);
                GetCenterEyeBasis(targetWS, camPos, camRight, camUp, towardCamera);

                float3 rotatedRight = camRight * cosineValue + camUp * sineValue;
                float3 rotatedUp = camUp * cosineValue - camRight * sineValue;

                float3 anchorWS = targetWS
                    + rotatedRight * _SPS_CensorOffset.x
                    + rotatedUp * _SPS_CensorOffset.y
                    + towardCamera * _SPS_CensorOffset.z;

                float3 tlWS = anchorWS - rotatedRight * halfWidth + rotatedUp * halfHeight;
                float3 blWS = anchorWS - rotatedRight * halfWidth - rotatedUp * halfHeight;
                float3 trWS = anchorWS + rotatedRight * halfWidth + rotatedUp * halfHeight;
                float3 brWS = anchorWS + rotatedRight * halfWidth - rotatedUp * halfHeight;

                float4 tlClip = UnityWorldToClipPos(tlWS);
                float4 blClip = UnityWorldToClipPos(blWS);
                float4 trClip = UnityWorldToClipPos(trWS);
                float4 brClip = UnityWorldToClipPos(brWS);
                if (QuadOutsideView(tlClip, blClip, trClip, brClip)) return;

                AppendCensorVertex(stereoInput, tlClip, float2(0, 1), stream);
                AppendCensorVertex(stereoInput, blClip, float2(0, 0), stream);
                AppendCensorVertex(stereoInput, trClip, float2(1, 1), stream);
                AppendCensorVertex(stereoInput, brClip, float2(1, 0), stream);
                stream.RestartStrip();
            }

            void EmitDirectCensors(v2g stereoInput, inout TriangleStream<g2f> stream) {
                int maxCensors = clamp((int)round(_SPS_DebugMaxCensors), 1, SPS_DEBUG_CENSOR_MAX);
                float3 originWS = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                SpsDebugDirectRecord records[SPS_DEBUG_DIRECT_MAX_RESULTS] = {
                    SPS_DEBUG_DIRECT_ZERO_16,
                    SPS_DEBUG_DIRECT_ZERO_4
                };
                uint count = sps_debug_direct_collect(tex, SPS_DEBUG_PRODUCT_ANY, originWS, (uint)maxCensors, records);
                float3 camPos = GetCenterEyePos();
                float radians = _SPS_CensorRotation * 0.01745329252;
                float sineValue = 0.0;
                float cosineValue = 1.0;
                sincos(radians, sineValue, cosineValue);
                float halfWidth = max(abs(_SPS_CensorWidth), 0.001) * 0.5;
                float halfHeight = max(abs(_SPS_CensorHeight), 0.001) * 0.5;

                [unroll]
                for (int resultIndex = 0; resultIndex < SPS_DEBUG_CENSOR_MAX; resultIndex++) {
                    if ((uint)resultIndex >= count) break;
                    EmitCensorQuad(
                        stereoInput,
                        camPos,
                        sineValue,
                        cosineValue,
                        halfWidth,
                        halfHeight,
                        records[resultIndex].world,
                        stream
                    );
                }
            }

            [maxvertexcount(80)]
            void geom(triangle v2g input[3], uint primitiveId : SV_PrimitiveID, inout TriangleStream<g2f> stream) {
                UNITY_SETUP_INSTANCE_ID(input[0]);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input[0]);
                if (primitiveId != 0u) return;
                if (_SPS_CensorOpacity <= 0.001) return;
            #if defined(_SPS_CENSORMODE_PIXELATE) || defined(_SPS_CENSORMODE_BOXBLUR) || defined(_SPS_CENSORMODE_GAUSSIANBLUR)
                if (_SPS_CensorEffectTint.a <= 0.001) return;
            #else
                if (_SPS_CensorSolidColor.a <= 0.001) return;
            #endif
                EmitDirectCensors(input[0], stream);
            }

            float shape_distance(float2 uv) {
                float2 p = uv * 2.0 - 1.0;
                if (_SPS_CensorShape > 1.5) return length(p) - 1.0;
                if (_SPS_CensorShape < 0.5) return max(abs(p.x), abs(p.y)) - 1.0;

                float2 halfSize = max(float2(abs(_SPS_CensorWidth), abs(_SPS_CensorHeight)) * 0.5, 0.0005);
                float minHalfSize = min(halfSize.x, halfSize.y);
                float radius = saturate(_SPS_CensorCornerRadius) * minHalfSize;
                float2 q = abs(p * halfSize) - (halfSize - radius);
                float worldDistance = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
                return worldDistance / minHalfSize;
            }

            float shape_coverage(float2 uv) {
                float distanceToEdge = shape_distance(uv);
                float antialias = max(fwidth(distanceToEdge), 0.0005);
                return 1.0 - smoothstep(-antialias, antialias + _SPS_CensorEdgeFeather, distanceToEdge);
            }

            float2 scene_uv(float4 grabPos) {
                return grabPos.xy / max(grabPos.w, 0.00001);
            }

            float4 sample_scene(float2 uv) {
                return UNITY_SAMPLE_SCREENSPACE_TEXTURE(_PoiGrab2, saturate(uv));
            }

            float4 sample_box_blur(float2 uv) {
                int sampleCount = clamp((int)round(_SPS_CensorBoxSamples), 1, SPS_DEBUG_BLUR_SAMPLES_MAX);
                float4 result = 0.0;
                if (sampleCount <= 1) {
                    result = sample_scene(uv);
                } else {
                    float2 stepUV = _PoiGrab2_TexelSize.xy
                        * max(_SPS_CensorBlurRadius, 0.5)
                        * max(_SPS_CensorBoxRadiusScale, 0.1);
                    float axisScale = 2.0 / (float)(sampleCount - 1);
                    float4 sum = 0.0;
                    [loop]
                    for (int y = 0; y < SPS_DEBUG_BLUR_SAMPLES_MAX; y++) {
                        if (y >= sampleCount) break;
                        float sampleY = (float)y * axisScale - 1.0;
                        [loop]
                        for (int x = 0; x < SPS_DEBUG_BLUR_SAMPLES_MAX; x++) {
                            if (x >= sampleCount) break;
                            float2 sampleOffset = float2((float)x * axisScale - 1.0, sampleY);
                            sum += sample_scene(uv + sampleOffset * stepUV);
                        }
                    }
                    result = sum / (float)(sampleCount * sampleCount);
                }
                return result;
            }

            float4 sample_gaussian_blur(float2 uv) {
                int sampleCount = clamp((int)round(_SPS_CensorGaussianSamples), 1, SPS_DEBUG_BLUR_SAMPLES_MAX);
                float4 result = 0.0;
                if (sampleCount <= 1) {
                    result = sample_scene(uv);
                } else {
                    float2 stepUV = _PoiGrab2_TexelSize.xy
                        * max(_SPS_CensorBlurRadius, 0.5)
                        * max(_SPS_CensorGaussianRadiusScale, 0.1);
                    float sigma = max(_SPS_CensorGaussianSigma, 0.1);
                    float inverseTwoSigmaSquared = 0.5 / (sigma * sigma);
                    float axisScale = 2.0 / (float)(sampleCount - 1);
                    float4 sum = 0.0;
                    float weightSum = 0.0;
                    [loop]
                    for (int y = 0; y < SPS_DEBUG_BLUR_SAMPLES_MAX; y++) {
                        if (y >= sampleCount) break;
                        float sampleY = (float)y * axisScale - 1.0;
                        [loop]
                        for (int x = 0; x < SPS_DEBUG_BLUR_SAMPLES_MAX; x++) {
                            if (x >= sampleCount) break;
                            float2 sampleOffset = float2((float)x * axisScale - 1.0, sampleY);
                            float weight = exp2(-dot(sampleOffset, sampleOffset) * inverseTwoSigmaSquared * 1.44269504);
                            sum += sample_scene(uv + sampleOffset * stepUV) * weight;
                            weightSum += weight;
                        }
                    }
                    result = sum / max(weightSum, 0.00001);
                }
                return result;
            }

            fixed4 frag(g2f input) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float coverage = shape_coverage(input.localUV);
                clip(coverage - 0.001);

                float4 color;
                float effectAlpha;
            #if defined(_SPS_CENSORMODE_PIXELATE)
                float2 uv = scene_uv(input.grabPos);
                float2 blockUV = _PoiGrab2_TexelSize.xy * max(_SPS_CensorPixelSize, 1.0);
                uv = (floor(uv / blockUV) + 0.5) * blockUV;
                color = sample_scene(uv) * _SPS_CensorEffectTint;
                effectAlpha = _SPS_CensorEffectTint.a;
            #elif defined(_SPS_CENSORMODE_BOXBLUR)
                color = sample_box_blur(scene_uv(input.grabPos)) * _SPS_CensorEffectTint;
                effectAlpha = _SPS_CensorEffectTint.a;
            #elif defined(_SPS_CENSORMODE_GAUSSIANBLUR)
                color = sample_gaussian_blur(scene_uv(input.grabPos)) * _SPS_CensorEffectTint;
                effectAlpha = _SPS_CensorEffectTint.a;
            #else
                color = _SPS_CensorSolidColor;
                effectAlpha = _SPS_CensorSolidColor.a;
            #endif

                color.a = saturate(coverage * _SPS_CensorOpacity * effectAlpha);
                return color;
            }
            ENDCG
        }
    }

    Fallback Off
}
