#include "engine/MaterialTemplate.hlsl"

#if defined(MATERIAL_GBUFFER_PS)
void PatchGBufferSurface(GBufferInput input, inout MaterialSurface surface)
{
    // One UNORM texture holds two padded 1024x1024 tiles with independent mips.
    // Top: sRGB base color. Bottom: OpenGL normal XY, metalness, roughness.
    const float2 tileScale = float2(1.0, 1008.0 / 2048.0);
    const float2 uvDx = ddx(input.tex);
    const float2 uvDy = ddy(input.tex);
    const float2 uv = frac(input.tex) * tileScale + float2(0.0, 8.0 / 2048.0);
    const float2 atlasDx = uvDx * tileScale;
    const float2 atlasDy = uvDy * tileScale;
    const float3 color = albedoTexture.SampleGrad(LinearWrapSampler, uv, atlasDx, atlasDy).rgb;
    const float4 finish = albedoTexture.SampleGrad(LinearWrapSampler, uv + float2(0.0, 0.5), atlasDx, atlasDy);

    // Adapt the source maps to SRI's diffuse and specular lighting model.
    const float metalness = finish.b;
    const float gloss = 1.0 - lerp(0.18, 0.86, finish.a);
    const float3 base = lerp(pow(color, 2.2), color, 0.33);
    surface.albedo = float4(base * lerp(1.0, 0.78, metalness), 1.0);
    surface.specularColor *= lerp(0.18, 0.92, metalness) * lerp(0.52, 1.0, gloss);
    surface.shininess = lerp(10.0, 124.0, gloss * gloss);

    // The mesh format passes no tangents to this stage. Build the UV basis
    // from world-space derivatives, including the handedness of mirrored UVs.
    const float3 positionDx = ddx(input.worldPos);
    const float3 positionDy = ddy(input.worldPos);
    const float determinant = uvDx.x * uvDy.y - uvDx.y * uvDy.x;
    const float handedness = determinant < 0.0 ? -1.0 : 1.0;
    const float3 normal = normalize(input.normal);
    float3 tangent = (positionDx * uvDy.y - positionDy * uvDx.y) * handedness;
    tangent -= normal * dot(normal, tangent);
    const float tangentLength = dot(tangent, tangent);
    if (abs(determinant) < 1e-10 || tangentLength < 1e-12)
        return;

    tangent *= rsqrt(tangentLength);
    const float3 bitangentReference = (positionDy * uvDx.x - positionDx * uvDy.x) * handedness;
    float3 bitangent = cross(normal, tangent);
    if (dot(bitangent, bitangentReference) < 0.0)
        bitangent = -bitangent;

    // The texture sampler's V axis increases down the atlas image.
    const float2 normalXY = (finish.rg * 2.0 - 1.0) * float2(2.8, -2.8);
    const float normalZ = sqrt(max(0.02, 1.0 - dot(normalXY, normalXY)));
    surface.normal = normalize(tangent * normalXY.x + bitangent * normalXY.y + normal * normalZ);
}
#endif
