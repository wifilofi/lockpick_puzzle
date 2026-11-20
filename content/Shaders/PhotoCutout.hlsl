#include "engine/MaterialTemplate.hlsl"

#if defined(MATERIAL_GBUFFER_PS)
void PatchGBufferSurface(GBufferInput input, inout MaterialSurface surface)
{
    clip(surface.albedo.a - 0.20);
    surface.albedo.rgb *= 1.8;
    surface.specularColor = float3(0, 0, 0);
}

#elif defined(MATERIAL_SHADOW_VS)
void PatchShadowVertex(inout MaterialVertex vertex)
{
    // These flat photographs do not cast opaque rectangular shadows.
    vertex.position.xyz = float3(0, 0, 0);
}
#endif
