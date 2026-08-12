#ifndef AMITY_SPS_INC_ID
#define AMITY_SPS_INC_ID

#include "UnityCG.cginc"
#include "sps_cell_hash.cginc"
#include "sps_utils.cginc"

UNITY_INSTANCING_BUFFER_START(AmitySpsInstanceBuf_Id)
    UNITY_DEFINE_INSTANCED_PROP(float, _SPS_Configured)
    #define _SPS_Configured UNITY_ACCESS_INSTANCED_PROP(AmitySpsInstanceBuf_Id, _SPS_Configured)
    UNITY_DEFINE_INSTANCED_PROP(float, _SPS_Id)
    #define _SPS_Id UNITY_ACCESS_INSTANCED_PROP(AmitySpsInstanceBuf_Id, _SPS_Id)
    UNITY_DEFINE_INSTANCED_PROP(float, _SPS_PlayerId)
    #define _SPS_PlayerId UNITY_ACCESS_INSTANCED_PROP(AmitySpsInstanceBuf_Id, _SPS_PlayerId)
UNITY_INSTANCING_BUFFER_END(AmitySpsInstanceBuf_Id)

bool amity_sps_should_abort() {
    if (!amity_sps_to_bool(_SPS_Configured)) return true;
    #if defined(UNITY_SINGLE_PASS_STEREO) || defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
        return unity_StereoEyeIndex != 0;
    #else
        return false;
    #endif
}

uint amity_sps_player_id() {
    return amity_sps_to_uint(_SPS_PlayerId);
}

uint amity_sps_id() {
    return amity_sps_to_uint(_SPS_Id);
}

uint amity_sps_hash_id(uint id, uint playerId) {
    if (playerId == 0u) return id;
    return amity_sps_hash_mix(id ^ amity_sps_hash_mix(playerId));
}

uint amity_sps_id_hash() {
    return amity_sps_hash_id(amity_sps_id(), amity_sps_player_id());
}

// Non-prefixed aliases for VRCFury compatibility
#define sps_should_abort amity_sps_should_abort
#define sps_player_id amity_sps_player_id
#define sps_id amity_sps_id
#define sps_hash_id amity_sps_hash_id
#define sps_id_hash amity_sps_id_hash

#endif
