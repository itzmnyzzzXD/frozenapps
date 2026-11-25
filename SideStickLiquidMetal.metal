#include <metal_stdlib>
using namespace metal;

static float hash21(float2 point) {
    float value = dot(point, float2(127.1, 311.7));
    return fract(sin(value) * 43758.5453123);
}

[[ stitchable ]] half4 sideStickLiquidMetal(
    float2 position,
    half4 sourceColor,
    float time,
    float2 tilt,
    float variant,
    float2 surfaceSize
) {
    float2 safeSize = max(surfaceSize, float2(1.0));
    float2 uv = clamp(position / safeSize, float2(0.0), float2(1.0));
    float2 centered = uv * 2.0 - 1.0;

    float driftA = sin((centered.x * 2.8 + centered.y * 1.2 + time * 0.075 + tilt.x * 1.8) * 6.28318);
    float driftB = cos((centered.y * 3.6 - centered.x * 0.9 - time * 0.052 + tilt.y * 1.7) * 6.28318);
    float flow = (driftA + driftB) * 0.5;
    float fineNoise = hash21(floor(position * 0.14) + floor(time * 0.35));

    float wavePosition = uv.y + flow * 0.075 + tilt.y * 0.12;
    float chromeBand = pow(saturate(0.5 + 0.5 * cos((wavePosition * 8.5 + tilt.x * 0.7) * 6.28318)), 13.0);
    float secondaryBand = pow(saturate(0.5 + 0.5 * sin((uv.x * 4.6 - uv.y * 2.1 + time * 0.035) * 6.28318)), 20.0);
    float specularLine = pow(saturate(1.0 - abs(uv.y - 0.20 - flow * 0.035 - tilt.y * 0.09)), 22.0);
    float edgeReflection = pow(saturate(1.0 - abs(centered.x) * 0.78), 2.0);

    // Grayscale-only liquid metal: luminance is the sole output channel.
    float reflection = 0.18 + chromeBand * 0.40 + secondaryBand * 0.12 + specularLine * 0.35;
    float noiseLift = (fineNoise - 0.5) * 0.035;
    float baseLuminance = variant < 0.5 ? 0.42 : (variant < 1.5 ? 0.10 : 0.68);
    float reflectedLuminance = variant < 0.5 ? 0.94 : (variant < 1.5 ? 0.48 : 1.0);
    float luminance = baseLuminance * (0.72 + flow * 0.12 + noiseLift);
    luminance = mix(luminance, reflectedLuminance, saturate(reflection * (0.55 + edgeReflection * 0.35)));
    luminance += edgeReflection * 0.025;
    luminance += saturate(tilt.x * 0.45 + 0.5) * specularLine * 0.025;
    float3 color = float3(luminance);
    float pulse = 0.94 + 0.06 * sin(time * 1.256637 + flow * 2.0);
    color *= pulse;
    color = clamp(color, float3(0.0), float3(1.0));

    float outputAlpha = float(sourceColor.a) * 0.72;
    return half4(half3(color * outputAlpha), half(outputAlpha));
}
