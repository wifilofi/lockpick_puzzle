#define SAFE_STEEL_CUSTOM_SURFACE
#include "game/SafeSteel.hlsl"

#ifndef CABINET_PANEL_ALBEDO_SCALE
#define CABINET_PANEL_ALBEDO_SCALE 1.30
#endif

#if defined(MATERIAL_GBUFFER_PS)
void PatchGBufferSurface(GBufferInput input, inout MaterialSurface surface)
{
    ApplySafeSteel(input, surface, 3.6, 1.0, 1.25);
    surface.albedo.rgb *= CABINET_PANEL_ALBEDO_SCALE;
}
#endif
