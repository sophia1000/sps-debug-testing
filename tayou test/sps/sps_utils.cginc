#ifndef AMITY_SPS_INC_UTILS
#define AMITY_SPS_INC_UTILS

#include "UnityShaderVariables.cginc"

float3 amity_sps_normalize(float3 a) {
    return any(a != 0) ? normalize(a) : float3(0, 0, 1);
}

float amity_sps_length_sq(float3 v) {
    return dot(v, v);
}

bool amity_sps_to_bool(float v) {
    return v > 0.5;
}

uint amity_sps_to_uint(float v) {
    return (uint)round(v);
}

void amity_sps_clip_rect(int2 local, int2 size) {
    clip(float4(
        local.x,
        local.y,
        size.x - 1 - local.x,
        size.y - 1 - local.y
    ) + 0.5);
}

float3 amity_sps_object_origin_world() {
    return mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
}

float3 amity_sps_object_direction_world(float3 localDirection) {
    return mul((float3x3)unity_ObjectToWorld, localDirection);
}

float3 amity_sps_object_forward_world() {
    return amity_sps_normalize(amity_sps_object_direction_world(float3(0, 0, 1)));
}

float3 amity_sps_object_up_world() {
    return amity_sps_normalize(amity_sps_object_direction_world(float3(0, 1, 0)));
}

float amity_sps_object_scale_world() {
    return length(amity_sps_object_direction_world(float3(0, 0, 1)));
}

float3 amity_sps_toLocal(float3 v) { return mul(unity_WorldToObject, float4(v, 1)).xyz; }
float3 amity_sps_toWorld(float3 v) { return mul(unity_ObjectToWorld, float4(v, 1)).xyz; }
float3 amity_sps_direction_toWorld(float3 v) { return mul((float3x3)unity_ObjectToWorld, v); }
float3 amity_sps_direction_toLocal(float3 v) { return mul((float3x3)unity_WorldToObject, v); }

// Non-prefixed aliases for VRCFury compatibility
#define sps_normalize amity_sps_normalize
#define sps_length_sq amity_sps_length_sq
#define sps_to_bool amity_sps_to_bool
#define sps_to_uint amity_sps_to_uint
#define sps_clip_rect amity_sps_clip_rect
#define sps_object_origin_world amity_sps_object_origin_world
#define sps_object_direction_world amity_sps_object_direction_world
#define sps_object_forward_world amity_sps_object_forward_world
#define sps_object_up_world amity_sps_object_up_world
#define sps_object_scale_world amity_sps_object_scale_world
#define sps_toLocal amity_sps_toLocal
#define sps_toWorld amity_sps_toWorld
#define sps_direction_toWorld amity_sps_direction_toWorld
#define sps_direction_toLocal amity_sps_direction_toLocal

#endif
