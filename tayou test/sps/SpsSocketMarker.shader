Shader "Hidden/Amity/SpsSocketMarker" {
    Properties {
        [Header(Flags)]
        [Toggle] _SPS_SocketHole("Hole", Float) = 0
        [Toggle] _SPS_SocketDoubleSided("Double Sided", Float) = 0
        [Toggle] _SPS_SocketRadiusOffset("Radius Offset", Float) = 0
        _SPS_SocketNextId("Restrict Next Socket Id", Float) = 0
        [Toggle] _SPS_SocketUseTangentIn("Use Tangent In", Float) = 0
        [Toggle] _SPS_SocketUseTangentOut("Use Tangent Out", Float) = 0
        _SPS_SocketTangentIn("Tangent In", Vector) = (0,0,0,0)
        _SPS_SocketTangentOut("Tangent Out", Vector) = (0,0,0,0)
        [Header(Tags)]
        _SPS_SocketTag1("Tag 1", Float) = 0
        _SPS_SocketTag2("Tag 2", Float) = 0
        _SPS_SocketTag3("Tag 3", Float) = 0
        _SPS_SocketTag4("Tag 4", Float) = 0
        _SPS_SocketTag5("Tag 5", Float) = 0
        _SPS_SocketTag6("Tag 6", Float) = 0
        _SPS_SocketTag7("Tag 7", Float) = 0
        _SPS_SocketTag8("Tag 8", Float) = 1337
        [Header(Unique ID)]
        _SPS_Configured("ID Configured", Float) = 0
        _SPS_Id("ID", Float) = 0
        _SPS_PlayerId("Player ID", Float) = 0
    }
    SubShader {
        Tags {
            "Queue" = "Background-948"
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True"
            "VRCFallback" = "Hidden"
        }
        Pass {
            Cull Off
            ZWrite Off
            ZTest Always
            Blend One Zero
            ColorMask RGBA

            CGPROGRAM
            #pragma target 4.0
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma multi_compile_instancing
            #include "../sps/sps_cell_geom.cginc"
            #include "../sps/sps_cell_frag.cginc"
            #include "../sps/sps_cell_hash.cginc"
            #include "../sps/sps_types.cginc"
            #include "../sps/sps_utils.cginc"

            UNITY_INSTANCING_BUFFER_START(AmitySpsSocketProps)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketHole)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketDoubleSided)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketRadiusOffset)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketNextId)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketUseTangentIn)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketUseTangentOut)
                UNITY_DEFINE_INSTANCED_PROP(float4, _SPS_SocketTangentIn)
                UNITY_DEFINE_INSTANCED_PROP(float4, _SPS_SocketTangentOut)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketTag1)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketTag2)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketTag3)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketTag4)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketTag5)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketTag6)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketTag7)
                UNITY_DEFINE_INSTANCED_PROP(float, _SPS_SocketTag8)
            UNITY_INSTANCING_BUFFER_END(AmitySpsSocketProps)

            #define AMITY_SPS_SOCKET_PROP(name) UNITY_ACCESS_INSTANCED_PROP(AmitySpsSocketProps, name)
            #define _SPS_SocketHole AMITY_SPS_SOCKET_PROP(_SPS_SocketHole)
            #define _SPS_SocketDoubleSided AMITY_SPS_SOCKET_PROP(_SPS_SocketDoubleSided)
            #define _SPS_SocketRadiusOffset AMITY_SPS_SOCKET_PROP(_SPS_SocketRadiusOffset)
            #define _SPS_SocketNextId AMITY_SPS_SOCKET_PROP(_SPS_SocketNextId)
            #define _SPS_SocketUseTangentIn AMITY_SPS_SOCKET_PROP(_SPS_SocketUseTangentIn)
            #define _SPS_SocketUseTangentOut AMITY_SPS_SOCKET_PROP(_SPS_SocketUseTangentOut)
            #define _SPS_SocketTangentIn AMITY_SPS_SOCKET_PROP(_SPS_SocketTangentIn)
            #define _SPS_SocketTangentOut AMITY_SPS_SOCKET_PROP(_SPS_SocketTangentOut)
            #define _SPS_SocketTag1 AMITY_SPS_SOCKET_PROP(_SPS_SocketTag1)
            #define _SPS_SocketTag2 AMITY_SPS_SOCKET_PROP(_SPS_SocketTag2)
            #define _SPS_SocketTag3 AMITY_SPS_SOCKET_PROP(_SPS_SocketTag3)
            #define _SPS_SocketTag4 AMITY_SPS_SOCKET_PROP(_SPS_SocketTag4)
            #define _SPS_SocketTag5 AMITY_SPS_SOCKET_PROP(_SPS_SocketTag5)
            #define _SPS_SocketTag6 AMITY_SPS_SOCKET_PROP(_SPS_SocketTag6)
            #define _SPS_SocketTag7 AMITY_SPS_SOCKET_PROP(_SPS_SocketTag7)
            #define _SPS_SocketTag8 AMITY_SPS_SOCKET_PROP(_SPS_SocketTag8)

            struct appdata {
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2g {
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            struct g2f {
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
                nointerpolation int cellIndex : TEXCOORD0;
                nointerpolation float3 rootWorld : TEXCOORD1;
                nointerpolation float3 normalWorld : TEXCOORD2;
                nointerpolation float3 upWorld : TEXCOORD3;
            };

            v2g vert(appdata v) {
                UNITY_SETUP_INSTANCE_ID(v);
                v2g o;
                o.uv = v.uv;
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                return o;
            }

            [maxvertexcount((AMITY_SPS_CELL_REPLICA_COUNT + 1) * 3)]
            void geom(triangle v2g input[3], inout TriangleStream<g2f> stream) {
                UNITY_SETUP_INSTANCE_ID(input[0]);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input[0]);
                if (amity_sps_should_abort()) return;

                float3 rootWorld = amity_sps_object_origin_world();
                float3 normalWorld = amity_sps_object_forward_world();
                float3 upWorld = amity_sps_object_up_world();

                g2f o;
                o.rootWorld = rootWorld;
                o.normalWorld = normalWorld;
                o.upWorld = upWorld;
                UNITY_TRANSFER_INSTANCE_ID(input[0], o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                AMITY_SPS_CELL_GEOM(o, stream)
            }

            bool amity_sps_try_get_socket_payload_rgba(
                uint index,
                uint flags,
                uint nextId,
                uint tags[AMITY_SPS_SOCKET_PAYLOAD_TAG_COUNT],
                float3 tangentIn,
                float3 tangentOut,
                out float4 rgba
            ) {
                rgba = 0;
                if (index == amity_sps_cell_pixel_index_from_payload_index(AMITY_SPS_SOCKET_PAYLOAD_FLAGS)) {
                    rgba = amity_sps_encode_uint(flags);
                    return true;
                }
                if (index == amity_sps_cell_pixel_index_from_payload_index(AMITY_SPS_SOCKET_PAYLOAD_NEXT_ID)) {
                    rgba = amity_sps_encode_uint(nextId);
                    return true;
                }
                uint payloadIndex;
                if (!amity_sps_cell_payload_index_from_pixel_index(index, payloadIndex)) return false;
                if (payloadIndex >= AMITY_SPS_SOCKET_PAYLOAD_TAG_START
                    && payloadIndex < AMITY_SPS_SOCKET_PAYLOAD_TAG_START + AMITY_SPS_SOCKET_PAYLOAD_TAG_COUNT) {
                    rgba = amity_sps_encode_uint(tags[payloadIndex - AMITY_SPS_SOCKET_PAYLOAD_TAG_START]);
                    return true;
                }
                if (payloadIndex >= AMITY_SPS_SOCKET_PAYLOAD_TANGENT_IN_START
                    && payloadIndex < AMITY_SPS_SOCKET_PAYLOAD_TANGENT_IN_START + 3u) {
                    float comp = 0;
                    uint off = payloadIndex - AMITY_SPS_SOCKET_PAYLOAD_TANGENT_IN_START;
                    if (off == 0u) comp = tangentIn.x;
                    else if (off == 1u) comp = tangentIn.y;
                    else comp = tangentIn.z;
                    rgba = amity_sps_encode_float(comp);
                    return true;
                }
                if (payloadIndex >= AMITY_SPS_SOCKET_PAYLOAD_TANGENT_OUT_START
                    && payloadIndex < AMITY_SPS_SOCKET_PAYLOAD_TANGENT_OUT_START + 3u) {
                    float comp = 0;
                    uint off = payloadIndex - AMITY_SPS_SOCKET_PAYLOAD_TANGENT_OUT_START;
                    if (off == 0u) comp = tangentOut.x;
                    else if (off == 1u) comp = tangentOut.y;
                    else comp = tangentOut.z;
                    rgba = amity_sps_encode_float(comp);
                    return true;
                }
                return false;
            }

            float4 frag(g2f i) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                uint pixelIndex;
                float4 rgba = 0;
                if (amity_sps_cell_frag(
                    i.cellIndex,
                    i.vertex,
                    pixelIndex,
                    rgba
                )) return rgba;
                uint uniqueId = amity_sps_id();
                if (uniqueId == 0u) uniqueId = amity_sps_hash_world(i.rootWorld, 0u);
                uint playerId = amity_sps_player_id();
                uint nextId = amity_sps_to_uint(_SPS_SocketNextId);
                float3 tangentIn = amity_sps_to_bool(_SPS_SocketUseTangentIn) ? amity_sps_toWorld(_SPS_SocketTangentIn.xyz) : 0;
                float3 tangentOut = amity_sps_to_bool(_SPS_SocketUseTangentOut) ? amity_sps_toWorld(_SPS_SocketTangentOut.xyz) : 0;
                float tagValues[AMITY_SPS_SOCKET_PAYLOAD_TAG_COUNT] = {
                    _SPS_SocketTag1, _SPS_SocketTag2, _SPS_SocketTag3, _SPS_SocketTag4,
                    _SPS_SocketTag5, _SPS_SocketTag6, _SPS_SocketTag7, _SPS_SocketTag8
                };
                uint tags[AMITY_SPS_SOCKET_PAYLOAD_TAG_COUNT];
                [unroll]
                for (uint tagIndex = 0u; tagIndex < AMITY_SPS_SOCKET_PAYLOAD_TAG_COUNT; tagIndex++) {
                    tags[tagIndex] = amity_sps_to_uint(tagValues[tagIndex]);
                }
                uint flags = 0u;
                float flagValues[4] = { _SPS_SocketHole, _SPS_SocketDoubleSided, 0, _SPS_SocketRadiusOffset };
                uint flagMasks[4] = {
                    AMITY_SPS_SOCKET_FLAG_HOLE,
                    AMITY_SPS_SOCKET_FLAG_DOUBLE_SIDED,
                    AMITY_SPS_SOCKET_FLAG_PORTAL,
                    AMITY_SPS_SOCKET_FLAG_RADIUS_OFFSET
                };
                [unroll]
                for (uint flagIndex = 0u; flagIndex < 4u; flagIndex++) {
                    if (amity_sps_to_bool(flagValues[flagIndex])) flags |= flagMasks[flagIndex];
                }
                if (amity_sps_try_get_slot_header_rgba(
                    pixelIndex,
                    uniqueId,
                    playerId,
                    AMITY_SPS_PRODUCT_SOCKET,
                    i.rootWorld,
                    i.normalWorld,
                    i.upWorld,
                    amity_sps_object_scale_world(),
                    0,
                    rgba
                )) return rgba;
                if (amity_sps_try_get_socket_payload_rgba(
                    pixelIndex,
                    flags,
                    nextId,
                    tags,
                    tangentIn,
                    tangentOut,
                    rgba
                )) {
                    return rgba;
                }
                return 0;
            }
            ENDCG
        }
    }
}
