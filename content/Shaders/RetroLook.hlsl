Texture2D<float4> SceneColor : register(t0);
Texture2D<float4> BleedMask : register(t1);
Texture2D<float4> BleedCurve : register(t2);
SamplerState LinearClampSampler : register(s1);

/*
cbuffer EngineFrame : register(b0)
{
    float SimulationTime;
};
*/

cbuffer PosterizeParams : register(b5)
{
    float Brightness;
    float Contrast;
    // float NoiseAmount;
    // float NoiseRate;
    // float LcdBefore;
    // float LcdAfter;
    // float HueWobble;
    float PosterizeStrength;
    float PosterizeSteps;
    float PosterizeLift;
    // float TintEnabled;
    // float3 Tint;
    // float SharpenStrength;
    // float GlowAmount;
    // float GlowThreshold;
    // float GlowRadius;
    // float StaticAmount;
};

cbuffer BleedParams : register(b6)
{
    float BleedAmount;
    int BleedMode;
    int BleedMaskChannel;
};

/*
static const float2 StageSize = float2(1440.0, 1080.0);
// LcdTile.png has four identical pixels across each row. Keep its exact
// top-to-bottom byte values here so texture color-space decoding cannot alter them.
static const float LcdRows[4] = { 3.0 / 255.0, 69.0 / 255.0, 201.0 / 255.0, 253.0 / 255.0 };
*/

float3 LinearToSRGB(float3 linearColor)
{
    linearColor = max(linearColor, 0.0);
    return lerp(12.92 * linearColor, 1.055 * pow(linearColor, 1.0 / 2.4) - 0.055, step(0.0031308, linearColor));
}

float3 SRGBToLinear(float3 encoded)
{
    encoded = saturate(encoded);
    return lerp(encoded / 12.92, pow((encoded + 0.055) / 1.055, 2.4), step(0.04045, encoded));
}

float4 SampleScene(float2 uv)
{
    return SceneColor.SampleLevel(LinearClampSampler, uv, 0);
}

// Filter weights are paired luma/chroma taps from the three Unity NTSC modes.
static const float2 BleedWeights0[22] = {
    float2(0.000134711, 0.001845562), float2(-0.000226705, 0.002381606),
    float2(-0.000777988, 0.003040177), float2(-0.000997809, 0.003838976),
    float2(-0.000522802, 0.004795341), float2(0.000344691, 0.005925312),
    float2(0.000768930, 0.007242534), float2(0.000275591, 0.008757043),
    float2(-0.000373434, 0.010473987), float2(0.000522796, 0.012392365),
    float2(0.003813817, 0.014503872), float2(0.007502825, 0.016791957),
    float2(0.006786001, 0.019231195), float2(-0.002636726, 0.021787070),
    float2(-0.019461182, 0.024416251), float2(-0.033792479, 0.027067414),
    float2(-0.029921972, 0.029682613), float2(0.005032552, 0.032199202),
    float2(0.071226466, 0.034552198), float2(0.151755921, 0.036677005),
    float2(0.218166470, 0.038512317), float2(0.071226466, 0.040003044)
};

static const float2 BleedWeights1[22] = {
    float2(-0.000012020, -0.000118847), float2(-0.000049979, -0.000271306),
    float2(-0.000113940, -0.000502642), float2(-0.000122150, -0.000930833),
    float2(-0.000005612, -0.001451013), float2(0.000170516, -0.002064744),
    float2(0.000237199, -0.002700432), float2(0.000169640, -0.003241276),
    float2(0.000285688, -0.003524948), float2(0.000984574, -0.003350284),
    float2(0.002018683, -0.002491729), float2(0.002002275, -0.000721149),
    float2(-0.000909882, 0.002164659), float2(-0.007049081, 0.006313635),
    float2(-0.013222860, 0.011789103), float2(-0.012606931, 0.018545660),
    float2(0.002460860, 0.026414396), float2(0.035868225, 0.035100710),
    float2(0.084016453, 0.044196567), float2(0.135563500, 0.053207202),
    float2(0.175261268, 0.061590275), float2(0.084016453, 0.068803602)
};

static const float2 BleedWeights2[30] = {
    float2(-0.000051693, 0.001384762), float2(0.000000000, 0.001678312),
    float2(-0.000066171, 0.002021715), float2(-0.000245058, 0.002420562),
    float2(-0.000432928, 0.002880460), float2(-0.000472644, 0.003406879),
    float2(-0.000252236, 0.004004985), float2(0.000198929, 0.004679445),
    float2(0.000687058, 0.005434218), float2(0.000944112, 0.006272332),
    float2(0.000803467, 0.007195654), float2(0.000363199, 0.008204665),
    float2(0.000013422, 0.009298238), float2(0.000253402, 0.010473450),
    float2(0.001339461, 0.011725413), float2(0.002932972, 0.013047155),
    float2(0.003983485, 0.014429548), float2(0.003026683, 0.015861306),
    float2(-0.001102056, 0.017329037), float2(-0.008373026, 0.018817382),
    float2(-0.016897700, 0.020309220), float2(-0.022914480, 0.021785952),
    float2(-0.021642347, 0.023227857), float2(-0.008863273, 0.024614500),
    float2(0.017271957, 0.025925203), float2(0.054921920, 0.027139546),
    float2(0.098342579, 0.028237893), float2(0.139044281, 0.029201910),
    float2(0.168055832, 0.030015081), float2(0.098342579, 0.030663170)
};

// Keep the original filter's signal transform and inverse.
float3 EncodeBleedSignal(float3 rgb)
{
    return float3(
        dot(rgb, float3(0.2989, 0.5959, 0.2115)),
        dot(rgb, float3(0.5870, -0.2744, -0.5229)),
        dot(rgb, float3(0.1140, -0.3216, 0.3114)));
}

float3 DecodeBleedSignal(float3 signal)
{
    return float3(
        dot(signal, float3(1.0, 1.0, 1.0)),
        dot(signal, float3(0.956, -0.2720, -1.1060)),
        dot(signal, float3(0.6210, -0.6474, 1.7046)));
}

float3 BleedWeight(int tap, int center)
{
    if (BleedMode == 3)
    {
        float3 weight = BleedCurve.SampleLevel(LinearClampSampler, float2(tap / 50.0, 0), 0).rgb;
        if (tap != center)
            weight.r = BleedCurve.SampleLevel(LinearClampSampler, float2((tap + 3) / 50.0, 0), 0).r;
        return weight;
    }

    float2 weight;
    if (BleedMode == 2) weight = BleedWeights2[tap];
    else if (BleedMode == 1) weight = BleedWeights1[tap];
    else weight = BleedWeights0[tap];
    return weight.xyy;
}

float4 PictureAt(float2 uv, float texelWidth)
{
    if (BleedAmount <= 0.0) return SampleScene(uv);

    if (BleedMaskChannel != 0)
    {
        float4 mask = BleedMask.SampleLevel(LinearClampSampler, uv, 0);
        if ((BleedMaskChannel == 2 ? mask.a : mask.r) < 0.0001)
            return SampleScene(uv);
    }

    float width = texelWidth * BleedAmount;
    float2 centerUv = uv - float2(0.5 * width, 0);
    int taps = BleedMode == 3 ? 17 : (BleedMode == 2 ? 29 : 21);
    float4 center = SampleScene(centerUv);
    float3 norm = BleedWeight(taps, taps);
    float3 signal = EncodeBleedSignal(center.rgb) * norm;

    [loop] for (int tap = 0; tap < taps; tap++)
    {
        float2 offset = float2((taps - tap) * width, 0);
        float3 weight = BleedWeight(tap, taps);
        signal += (EncodeBleedSignal(SampleScene(centerUv - offset).rgb)
                 + EncodeBleedSignal(SampleScene(centerUv + offset).rgb)) * weight;
        norm += 2.0 * weight;
    }

    if (any(abs(norm) < 1e-5)) return center;
    return float4(DecodeBleedSignal(signal / norm), center.a);
}

/*
// A hash of a pixel and a seed to 0..1 (24 bits), for the noise.
float Hash(uint2 pixel, uint seed)
{
    uint h = pixel.x * 1597334677u ^ pixel.y * 3812015801u ^ seed * 2654435761u;
    h = (h ^ (h >> 16)) * 2246822519u;
    h = (h ^ (h >> 13)) * 3266489917u;
    h ^= h >> 16;
    return (h & 0xFFFFFFu) * (1.0 / 16777216.0);
}

// Adobe's Overlay of a layer s over the base b, per channel, then the layer's opacity.
float3 Overlay(float3 b, float3 s, float opacity)
{
    float3 dark = 2.0 * b * s;
    float3 light = 1.0 - 2.0 * (1.0 - b) * (1.0 - s);
    return lerp(b, lerp(light, dark, step(b, 0.5)), opacity);
}

// Shader Graph's gradient noise (the old hue wobble used it), 0..1.
float2 GradientDirection(float2 p)
{
    p = fmod(p, 289.0);
    float x = fmod((34.0 * p.x + 1.0) * p.x, 289.0) + p.y;
    x = fmod((34.0 * x + 1.0) * x, 289.0);
    x = frac(x / 41.0) * 2.0 - 1.0;
    return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
}

float GradientNoise(float2 p)
{
    float2 ip = floor(p);
    float2 fp = frac(p);
    float d00 = dot(GradientDirection(ip), fp);
    float d01 = dot(GradientDirection(ip + float2(0, 1)), fp - float2(0, 1));
    float d10 = dot(GradientDirection(ip + float2(1, 0)), fp - float2(1, 0));
    float d11 = dot(GradientDirection(ip + float2(1, 1)), fp - float2(1, 1));
    fp = fp * fp * fp * (fp * (fp * 6.0 - 15.0) + 10.0);
    return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x) + 0.5;
}

// A turn of the hue by `turns` of the circle (the colour is turned in the plane of its chroma, YIQ).
float3 TurnHue(float3 rgb, float turns)
{
    float angle = turns * 6.2831853;
    float c = cos(angle);
    float s = sin(angle);
    float3 yiq = float3(dot(rgb, float3(0.299, 0.587, 0.114)),
                        dot(rgb, float3(0.596, -0.274, -0.322)),
                        dot(rgb, float3(0.211, -0.523, 0.312)));
    yiq.yz = float2(yiq.y * c - yiq.z * s, yiq.y * s + yiq.z * c);
    return saturate(float3(yiq.x + 0.956 * yiq.y + 0.621 * yiq.z,
                           yiq.x - 0.272 * yiq.y - 0.647 * yiq.z,
                           yiq.x - 1.106 * yiq.y + 1.703 * yiq.z));
}
*/

float3 Posterize(float3 rgb)
{
    float stepSize = 1.0 / PosterizeSteps;
    float3 lifted = PosterizeLift == 1.0 ? rgb : pow(rgb, PosterizeLift);
    float3 poster = floor(lifted / stepSize) * stepSize;
    if (PosterizeLift != 1.0)
        poster = pow(poster, 1.0 / PosterizeLift);
    return lerp(rgb, poster, PosterizeStrength);
}

/*
// Value noise: a hash on the corners of a cell of the grid, smoothly mixed between them.
float ValueNoise(float2 p, uint seed)
{
    float2 cell = floor(p);
    float2 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    uint2 c = (uint2)cell;
    float a = Hash(c, seed);
    float b = Hash(c + uint2(1, 0), seed);
    float d = Hash(c + uint2(0, 1), seed);
    float e = Hash(c + uint2(1, 1), seed);
    return lerp(lerp(a, b, f.x), lerp(d, e, f.x), f.y);
}

// The static of a transition: grains a few pixels across (a coarse noise and a fine one over it, smoothly mixed, so they clump),
// new thirty times a second, in the dark teal and pale cyan of an old set that lost its signal. The colours are as they are seen.
float3 StaticAt(float2 grid)
{
    uint seed = (uint)(SimulationTime * 30.0) * 31u + 7919u;
    float coarse = ValueNoise(grid / 6.0, seed);
    float fine = ValueNoise(grid / 3.0, seed + 17u);
    float grain = saturate((coarse * 0.6 + fine * 0.4 - 0.5) * 2.0 + 0.42);
    return SRGBToLinear(lerp(float3(0.06, 0.17, 0.19), float3(0.55, 0.78, 0.80), grain));
}

float3 GlowAt(float2 uv)
{
    float2 reach = GlowRadius / StageSize;
    float range = max(1.0 - GlowThreshold, 1e-3);
    float3 sum = 0.0;
    [unroll] for (int ring = 0; ring < 2; ring++)
    {
        float scale = ring == 0 ? 0.5 : 1.0;
        [unroll] for (int i = 0; i < 6; i++)
        {
            // The second ring is turned by half a step, so the taps do not line up.
            float angle = (i + 0.5 * ring) * 1.0471976;
            float2 offset = float2(cos(angle), sin(angle)) * reach * scale;
            float3 tap = SampleScene(uv + offset).rgb;
            float over = saturate((max(tap.r, max(tap.g, tap.b)) - GlowThreshold) / range);
            sum += tap * over;
        }
    }
    return sum * (GlowAmount / 12.0);
}
*/

float4 PSPosterize(float4 position : SV_POSITION, float2 uv : TEXCOORD0) : SV_Target
{
    float4 picture = SampleScene(uv);
    float3 seen = LinearToSRGB(saturate(picture.rgb)) * Brightness;
    if (Contrast != 1.0)
        seen = (seen - 0.5) * Contrast + 0.5;
    seen = saturate(seen);

    if (PosterizeStrength > 0.0)
        seen = Posterize(seen);

    picture.rgb = SRGBToLinear(seen);
    return picture;
}

float4 PSMain(float4 position : SV_POSITION, float2 uv : TEXCOORD0) : SV_Target
{
    uint width, height;
    SceneColor.GetDimensions(width, height);
    return PictureAt(uv, 1.0 / float(width));
}

// Original effects and their order are retained here for re-enabling later.
/*
    if (SharpenStrength > 0.0)
    {
        float3 neighbors = PictureAt(uv + float2(0, texel.y), texel.x).rgb
                         + PictureAt(uv - float2(0, texel.y), texel.x).rgb
                         + PictureAt(uv + float2(texel.x, 0), texel.x).rgb
                         + PictureAt(uv - float2(texel.x, 0), texel.x).rgb;
        picture.rgb += (picture.rgb - neighbors * 0.25) * SharpenStrength;
    }

    float2 grid = float2(uv.x, 1.0 - uv.y) * StageSize;
    if (LookEnabled > 0.5)
    {
        uint2 pixel = (uint2)clamp(floor(grid), 0.0, StageSize - 1.0);
        float3 seen = LinearToSRGB(saturate(picture.rgb * Brightness));
        uint seed = NoiseRate > 0.0 ? (uint)floor(SimulationTime * NoiseRate) : 0u;
        seen = lerp(seen, Hash(pixel, seed).xxx, NoiseAmount);

        float3 lcd = LcdRows[3u - pixel.y % 4u].xxx;
        seen = Overlay(seen, lcd, LcdBefore);
        if (TintEnabled > 0.5) seen = saturate(seen * Tint);
        if (PosterizeStrength > 0.0) seen = Posterize(saturate(seen));
        seen = Overlay(seen, lcd, LcdAfter);

        if (HueWobble > 0.0)
        {
            uint frame = asuint(SimulationTime);
            float2 offset = float2(Hash(uint2(1, 0), frame) * 100.0, 14.43 + Hash(uint2(2, 0), frame) * 85.57);
            float wobble = GradientNoise((float2(0.0, grid.y * 0.25) + offset) * 10.0);
            seen = TurnHue(seen, wobble * HueWobble);
        }
        picture.rgb = SRGBToLinear(seen);
    }

    if (GlowAmount > 0.0) picture.rgb += GlowAt(uv);
    if (StaticAmount > 0.0) picture.rgb = lerp(picture.rgb, StaticAt(grid), StaticAmount);
*/
