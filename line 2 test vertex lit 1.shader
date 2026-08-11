// ============================================================================
//  Debug/LightLines_Vertex8_AllLights_VR_Unlit
//  - Directional stats: "I:" label row per directional light (stacked)
//  - Axes numbers: single 3-row slab (4 verts) with per-row tint in fragment
//  - Negative numbers supported (minus glyph at atlas index 16; set _AtlasCols=17)
//  - Precision rule (stable):
//      * Show 0000.0000 when |value| <= 9999
//      * Else shift decimal so total digits (int+frac) <= 8, frac <= 4
//      * Carry-safe rounding prevents flicker at boundaries
//  - _AxesRowOffset to raise/lower axes slab relative to DIR rows
//  - PS-label snapping along the line for far lights
//  - D3D11 GS limit safe: maxvertexcount=72; axes-on caps lights to 7
// ============================================================================

Shader "Debug/LightLines_Vertex8_AllLights_VR_Unlit"
{
    Properties
    {
        _Alpha             ("Line/Label Opacity", Range(0,1)) = 1.0
        _LineWorldWidth    ("Line Width (world units)", Float) = 0.02

        // Point/Spot labels
        _UseLabels         ("Show Labels (0/1)", Float) = 1
        _GlyphsTex         ("Glyph Atlas", 2D) = "white" {}
        _AtlasCols         ("Atlas Columns", Float) = 17    // minus at index 16
        _LabelWorldH       ("Label Height (world units)", Float) = 0.25
        _LabelWorldGap     ("Label Row Gap (world units)", Float) = 0.05
        _LabelWorldOffset  ("PS Label Offset (Right,Up) world units", Vector) = (0.2, 0.2, 0, 0)

        // Snap PS stats along the line when far
        _UseSnapLabelAlongLine ("PS Snap Labels Along Line (0/1)", Float) = 0
        _SnapCutoffDist        ("PS Snap Cutoff Distance (m)", Float) = 3.0
        _SnapAlongDist         ("PS Snap Along Distance (m)", Float) = 2.0

        // Directional-only label controls
        _DirLabelOffsetRU  ("DIR Label Start (Right,Up) world units", Vector) = (0.2, 0.5, 0, 0)
        _DirLabelStepRows  ("DIR Label Step (rows; can be negative)", Float) = 1.0

        // Hide labels in VRChat mirrors
        _HideStatsInVRCMirror ("Hide Stats Only In VRC Mirror (0/1)", Float) = 1

        // Label visibility vs distance
        _MinFade           ("Fade-In Start Distance", Float) = 0.25
        _MaxFade           ("Fade-Out End Distance",  Float) = 15.0
        _FadeSoftness      ("Fade Softness (meters)", Float) = 0.50

        // Range clamp (point/spot)
        _ClampLineToRange  ("Clamp Lines To Light Range (0/1)", Float) = 0

        // Directional debug
        _ShowDirectional   ("Show Directional Debug (0/1)", Float) = 0
        _DirLineLength     ("Directional Line Length (m)", Float) = 0.5

        // World Axes Debug
        _ShowWorldAxes     ("Show World Axes + XYZ Numbers (0/1)", Float) = 0
        _AxisLineLength    ("World Axis Line Length (m)", Float) = 0.5

        // Axes slab extra vertical offset, in rows (can be fractional/negative)
        _AxesRowOffset     ("Axes Extra Offset (rows)", Float) = 0.0

        // Render state
        [Enum(UnityEngine.Rendering.CompareFunction)]
        _ZTest             ("ZTest", Float) = 7
        [Enum(Off,0, On,1)]
        _ZWrite            ("ZWrite", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull              ("Cull", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)]
        _SrcBlend          ("Src Blend", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)]
        _DstBlend          ("Dst Blend", Float) = 10
    }

    SubShader
    {
        Tags { "Queue"="Overlay+1000" "RenderType"="Overlay" }
        ZTest [_ZTest]
        ZWrite [_ZWrite]
        Cull   [_Cull]
        Blend  [_SrcBlend] [_DstBlend]

        CGINCLUDE
        #pragma target 4.0
        #pragma multi_compile _ UNITY_SINGLE_PASS_STEREO
        #pragma fragmentoption ARB_precision_hint_fastest

        #include "UnityCG.cginc"
        #include "Lighting.cginc"

        // --- Material params ---
        float   _Alpha, _UseLabels;
        float   _LineWorldWidth;
        float   _LabelWorldH, _LabelWorldGap;
        float4  _LabelWorldOffset;   // point/spot
        float4  _DirLabelOffsetRU;   // directional (Right,Up)
        float   _DirLabelStepRows;   // directional step (can be negative)
        float   _MinFade, _MaxFade, _FadeSoftness;
        float   _ClampLineToRange;
        float   _ShowDirectional, _DirLineLength;
        float   _HideStatsInVRCMirror;

        // PS snap controls
        float   _UseSnapLabelAlongLine, _SnapCutoffDist, _SnapAlongDist;

        // World axes
        float   _ShowWorldAxes, _AxisLineLength;
        float   _AxesRowOffset;

        // Atlas config
        sampler2D _GlyphsTex;
        float4    _GlyphsTex_TexelSize;
        float     _AtlasCols;

        // VRChat shader globals
        float _VRChatMirrorMode; // 0=not mirror, 1=VR mirror, 2=desktop mirror

        // --- Glyph layout ---
        static const int   GLYPH_DIGIT0 = 0;
        static const int   GLYPH_DOT    = 10;
        static const int   GLYPH_COLON  = 11;
        static const int   GLYPH_D      = 12;
        static const int   GLYPH_R      = 13;
        static const int   GLYPH_I      = 14;
        static const int   GLYPH_SPACE  = 15;
        static const int   GLYPH_MINUS  = 16;   // (-) at col 16; set _AtlasCols=17
        static const int   LABEL_LEN    = 11;   // visible slots per row
        static const float CHAR_ASPECT  = 0.6;

        // --- Streams ---
        struct appdata { float3 vertex : POSITION; };
        struct v2g     { float4 pos    : POSITION; };

        // Lines: uv.x < 0 marks line.
        // Labels: uv=(0..1,0..1) across 3-row slab.
        // labelMode: 0 = PS/DIR: leading letter + colon, then number
        //            1 = number-only (single row)
        //            2 = number-only (3-row AXES slab), per-row tint in frag
        struct g2f {
            float4 pos : SV_POSITION;
            fixed4 col : COLOR0;
            float2 uv  : TEXCOORD0;
            float3 vals: TEXCOORD1;     // row values (D/R/I or X/Y/Z)
            float  labelMode : TEXCOORD2;
        };

        v2g vert(appdata v){ v2g o; o.pos=float4(0,0,0,1); return o; }

        fixed4 MakeLineColor(float3 rgb){ return fixed4(saturate(rgb), _Alpha); }
        float  Luminance(float3 rgb){ return max(0.0, dot(rgb, float3(0.299,0.587,0.114))); }

        // Center-eye helpers
        float3 GetCenterEyePos()
        {
        #if defined(UNITY_SINGLE_PASS_STEREO)
            return 0.5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]);
        #else
            return _WorldSpaceCameraPos.xyz;
        #endif
        }
        void GetCenterEyeBasis(float3 anchorWS, out float3 camPos, out float3 camRight, out float3 camUp)
        {
            camPos = GetCenterEyePos();
            float3 worldUp = float3(0,1,0);
            float3 viewDir = normalize(camPos - anchorWS);
            camRight = normalize(cross(worldUp, viewDir));
            camUp    = worldUp;
            if (abs(camRight.x)+abs(camRight.y)+abs(camRight.z) < 1e-4)
                camRight = normalize(UNITY_MATRIX_I_V[0].xyz);
        }

        float DistanceFade(float d)
        {
            float s = max(1e-6, _FadeSoftness);
            float aNear = smoothstep(_MinFade, _MinFade + s, d);
            float aFar  = 1.0 - smoothstep(_MaxFade - s, _MaxFade, d);
            return saturate(aNear * aFar);
        }

        // Left-eye invView (SPS fix)
        float4x4 GetLeftEyeInvView()
        {
        #if defined(UNITY_SINGLE_PASS_STEREO)
            return unity_StereoMatrixInvV[0];
        #else
            return UNITY_MATRIX_I_V;
        #endif
        }
        float3 ViewPosToWorld(float3 vp)
        {
            float4x4 invV = GetLeftEyeInvView();
            return mul(invV, float4(vp,1)).xyz;
        }
        float3 ViewDirToWorld(float3 vd)
        {
            float4x4 invV = GetLeftEyeInvView();
            return normalize(mul((float3x3)invV, vd));
        }

        // World-space ribbon line
        void EmitWorldLine(float3 aWS, float3 bWS, float3 rgb, inout TriangleStream<g2f> ts)
        {
            float3 mid = 0.5*(aWS+bWS);
            float3 camPos = GetCenterEyePos();

            float3 n = cross(mid - camPos, aWS - bWS);
            float  nLen = max(length(n), 1e-6);
            float3 off = (n / nLen) * (_LineWorldWidth * 0.5);

            float3 aL = aWS - off, aR = aWS + off;
            float3 bL = bWS - off, bR = bWS + off;

            g2f o; o.col = MakeLineColor(rgb); o.uv = float2(-1,-1); o.vals = 0; o.labelMode = 0;
            o.pos = UnityWorldToClipPos(aL); ts.Append(o);
            o.pos = UnityWorldToClipPos(aR); ts.Append(o);
            o.pos = UnityWorldToClipPos(bL); ts.Append(o);
            o.pos = UnityWorldToClipPos(bR); ts.Append(o);
            ts.RestartStrip();
        }

        // ===================== LABELS =====================

        // Point/Spot: 3-row slab (D/R/I) as one quad using PS offsets
        void EmitLabelQuad3Rows_PS(float3 anchorWS, float3 rowVals, bool hideLabels, inout TriangleStream<g2f> ts)
        {
            if (hideLabels) return;

            float3 camPos, camRight, camUp;
            GetCenterEyeBasis(anchorWS, camPos, camRight, camUp);

            float2 offsetRU = _LabelWorldOffset.xy;
            float  hWorld   = _LabelWorldH;
            float  totalH   = hWorld*3.0 + _LabelWorldGap*2.0;
            float  wWorld   = hWorld * CHAR_ASPECT * LABEL_LEN;

            float3 center   = anchorWS + camRight*offsetRU.x + camUp*offsetRU.y;
            float  fade     = DistanceFade(distance(camPos, center));

            float3 tlWS = center + (-0.5*wWorld)*camRight + ( 0.5*totalH)*camUp;
            float3 blWS = center + (-0.5*wWorld)*camRight + (-0.5*totalH)*camUp;
            float3 trWS = center + ( 0.5*wWorld)*camRight + ( 0.5*totalH)*camUp;
            float3 brWS = center + ( 0.5*wWorld)*camRight + (-0.5*totalH)*camUp;

            g2f o; o.col = fixed4(1,1,1, _Alpha * fade); o.vals = rowVals; o.labelMode = 0.0;
            o.uv=float2(0,0); o.pos=UnityWorldToClipPos(tlWS); ts.Append(o);
            o.uv=float2(0,1); o.pos=UnityWorldToClipPos(blWS); ts.Append(o);
            o.uv=float2(1,0); o.pos=UnityWorldToClipPos(trWS); ts.Append(o);
            o.uv=float2(1,1); o.pos=UnityWorldToClipPos(brWS); ts.Append(o);
            ts.RestartStrip();
        }

        // Directional & single-row number labels at DIR area
        void EmitRowAtDirArea(float3 anchorWS, int rowIdx, float val, float rowsUp, bool hideLabels, fixed3 tint, float numberOnly, inout TriangleStream<g2f> ts)
        {
            if (hideLabels) return;

            float3 camPos, camRight, camUp;
            GetCenterEyeBasis(anchorWS, camPos, camRight, camUp);

            float2 dirRU  = _DirLabelOffsetRU.xy;     // DIR start (Right,Up)
            float  hWorld = _LabelWorldH;
            float  wWorld = hWorld * CHAR_ASPECT * LABEL_LEN;

            float  perRow = (hWorld + _LabelWorldGap) * _DirLabelStepRows;
            float3 center = anchorWS + camRight*dirRU.x + camUp*(dirRU.y + rowsUp * perRow);

            float  fade   = DistanceFade(distance(camPos, center));

            float3 tlWS = center + (-0.5*wWorld)*camRight + ( 0.5*hWorld)*camUp;
            float3 blWS = center + (-0.5*wWorld)*camRight + (-0.5*hWorld)*camUp;
            float3 trWS = center + ( 0.5*wWorld)*camRight + ( 0.5*hWorld)*camUp;
            float3 brWS = center + ( 0.5*wWorld)*camRight + (-0.5*hWorld)*camUp;

            float row0 = (float)rowIdx / 3.0;
            float row1 = (float)(rowIdx+1) / 3.0;

            g2f o; o.col = fixed4(tint, _Alpha * fade); o.labelMode = numberOnly;
            o.vals = (rowIdx==0) ? float3(val,0,0) : (rowIdx==1? float3(0,val,0) : float3(0,0,val));

            o.uv=float2(0,row0); o.pos=UnityWorldToClipPos(tlWS); ts.Append(o);
            o.uv=float2(0,row1); o.pos=UnityWorldToClipPos(blWS); ts.Append(o);
            o.uv=float2(1,row0); o.pos=UnityWorldToClipPos(trWS); ts.Append(o);
            o.uv=float2(1,row1); o.pos=UnityWorldToClipPos(brWS); ts.Append(o);
            ts.RestartStrip();
        }

        // Axes: single 3-row slab at DIR area, number-only mode (labelMode=2)
        void EmitAxesNumbersSlab(float3 anchorWS, float rowsUpBase, float3 xyzVals, bool hideLabels, inout TriangleStream<g2f> ts)
        {
            if (hideLabels) return;

            float3 camPos, camRight, camUp;
            GetCenterEyeBasis(anchorWS, camPos, camRight, camUp);

            float2 dirRU  = _DirLabelOffsetRU.xy;
            float  hWorld = _LabelWorldH;
            float  totalH = hWorld*3.0 + _LabelWorldGap*2.0;
            float  wWorld = hWorld * CHAR_ASPECT * LABEL_LEN;

            float  perRow = (hWorld + _LabelWorldGap) * _DirLabelStepRows;
            float3 center = anchorWS + camRight*dirRU.x + camUp*(dirRU.y + rowsUpBase * perRow);

            float  fade   = DistanceFade(distance(camPos, center));

            float3 tlWS = center + (-0.5*wWorld)*camRight + ( 0.5*totalH)*camUp;
            float3 blWS = center + (-0.5*wWorld)*camRight + (-0.5*totalH)*camUp;
            float3 trWS = center + ( 0.5*wWorld)*camRight + ( 0.5*totalH)*camUp;
            float3 brWS = center + ( 0.5*wWorld)*camRight + (-0.5*totalH)*camUp;

            g2f o; o.col = fixed4(1,1,1, _Alpha * fade); // per-row tint in frag
            o.vals = xyzVals; o.labelMode = 2.0;

            o.uv=float2(0,0); o.pos=UnityWorldToClipPos(tlWS); ts.Append(o);
            o.uv=float2(0,1); o.pos=UnityWorldToClipPos(blWS); ts.Append(o);
            o.uv=float2(1,0); o.pos=UnityWorldToClipPos(trWS); ts.Append(o);
            o.uv=float2(1,1); o.pos=UnityWorldToClipPos(brWS); ts.Append(o);
            ts.RestartStrip();
        }

        // ===================== HELPERS =====================

        float3 ComputeClampedEndpoint(float3 rootWS, float3 lightWS, float range)
        {
            float3 dir  = rootWS - lightWS;
            float  dist = length(dir);
            float3 nDir = (dist > 1e-6) ? (dir / dist) : float3(0,1,0);
            float  len  = min(dist, max(range, 0.0));
            return lightWS + nDir * len;
        }

        // Where to place PS labels (either at light, or snapped along the line)
        float3 GetPSLabelAnchor(float3 rootWS, float3 lightWS, float range)
        {
            float3 endWS = (_ClampLineToRange > 0.5)
                ? ComputeClampedEndpoint(rootWS, lightWS, range)
                : lightWS;

            float segLen = distance(rootWS, endWS);

            if (_UseSnapLabelAlongLine > 0.5 && segLen > _SnapCutoffDist)
            {
                float3 dir = normalize(endWS - rootWS);
                float  t   = max(0.0, min(_SnapAlongDist, segLen));
                return rootWS + dir * t;
            }
            // default: above the light
            return lightWS;
        }

        void EmitPointOrSpot(float3 rootWS, float3 lightWS, float3 rgb, float range, bool hideLabels, inout TriangleStream<g2f> ts)
        {
            float3 aWS = (_ClampLineToRange > 0.5) ? lightWS : rootWS;
            float3 bWS = (_ClampLineToRange > 0.5) ? ComputeClampedEndpoint(rootWS, lightWS, range) : lightWS;

            EmitWorldLine(aWS, bWS, rgb, ts);

            if (_UseLabels > 0.5)
            {
                float dist  = distance(lightWS, rootWS);
                float3 vals = float3(dist, range, Luminance(rgb));

                // place slab at light or snapped toward root
                float3 anchor = GetPSLabelAnchor(rootWS, lightWS, range);
                EmitLabelQuad3Rows_PS(anchor, vals, hideLabels, ts);
            }
        }

        // Directional: line + "I:" row (stacked)
        void EmitDirectionalShifted(float3 rootWS, float3 dirWS, float3 rgb, float shiftRows, bool hideLabels, inout TriangleStream<g2f> ts)
        {
            float3 aWS = rootWS;
            float3 bWS = rootWS + normalize(dirWS) * max(_DirLineLength, 0.0);
            EmitWorldLine(aWS, bWS, rgb, ts);

            if (_UseLabels > 0.5)
            {
                float inten = Luminance(rgb);
                EmitRowAtDirArea(rootWS, 2, inten, shiftRows, hideLabels, fixed3(1,1,1), 0.0, ts);
            }
        }

        // ===================== FRAGMENT =====================
        fixed4 frag(g2f i) : SV_Target
        {
            // Lines path
            if (i.uv.x < 0.0) return i.col;

            // Row (0..2) inside a 3-row slab
            float v  = saturate(i.uv.y);
            int   row = (int)floor(v * 3.0 + 1e-5);

            // Value for this row
            float value = (row==0)? i.vals.x : (row==1? i.vals.y : i.vals.z);

            // Negative support + abs for formatting
            bool  neg = (value < 0.0);
            float av  = abs(value);

            // ----- STABLE PRECISION / DOT PLACEMENT -----
            // Integer digit count by thresholds (avoid log10)
            int intCount = 1;
            if (av >= 10.0)       intCount = 2;
            if (av >= 100.0)      intCount = 3;
            if (av >= 1000.0)     intCount = 4;
            if (av >= 10000.0)    intCount = 5;
            if (av >= 100000.0)   intCount = 6;
            if (av >= 1000000.0)  intCount = 7;
            if (av >= 10000000.0) intCount = 8;

            // Desired integer display digits (dot at 4 while small)
            int intDisp   = (intCount <= 4) ? 4 : min(intCount, 8);
            int fracCount = min(4, max(0, 8 - intDisp));

            // Round to available precision
            float scale = (fracCount==0?1.0:(fracCount==1?10.0:(fracCount==2?100.0:(fracCount==3?1000.0:10000.0))));
            float scaledF = floor(av * scale + 0.5);
            const float MAX8 = 99999999.0;  // 8 digits
            const float LIM9 = 100000000.0; // overflow to 9 digits (carry)

            // Carry-safe adjust at boundaries (e.g., 9999.99995 -> 10000.0000)
            if (scaledF >= LIM9)
            {
                // Shift one more integer digit, reduce frac by one
                intDisp   = min(8, intDisp + 1);
                fracCount = max(0, fracCount - 1);
                scale = (fracCount==0?1.0:(fracCount==1?10.0:(fracCount==2?100.0:(fracCount==3?1000.0:10000.0))));
                scaledF = floor(av * scale + 0.5);
                if (scaledF >= LIM9) scaledF = MAX8; // hard cap (extreme edge)
            }

            // Extract digits d7..d0 (d7 most significant)
            int d7 = (int)floor(scaledF / 10000000.0); scaledF -= d7 * 10000000.0;
            int d6 = (int)floor(scaledF / 1000000.0);  scaledF -= d6 * 1000000.0;
            int d5 = (int)floor(scaledF / 100000.0);   scaledF -= d5 * 100000.0;
            int d4 = (int)floor(scaledF / 10000.0);    scaledF -= d4 * 10000.0;
            int d3 = (int)floor(scaledF / 1000.0);     scaledF -= d3 * 1000.0;
            int d2 = (int)floor(scaledF / 100.0);      scaledF -= d2 * 100.0;
            int d1 = (int)floor(scaledF / 10.0);       scaledF -= d1 * 10.0;
            int d0 = (int)scaledF;

            // Horizontal slot j across the row (0..10)
            float x = saturate(i.uv.x);
            float fIndex = x * LABEL_LEN;
            int   j = (int)floor(fIndex); j = clamp(j, 0, LABEL_LEN-1);
            float within = frac(fIndex);

            int glyph = GLYPH_SPACE;

            // Helper: pick digit by absolute index 7..0
            #define PICKDG(W) ((W)==7?d7:((W)==6?d6:((W)==5?d5:((W)==4?d4:((W)==3?d3:((W)==2?d2:((W)==1?d1:d0)))))))

            if (i.labelMode < 0.5)
            {
                // PS/DIR with leading letter + colon, then number section (slots 2..10)
                if      (j == 0) glyph = (row==0) ? GLYPH_D : (row==1 ? GLYPH_R : GLYPH_I);
                else if (j == 1) glyph = GLYPH_COLON;
                else
                {
                    int idx = j - 2; // 0..8 numeric section
                    if (idx < intDisp)
                    {
                        int which = 7 - idx;
                        glyph = GLYPH_DIGIT0 + PICKDG(which);
                    }
                    else
                    {
                        if (fracCount > 0)
                        {
                            if (idx == intDisp) glyph = GLYPH_DOT;
                            else
                            {
                                int n = idx - intDisp - 1;     // 0..(fracCount-1)
                                int which = 7 - (intDisp + n); // continues left->right
                                glyph = GLYPH_DIGIT0 + PICKDG(which);
                            }
                        }
                        else glyph = GLYPH_SPACE;
                    }
                }
            }
            else
            {
                // Number-only (single row or axes slab). Slot 1 can hold the minus.
                if      (j == 0) glyph = GLYPH_SPACE;
                else if (j == 1) glyph = neg ? GLYPH_MINUS : GLYPH_SPACE;
                else
                {
                    int idx = j - 2; // 0..8 numeric section
                    if (idx < intDisp)
                    {
                        int which = 7 - idx;
                        glyph = GLYPH_DIGIT0 + PICKDG(which);
                    }
                    else
                    {
                        if (fracCount > 0)
                        {
                            if (idx == intDisp) glyph = GLYPH_DOT;
                            else
                            {
                                int n = idx - intDisp - 1;
                                int which = 7 - (intDisp + n);
                                glyph = GLYPH_DIGIT0 + PICKDG(which);
                            }
                        }
                        else glyph = GLYPH_SPACE;
                    }
                }
            }

            // Atlas sampling (configurable columns)
            float cellW = 1.0 / max(_AtlasCols, 1.0);
            float padU  = _GlyphsTex_TexelSize.x * 2.0;
            float padV  = _GlyphsTex_TexelSize.y * 2.0;

            float u0 = glyph * cellW + padU;
            float u1 = (glyph + 1) * cellW - padU;
            float v0 = padV, v1 = 1.0 - padV;

            float vRow = frac(v * 3.0);
            fixed a = tex2Dlod(_GlyphsTex, float4(lerp(u0,u1,within), lerp(v0,v1, vRow), 0, 0)).r;

            // Per-row tint for AXES slab (labelMode==2): row0=R, row1=G, row2=B
            fixed3 tint = i.col.rgb;
            if (i.labelMode > 1.5)
            {
                tint = (row==0) ? fixed3(1,0,0) : (row==1 ? fixed3(0,1,0) : fixed3(0,0,1));
            }

            return fixed4(tint, max(a, 0.001) * i.col.a);
        }
        ENDCG

        // ===================== PASS =====================
        Pass
        {
            Tags { "LightMode"="Vertex" }
            CGPROGRAM
            #pragma vertex   vert
            #pragma geometry geom
            #pragma fragment frag

            // D3D11: 14 scalars/vertex => 72 verts max (72*14 = 1008 ≤ 1024)
            [maxvertexcount(72)]
            void geom(point v2g IN[1], inout TriangleStream<g2f> ts)
            {
                if (_Alpha <= 0.001) return;
                float3 rootWS = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;

                bool inMirror  = (_VRChatMirrorMode > 0.5);
                bool hideStats = (_HideStatsInVRCMirror > 0.5) && inMirror;

                // per-light worst-case: line quad (4) + one label slab (4) = 8 verts
                // axes: 3 lines (12) + single 3-row slab (4) = 16 verts
                int lightQuota = ((_ShowWorldAxes > 0.5) && (_UseLabels > 0.5) && !hideStats) ? 7 : 8;
                int processedLights = 0;
                int dirCount = 0;

                [unroll]
                for (int i = 0; i < 8; i++)
                {
                    if (processedLights >= lightQuota) break;

                    float4 lpV = unity_LightPosition[i]; // left-eye view space in SPS
                    if (abs(lpV.x)+abs(lpV.y)+abs(lpV.z)+abs(lpV.w) <= 1e-6)
                        continue;

                    if (lpV.w == 0.0)
                    {
                        if (_ShowDirectional <= 0.5) continue;

                        float3 rgb = (float3)unity_LightColor[i].rgb;
                        if (dot(rgb, rgb) <= 1e-10) continue;
                        if (dot(lpV.xyz, lpV.xyz) <= 1e-8) continue;

                        float3 dirWS = ViewDirToWorld(-lpV.xyz);
                        EmitDirectionalShifted(rootWS, dirWS, rgb, (float)dirCount, hideStats, ts);
                        dirCount++;
                        processedLights++;
                    }
                    else
                    {
                        float3 lightWS = ViewPosToWorld(lpV.xyz);
                        float  range   = sqrt(max(0.0, (float)unity_LightAtten[i].w));
                        float3 rgb     = (float3)unity_LightColor[i].rgb;

                        EmitPointOrSpot(rootWS, lightWS, rgb, range, hideStats, ts);
                        processedLights++;
                    }
                }

                if (_ShowWorldAxes > 0.5)
                {
                    float L = max(_AxisLineLength, 0.0);
                    if (L > 1e-6)
                    {
                        EmitWorldLine(rootWS, rootWS + float3(L,0,0), float3(1,0,0), ts); // +X
                        EmitWorldLine(rootWS, rootWS + float3(0,L,0), float3(0,1,0), ts); // +Y
                        EmitWorldLine(rootWS, rootWS + float3(0,0,L), float3(0,0,1), ts); // +Z
                    }

                    if (_UseLabels > 0.5 && !hideStats)
                    {
                        float baseRows = (float)dirCount + _AxesRowOffset;
                        float3 xyzVals = float3(rootWS.x, rootWS.y, rootWS.z);
                        EmitAxesNumbersSlab(rootWS, baseRows, xyzVals, /*hide*/ false, ts);
                    }
                }
            }
            ENDCG
        }
    }

    Fallback Off
}
