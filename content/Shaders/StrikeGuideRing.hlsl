#include "engine/Common.hlsl"

cbuffer StrikeGuideRings : register(b5)
{
    float4 CentersAndSize[2];
};

struct RingVertex
{
    float4 position : SV_POSITION;
    float2 offset : TEXCOORD0;
    nointerpolation float3 color : COLOR0;
};

RingVertex VSMain(uint vertex : SV_VertexID, uint instance : SV_InstanceID)
{
    const float2 corners[6] = {
        float2(-1, -1), float2(-1, 1), float2(1, 1),
        float2(-1, -1), float2(1, 1), float2(1, -1)
    };
    const float4 center = CentersAndSize[instance];
    float4 viewPosition = mul(float4(center.xyz, 1.0), View.viewMatrix);
    viewPosition.xy += corners[vertex] * center.w;

    RingVertex result;
    result.position = mul(viewPosition, View.projectionMatrix);
    result.offset = corners[vertex];
    result.color = instance == 0 ? float3(1.0, 0.16, 0.022) : float3(0.12, 0.78, 1.0);
    return result;
}

float4 PSMain(RingVertex input) : SV_Target
{
    float radius = length(input.offset);
    float edge = abs(radius - 0.61);
    float coreWidth = 0.10 + min(fwidth(radius), 0.06);
    float ring = 1.0 - smoothstep(0.0, coreWidth, edge);
    float halo = 1.0 - smoothstep(0.0, 0.37, edge);
    return float4(input.color * (3.5 * ring + 1.35 * halo * halo), 0.0);
}
