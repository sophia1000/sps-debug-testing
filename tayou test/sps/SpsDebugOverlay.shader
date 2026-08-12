Shader "Hidden/Amity/SpsDebugOverlay" {
    Properties {
        [Header(Visibility)]
        [Toggle] _ShowSockets("Show Sockets", Float) = 1
        [Toggle] _ShowPlugs("Show Resolved Plugs", Float) = 0
        [Toggle] _ShowRing("Show Rings", Float) = 1
        [Toggle] _ShowArrow("Show Direction Arrows", Float) = 1
        [Toggle] _ShowTags("Show Tag Markers", Float) = 1
        [Toggle] _ShowChain("Show Chain Links", Float) = 1

        [Header(Appearance)]
        _GizmoScale("Gizmo Scale", Range(0.1, 10)) = 1
        _LineWidthPx("Line Width (Pixels)", Range(0.5, 8)) = 2
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("Depth Test", Float) = 8
        _Radius("Radius", Range(0, 50)) = 5
        _FadeWidth("Fade Width", Range(0.01, 10)) = 0.3

        [Header(Colors)]
        _HoleColor("Hole Color", Color) = (1, 0.2, 0.2, 0.9)
        _RingColor("Ring Color", Color) = (0.2, 0.5, 1, 0.9)
        _ReversibleColor("Reversible Color", Color) = (0.2, 1, 0.3, 0.9)
        _PlugColor("Plug Color", Color) = (1, 0.8, 0.2, 0.9)
        _ChainColor("Chain Color", Color) = (1, 1, 1, 0.6)
    }
    SubShader {
        Tags {
            "Queue" = "Transparent+100"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
            "VRCFallback" = "Hidden"
        }
        Pass {
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            ZWrite Off
            ZTest [_ZTest]

            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"
            #include "sps_cell_layout.cginc"
            #include "sps_types.cginc"
            #include "sps_utils.cginc"
            #include "sps_resolver_types.cginc"

            SPS_INIT_TEX(_VFGridFinal)

            float _ShowSockets;
            float _ShowPlugs;
            float _ShowRing;
            float _ShowArrow;
            float _ShowTags;
            float _ShowChain;
            float _GizmoScale;
            float _LineWidthPx;
            float _Radius;
            float _FadeWidth;
            float4 _HoleColor;
            float4 _RingColor;
            float4 _ReversibleColor;
            float4 _PlugColor;
            float4 _ChainColor;
            
            static float g_radiusFade = 1.0;

            #define SPS_DEBUG_RING_SEGMENTS 16
            // Each gizmo is split across 4 geometry shader invocations (one
            // dispatch point per part) so every invocation stays within the
            // D3D11 limit of 1024 scalar output components.
            // Part 0: inner ring, Part 1: outer ring,
            // Part 2: arrows / plug axes, Part 3: tag markers + chain link.
            #define SPS_DEBUG_PART_COUNT 4
            #define SPS_DEBUG_MAX_VERTICES 64

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2g {
                float4 vertex : SV_POSITION;
                nointerpolation uint slotIndex : TEXCOORD0;
                nointerpolation uint partIndex : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            struct g2f {
                float4 vertex : SV_POSITION;
                nointerpolation float4 color : COLOR0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2g vert(appdata v) {
                UNITY_SETUP_INSTANCE_ID(v);
                v2g o = (v2g)0;
                o.vertex = float4(0, 0, 0, 1);
                o.slotIndex = (uint)round(v.uv.x);
                o.partIndex = (uint)round(v.uv.y);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                return o;
            }

            uint sps_debug_hash_id(uint id, uint playerId) {
                return playerId == 0u ? id : sps_hash_mix(id ^ sps_hash_mix(playerId));
            }

            uint sps_debug_payload_uint(SpsCell cell, uint payloadIndex) {
                return cell.read_uint(sps_cell_pixel_index_from_payload_index(payloadIndex));
            }

            // Cheap identity checks (1 texel each) are ordered before the
            // 4-texel magic validation so mismatching cells bail after a single
            // read. The corner-0 pre-filter rejects empty slots after one read
            // too, before we pay for the full 4-corner magic check.
            bool sps_debug_cell_matches(
                SpsTexture tex,
                int slotIndex,
                uint uniqueId,
                uint playerId,
                uint product
            ) {
                if (slotIndex < 0 || slotIndex >= sps_socket_slot_count()) return false;
                SpsCell candidate = sps_get_cell(tex, slotIndex);
                if (!amity_sps_cell_check_magic_corner0(candidate)) return false;
                if (candidate.read_uint(SPS_HEADER_VENDOR_INDEX) != SPS_VENDOR_SPS) return false;
                if (candidate.read_uint(SPS_HEADER_PRODUCT_INDEX) != product) return false;
                if (amity_sps_cell_header_unique_id(candidate) != uniqueId) return false;
                if (amity_sps_cell_header_player_id(candidate) != playerId) return false;
                // Only now, having passed the cheap identity gates, confirm the
                // remaining magic corners to rule out a corner-0 hash collision.
                return sps_cell_check_magic(candidate);
            }

            // A slot is the "primary" replica if it is the lowest-indexed
            // replica hash that lands on a valid matching cell. We scan replicas
            // in order and stop at the first valid match: if that match is this
            // slot, we are primary; otherwise an earlier replica owns the gizmo.
            // A real break (dynamic loop, no [unroll]) lets the common
            // no-collision case exit after a single iteration.
            bool sps_debug_is_primary_replica(SpsTexture tex, uint slotIndex, SpsCell cell) {
                uint uniqueId = amity_sps_cell_header_unique_id(cell);
                uint playerId = amity_sps_cell_header_player_id(cell);
                uint product = cell.read_uint(SPS_HEADER_PRODUCT_INDEX);
                uint seed = sps_debug_hash_id(uniqueId, playerId);

                for (uint replica = 0u; replica < SPS_CELL_REPLICA_COUNT; replica++) {
                    int candidateIndex = (int)sps_hashed_screen_slot_index_from_id(seed, replica);
                    if (!sps_debug_cell_matches(tex, candidateIndex, uniqueId, playerId, product)) continue;
                    return candidateIndex == (int)slotIndex;
                }
                return false;
            }

            bool sps_debug_find_socket(
                SpsTexture tex,
                uint uniqueId,
                uint playerId,
                out float3 worldPosition
            ) {
                worldPosition = float3(0, 0, 0);
                uint seed = sps_debug_hash_id(uniqueId, playerId);

                for (uint replica = 0u; replica < SPS_CELL_REPLICA_COUNT; replica++) {
                    int candidateIndex = (int)sps_hashed_screen_slot_index_from_id(seed, replica);
                    if (!sps_debug_cell_matches(
                        tex,
                        candidateIndex,
                        uniqueId,
                        playerId,
                        SPS_PRODUCT_SOCKET
                    )) continue;
                    worldPosition = sps_cell_header_world(sps_get_cell(tex, candidateIndex));
                    return true;
                }
                return false;
            }

            float3 sps_debug_hash_color(uint hash) {
                float h = (hash % 360u) / 360.0;
                float3 p = abs(frac(h + float3(0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
                return lerp(float3(1, 1, 1), saturate(p - 1.0), 0.8) * 0.9;
            }

            void sps_debug_append_vertex(
                float4 clipPosition,
                float4 color,
                v2g source,
                inout TriangleStream<g2f> stream
            ) {
                g2f o = (g2f)0;
                o.vertex = clipPosition;
                o.color = color;
                o.color.a *= g_radiusFade;
                UNITY_TRANSFER_INSTANCE_ID(source, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                stream.Append(o);
            }

            void sps_debug_emit_line(
                float3 worldA,
                float3 worldB,
                float widthPx,
                float4 color,
                v2g source,
                inout TriangleStream<g2f> stream
            ) {
                float4 clipA = UnityWorldToClipPos(worldA);
                float4 clipB = UnityWorldToClipPos(worldB);

                if (clipA.w > 0.0001 && clipB.w > 0.0001) {
                    float2 pixelA = (clipA.xy / clipA.w * 0.5 + 0.5) * _ScreenParams.xy;
                    float2 pixelB = (clipB.xy / clipB.w * 0.5 + 0.5) * _ScreenParams.xy;
                    float2 pixelDelta = pixelB - pixelA;
                    float pixelLength = length(pixelDelta);

                    if (pixelLength > 0.001) {
                        float2 perpendicular = float2(-pixelDelta.y, pixelDelta.x) / pixelLength;
                        float2 offsetNdc = perpendicular * (widthPx * 0.5) / _ScreenParams.xy * 2.0;

                        float4 aPlus = clipA;
                        float4 aMinus = clipA;
                        float4 bPlus = clipB;
                        float4 bMinus = clipB;
                        aPlus.xy += offsetNdc * clipA.w;
                        aMinus.xy -= offsetNdc * clipA.w;
                        bPlus.xy += offsetNdc * clipB.w;
                        bMinus.xy -= offsetNdc * clipB.w;

                        sps_debug_append_vertex(aPlus, color, source, stream);
                        sps_debug_append_vertex(aMinus, color, source, stream);
                        sps_debug_append_vertex(bPlus, color, source, stream);
                        sps_debug_append_vertex(bMinus, color, source, stream);
                        stream.RestartStrip();
                    }
                }
            }

            void sps_debug_emit_ring(
                float3 center,
                float3 right,
                float3 up,
                float radius,
                float4 color,
                v2g source,
                inout TriangleStream<g2f> stream
            ) {
                [unroll]
                for (int segment = 0; segment < SPS_DEBUG_RING_SEGMENTS; segment++) {
                    float angleA = UNITY_TWO_PI * segment / SPS_DEBUG_RING_SEGMENTS;
                    float angleB = UNITY_TWO_PI * (segment + 1) / SPS_DEBUG_RING_SEGMENTS;
                    float3 pointA = center + (right * cos(angleA) + up * sin(angleA)) * radius;
                    float3 pointB = center + (right * cos(angleB) + up * sin(angleB)) * radius;
                    sps_debug_emit_line(pointA, pointB, _LineWidthPx, color, source, stream);
                }
            }

            void sps_debug_emit_arrow(
                float3 start,
                float3 end,
                float3 right,
                float3 up,
                float4 color,
                v2g source,
                inout TriangleStream<g2f> stream
            ) {
                float3 direction = sps_normalize(end - start);
                float lengthWorld = max(length(end - start), 0.001);
                float headLength = min(lengthWorld * 0.35, 0.02 * _GizmoScale);
                float headWidth = headLength * 0.6;
                float3 headBase = end - direction * headLength;

                sps_debug_emit_line(start, end, _LineWidthPx, color, source, stream);
                sps_debug_emit_line(end, headBase + right * headWidth, _LineWidthPx, color, source, stream);
                sps_debug_emit_line(end, headBase - right * headWidth, _LineWidthPx, color, source, stream);
                sps_debug_emit_line(end, headBase + up * headWidth, _LineWidthPx, color, source, stream);
                sps_debug_emit_line(end, headBase - up * headWidth, _LineWidthPx, color, source, stream);
            }

            void sps_debug_emit_tag_markers(
                SpsCell cell,
                float3 center,
                float3 right,
                float3 up,
                v2g source,
                inout TriangleStream<g2f> stream
            ) {
                [unroll]
                for (uint tagIndex = 0u; tagIndex < SPS_SOCKET_PAYLOAD_TAG_COUNT; tagIndex++) {
                    uint tagHash = sps_debug_payload_uint(cell, SPS_SOCKET_PAYLOAD_TAG_START + tagIndex);
                    if (tagHash == 0u) continue;
                    float angle = 6.2831853 * tagIndex / SPS_SOCKET_PAYLOAD_TAG_COUNT;
                    float3 radial = right * cos(angle) + up * sin(angle);
                    float3 markerStart = center + radial * (0.044 * _GizmoScale);
                    float3 markerEnd = center + radial * (0.056 * _GizmoScale);
                    float4 tagColor = float4(sps_debug_hash_color(tagHash), 0.95);
                    sps_debug_emit_line(markerStart, markerEnd, _LineWidthPx * 2.0, tagColor, source, stream);
                }
            }

            void sps_debug_emit_plug_pill(
                SpsCell cell,
                float3 center,
                float3 forward,
                float3 right,
                float3 up,
                uint partIndex,
                v2g source,
                inout TriangleStream<g2f> stream
            ) {
                float plugLength = cell.read_float(SPS_PLUG_LENGTH_INDEX);
                float plugRadius = cell.read_float(SPS_PLUG_RADIUS_INDEX);
                if (plugLength <= 0 || plugRadius <= 0) return;

                // Capsule anchored at the plug base (the cell origin), extending
                // forward by `plugLength`. The base end is flat; only the far
                // (tip) end gets a rounded dome of radius `plugRadius`.
                float3 base = center;
                float rimT = max(0.0, plugLength - plugRadius);
                float3 rim = base + forward * rimT;
                float3 pole = base + forward * plugLength;

                if (partIndex == 0u) {
                    sps_debug_emit_ring(base, right, up, plugRadius, _PlugColor, source, stream);
                } else if (partIndex == 1u) {
                    sps_debug_emit_ring(rim, right, up, plugRadius, _PlugColor, source, stream);
                } else if (partIndex == 2u) {
                    [unroll]
                    for (int side = 0; side < 4; side++) {
                        float angle = UNITY_TWO_PI * side / 4.0;
                        float3 radial = right * cos(angle) + up * sin(angle);
                        sps_debug_emit_line(base + radial * plugRadius, rim + radial * plugRadius, _LineWidthPx, _PlugColor, source, stream);
                    }
                } else if (partIndex == 3u) {
                    // Dome silhouette on the tip end. Two meridian arcs from the
                    // rim to the pole (hemisphere of radius `plugRadius` whose
                    // center sits plugRadius before the pole).
                    for (int arc = 0; arc < 2; arc++) {
                        float angle = UNITY_TWO_PI * arc / 4.0;
                        float3 radial = right * cos(angle) + up * sin(angle);
                        int segments = 8;
                        for (int s = 0; s < segments; s++) {
                            float tA = (float)s / segments;
                            float tB = (float)(s + 1) / segments;
                            // theta: 90deg at the rim -> 0deg at the pole.
                            float thetaA = UNITY_PI * (1.0 - tA);
                            float thetaB = UNITY_PI * (1.0 - tB);
                            float3 a = rim
                                + forward * (plugRadius * sin(thetaA))
                                + radial * (plugRadius * cos(thetaA));
                            float3 b = rim
                                + forward * (plugRadius * sin(thetaB))
                                + radial * (plugRadius * cos(thetaB));
                            sps_debug_emit_line(a, b, _LineWidthPx, _PlugColor, source, stream);
                        }
                    }
                }
            }

            [maxvertexcount(SPS_DEBUG_MAX_VERTICES)]
            void geom(point v2g input[1], inout TriangleStream<g2f> stream) {
                UNITY_SETUP_INSTANCE_ID(input[0]);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input[0]);

                SpsTexture tex = SPS_GET_TEX(_VFGridFinal);
                uint slotIndex = input[0].slotIndex;
                uint partIndex = input[0].partIndex;
                if (slotIndex >= (uint)sps_socket_slot_count()) return;

                SpsCell cell = sps_get_cell(tex, (int)slotIndex);
                // Fast path: reject the (overwhelmingly common) empty slot after
                // a single texel read before touching the rest of the header.
                if (!amity_sps_cell_check_magic_corner0(cell)) return;
                if (cell.read_uint(SPS_HEADER_VENDOR_INDEX) != SPS_VENDOR_SPS) return;

                uint product = cell.read_uint(SPS_HEADER_PRODUCT_INDEX);
                bool isSocket = product == SPS_PRODUCT_SOCKET;
                bool isPlug = product == SPS_PRODUCT_PLUG;
                if ((!isSocket || !amity_sps_to_bool(_ShowSockets)) && (!isPlug || !amity_sps_to_bool(_ShowPlugs))) return;

                // Radius cull first: it only needs the world position (3 reads)
                // and rejects out-of-range gizmos before we pay for the full
                // 4-corner magic validation and the expensive primary-replica
                // probe (~5 hash probes). The corner-0 pre-filter above already
                // guarantees this slot holds a plausible cell, so the world read
                // is safe.
                float3 center = amity_sps_cell_header_world(cell);
                float3 objectWorldPos = unity_ObjectToWorld._m03_m13_m23;
                float distToObject = distance(center, objectWorldPos);
                g_radiusFade = (_Radius == 0.0) 
                    ? 1.0 
                    : smoothstep(0, max(_FadeWidth, 0.0001), _Radius - distToObject);
                if (g_radiusFade <= 0.0) return;   // fully outside radius, skip whole gizmo

                // Confirm the remaining magic corners now that the cheap product/
                // visibility/radius gates have passed (guards against a corner-0
                // hash collision on a slot we're about to emit geometry for).
                if (!amity_sps_cell_check_magic(cell)) return;
                if (!sps_debug_is_primary_replica(tex, slotIndex, cell)) return;

                float3 forward = sps_normalize(sps_cell_header_forward(cell));
                float3 sourceUp = sps_normalize(sps_cell_header_up(cell));
                float3 right = sps_normalize(cross(sourceUp, forward));
                float3 up = sps_normalize(cross(forward, right));

                if (isPlug) {
                    // Plugs render a capsule (length/radius from the payload)
                    // anchored at the plug base: ring at base, ring at tip rim,
                    // 4 side lines, dome arcs on the tip end.
                    if (partIndex < 4u && sps_to_bool(_ShowRing)) {
                        sps_debug_emit_plug_pill(cell, center, forward, right, up, partIndex, input[0], stream);
                    }
                    return;
                }

                uint flags = sps_debug_payload_uint(cell, SPS_SOCKET_PAYLOAD_FLAGS);
                bool hole = (flags & SPS_SOCKET_FLAG_HOLE) != 0u;
                bool doubleSided = (flags & SPS_SOCKET_FLAG_DOUBLE_SIDED) != 0u;
                float4 roleColor = float4(1, 1, 1, 0.9);
                if (hole && doubleSided) roleColor = _RingColor;
                else if (hole) roleColor = _HoleColor;
                else if (doubleSided) roleColor = _ReversibleColor;

                if (partIndex == 0u) {
                    if (sps_to_bool(_ShowRing)) {
                        sps_debug_emit_ring(center, right, up, 0.02 * _GizmoScale, roleColor, input[0], stream);
                    }
                } else if (partIndex == 1u) {
                    if (sps_to_bool(_ShowRing)) {
                        sps_debug_emit_ring(center, right, up, 0.04 * _GizmoScale, roleColor, input[0], stream);
                    }
                } else if (partIndex == 2u) {
                    if (sps_to_bool(_ShowArrow)) {
                        if (hole && doubleSided) {
                            sps_debug_emit_arrow(center, center - forward * 0.05 * _GizmoScale, right, up, roleColor, input[0], stream);
                            sps_debug_emit_arrow(center, center + forward * 0.05 * _GizmoScale, right, up, roleColor, input[0], stream);
                        } else if (doubleSided) {
                            sps_debug_emit_arrow(
                                center + forward * 0.05 * _GizmoScale,
                                center - forward * 0.05 * _GizmoScale,
                                right,
                                up,
                                roleColor,
                                input[0],
                                stream
                            );
                        } else {
                            sps_debug_emit_arrow(
                                center + forward * 0.1 * _GizmoScale,
                                center,
                                right,
                                up,
                                roleColor,
                                input[0],
                                stream
                            );
                        }
                    }
                } else {
                    if (sps_to_bool(_ShowTags)) {
                        sps_debug_emit_tag_markers(cell, center, right, up, input[0], stream);
                    }

                    if (sps_to_bool(_ShowChain)) {
                        uint nextId = sps_debug_payload_uint(cell, SPS_SOCKET_PAYLOAD_NEXT_ID);
                        float3 targetPosition = float3(0, 0, 0);
                        if (nextId != 0u && sps_debug_find_socket(
                            tex,
                            nextId,
                            sps_cell_header_player_id(cell),
                            targetPosition
                        )) {
                            sps_debug_emit_line(center, targetPosition, _LineWidthPx, _ChainColor, input[0], stream);
                        }
                    }
                }
            }

            fixed4 frag(g2f i) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                return i.color;
            }
            ENDCG
        }
    }
}
