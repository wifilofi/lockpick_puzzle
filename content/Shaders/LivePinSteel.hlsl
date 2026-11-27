#define SAFE_STEEL_CUSTOM_SURFACE
#include "game/SafeSteel.hlsl"

#if defined(MATERIAL_GBUFFER_PS)
float ElectricityAngle(uint seed)
{
    seed = (seed ^ (seed >> 16)) * 0x7feb352du;
    seed = (seed ^ (seed >> 15)) * 0x846ca68bu;
    seed ^= seed >> 16;
    return float(seed & 0x00ffffffu) * (6.28318530718 / 16777216.0);
}

void PatchGBufferSurface(GBufferInput input, inout MaterialSurface surface)
{
    // This material uses the fractional shininess bits for its per-pin animation seed.
    const uint seed = uint(frac(Material.shininess) * 1024.0);
    surface.shininess = floor(Material.shininess);
    ApplySafeSteel(input, surface, 2.35, 1.5, 1.0);
    surface.albedo.rgb *= float3(0.55, 0.60, 0.67);

    float sine, cosine;
    sincos(ElectricityAngle(seed), sine, cosine);
    const float2 uv = input.tex - 0.5;
    const float2 rotatedUV = float2(cosine * uv.x - sine * uv.y, sine * uv.x + cosine * uv.y) + 0.5;
    const float charge = emissionTexture.Sample(LinearWrapSampler, rotatedUV).r;
    // Keep the fine veins visible after filtering the sRGB texture down to a pin.
    const float veins = smoothstep(0.075, 0.36, charge);
    surface.emission = Material.emission * veins;
}
#endif
