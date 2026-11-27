#define SAFE_STEEL_CUSTOM_SURFACE
#include "game/SafeSteel.hlsl"

#if defined(MATERIAL_GBUFFER_PS)
void PatchGBufferSurface(GBufferInput input, inout MaterialSurface surface)
{
    ApplySafeSteel(input, surface, 3.8, 2.0);

    const float3 toCamera = normalize(View.cameraPos - input.worldPos);
    const float3 geometricNormal = normalize(input.normal);
    // Keep the reflection coherent across the face and let the steel texture break it up slightly.
    const float3 polishedNormal = normalize(lerp(geometricNormal, surface.normal, 0.30));
    const float3 reflection = reflect(-toCamera, polishedNormal);
    const float reflectionHeight = dot(reflection, float3(-0.20, 0.98, 0.0));

    const float lightPanel = smoothstep(0.045, 0.105, reflectionHeight)
        * (1.0 - smoothstep(0.155, 0.225, reflectionHeight));
    const float brightStrip = smoothstep(0.128, 0.145, reflectionHeight)
        * (1.0 - smoothstep(0.154, 0.180, reflectionHeight));
    const float lowerStrip = smoothstep(-0.50, -0.36, reflectionHeight)
        * (1.0 - smoothstep(-0.31, -0.19, reflectionHeight));
    const float grazing = 1.0 - saturate(dot(geometricNormal, toCamera));

    const float3 reflectedLight = 0.018
        + lightPanel * float3(0.22, 0.25, 0.28)
        + brightStrip * float3(0.40, 0.42, 0.44)
        + lowerStrip * float3(0.27, 0.24, 0.20)
        + grazing * grazing * 0.14;
    const float steelDetail = 0.72 + 0.50 * dot(surface.albedo.rgb, float3(0.2126, 0.7152, 0.0722));

    // Weak diffuse response leaves room for the dark reflection bands.
    surface.albedo.rgb *= 0.38;
    surface.emission += reflectedLight * (1.30 * steelDetail);
}
#endif
