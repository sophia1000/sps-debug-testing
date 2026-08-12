#ifndef AMITY_SPS_INC_TEXTURE
#define AMITY_SPS_INC_TEXTURE

#include "UnityCG.cginc"

#ifndef UNITY_SEPARATE_TEXTURE_SAMPLER
    #error SPS requires separate texture/sampler support for exact integer texel loads.
#endif

struct AmitySpsTexture {
    Texture2D tex;
    Texture2DArray texArray;
    float4 texelSize;
    bool isArray;

    float4 read(uint2 pixel) {
        if (texelSize.y < 0) pixel.y = (uint)texelSize.w - 1u - pixel.y;
        return isArray ? texArray.Load(int4(pixel.x, pixel.y, 0, 0)) : tex.Load(int3(pixel.x, pixel.y, 0));
    }
};

inline AmitySpsTexture AmityMakeSpsTexture(Texture2D tex, float4 texelSize) {
    AmitySpsTexture value;
    value.tex = tex;
    value.texelSize = texelSize;
    value.isArray = false;
    return value;
}

inline AmitySpsTexture AmityMakeSpsTexture(Texture2DArray texArray, float4 texelSize) {
    AmitySpsTexture value;
    value.texArray = texArray;
    value.texelSize = texelSize;
    value.isArray = true;
    return value;
}

#define AMITY_SPS_READ_TEX(tex, pixel) tex.read(pixel)

#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
    #define AMITY_SPS_INIT_TEX(tex) Texture2DArray tex; float4 tex##_TexelSize;
    #define AMITY_SPS_GET_TEX(tex) AmityMakeSpsTexture(tex, tex##_TexelSize)
#else
    #define AMITY_SPS_INIT_TEX(tex) Texture2D tex; float4 tex##_TexelSize;
    #define AMITY_SPS_GET_TEX(tex) AmityMakeSpsTexture(tex, tex##_TexelSize)
#endif

// Non-prefixed aliases for VRCFury compatibility
#define SpsTexture AmitySpsTexture
#define MakeSpsTexture AmityMakeSpsTexture
#define SPS_READ_TEX AMITY_SPS_READ_TEX
#define SPS_INIT_TEX AMITY_SPS_INIT_TEX
#define SPS_GET_TEX AMITY_SPS_GET_TEX

#endif
