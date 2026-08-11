# SPS Debug Testing

PC-only Unity shaders and materials for inspecting VRCFury SPS data in VRChat.

The tools can display the raw SPS bitmap, inspect an individual socket or plug,
list active targets, draw lines or tags at their world positions, and place
censor effects over targets. Target-enumerating shaders read VRCFury's existing
`_VFGridFinal` texture directly and use a geometry-stage distance scan to sort
targets and merge replicated SPS cells.

## Requirements

- Unity 2022.3
- VRChat Avatars SDK
- VRCFury with SPS
- PC VRChat; these shaders intentionally do not support Quest

## Setup

Copy this folder into the Unity project's `Assets` directory while preserving
the included `.meta` files. Add the desired material to the included upright,
double-sided panel mesh or another suitable mesh.

The Auto Inspector, record table, line, target-plane, and censor shaders do not
need the retired debug CRT/cache-writer setup. They consume the named SPS
texture already supplied by VRCFury. The censor shader additionally uses the
named `_PoiGrab2` capture for its screen effects.

## Main Assets

- `SpsDebugAutoInspector`: inspect one distance-sorted socket or plug
- `SpsDebugCachedSlotTable`: list distance-sorted active targets
- `SpsDebugRawAtlas`: view the SPS bitmap directly
- `SpsDebugLines`: draw lines from the object to active targets
- `SpsDebugTargetPlanes`: place camera-facing textured markers at targets
- `SpsDebugCensorTargets`: place solid, pixelated, or blurred censor shapes

