#ifndef AMITY_SPS_INC_ENCODE
#define AMITY_SPS_INC_ENCODE

#include "UnityCG.cginc"

float amity_sps_decode_channel(float value) {
    #ifdef UNITY_COLORSPACE_GAMMA
        return saturate(value);
    #else
        return saturate(LinearToGammaSpaceExact(value));
    #endif
}

float4 amity_sps_encode_uint(uint value) {
    uint4 shifts = uint4(0, 8, 16, 24);
    float4 bytes = float4((value >> shifts) & 255u) / 255.0;
    #ifdef UNITY_COLORSPACE_GAMMA
        return saturate(bytes);
    #else
        return saturate(float4(
            GammaToLinearSpaceExact(bytes.r),
            GammaToLinearSpaceExact(bytes.g),
            GammaToLinearSpaceExact(bytes.b),
            GammaToLinearSpaceExact(bytes.a)
        ));
    #endif
}

float4 amity_sps_encode_float(float value) {
    return amity_sps_encode_uint(asuint(value));
}

uint amity_sps_decode_uint(float4 rgba) {
    uint b0 = (uint)round(amity_sps_decode_channel(rgba.r) * 255.0);
    uint b1 = (uint)round(amity_sps_decode_channel(rgba.g) * 255.0);
    uint b2 = (uint)round(amity_sps_decode_channel(rgba.b) * 255.0);
    uint b3 = (uint)round(amity_sps_decode_channel(rgba.a) * 255.0);
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
}

uint amity_sps_decode_uint_raw(float4 rgba) {
    uint b0 = (uint)round(rgba.r * 255.0);
    uint b1 = (uint)round(rgba.g * 255.0);
    uint b2 = (uint)round(rgba.b * 255.0);
    uint b3 = (uint)round(rgba.a * 255.0);
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
}

// Non-prefixed aliases for VRCFury compatibility
#define sps_decode_channel amity_sps_decode_channel
#define sps_encode_uint amity_sps_encode_uint
#define sps_encode_float amity_sps_encode_float
#define sps_decode_uint amity_sps_decode_uint
#define sps_decode_uint_raw amity_sps_decode_uint_raw

#endif
